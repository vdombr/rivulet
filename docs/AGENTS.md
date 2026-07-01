# AGENTS.md

Guide for AI agents working on this Rivulet application.

## Overview

Rivulet is a Rack web framework built on Railway Oriented Programming, dry-rb,
falcon, and Sequel. Every request flows through an explicit pipeline of
operations and steps — no hidden control flow, no implicit context.

A freshly generated app starts greenfield: `app/models`, `db/migrations`,
`handlers/shared/steps`, `services/shared/steps` are all empty, and
`config/routes.rb` has no routes. Shared infrastructure (validation,
projection, auth) is not provided — build it as you need it.

## Commands

Run the app:

```bash
docker compose up
```

Rebuild after Gemfile changes:

```bash
docker compose up --build
```

All `rivulet` commands run inside the container — never with `bundle exec`
on the host. Start the stack with `docker compose up`, then invoke the CLI
through the compose service (`app`):

```bash
docker compose exec app rivulet --help
docker compose exec app rivulet g handler posts --list --read --create --update --delete
docker compose exec app rivulet g handler operation posts.show
docker compose exec app rivulet g handler step posts.load_post
docker compose exec app rivulet g service users
docker compose exec app rivulet g migration create_users
docker compose exec app rivulet db migrate
docker compose exec app rivulet console
docker compose exec app rivulet routes
```

### Host vs. Container: Where to Work

The current directory on the host is bind-mounted into the container as `/app`
(`volumes: ["./:/app"]` in `docker-compose.yml`). The two are the same files,
kept in sync by the mount:

- **Run `rivulet` commands inside the container** (see the list above). They
  read and write under `/app`, which is your current directory — so files a
  generator creates (e.g. `rivulet g handler posts`) appear on the host
  immediately.
- **Edit application code in your current directory on the host** — with your
  editor or file tools, not inside the container. Edits are reflected in the
  container instantly via the mount.
- **Do not edit files inside the container.** The container is an execution
  environment for `rivulet` and the app server, not a place to author code.

In short: edit on the host, run commands in the container; the bind mount
keeps both in sync. Because Zeitwerk eager-loads `app/` at startup, restart
the app container (`docker compose restart app`) after adding new files so
they are picked up.

## Project Structure

```
app/
  handlers/          # Transport layer
    shared/          # Reusable handler steps/utils
    <domain>/
      handler.rb
      container.rb
      operations/
      steps/
  services/          # Domain layer
    shared/
    <domain>/
      operations/
      steps/
      contracts/
      utils/
  models/            # Sequel models
config/
  application.rb     # App configuration (DSN, logger, sendfile)
  routes.rb          # Route definitions
db/
  migrations/        # SQL migration files
config.ru            # Rack entrypoint
falcon.rb            # Falcon server config
Dockerfile
docker-compose.yml
```

## Architecture

Rivulet separates transport concerns from domain concerns through two
independent execution layers that share the same building blocks.

### Handlers (Transport Layer)

Handlers process incoming HTTP requests, prepare execution context,
delegate work to services, and produce HTTP responses.

### Services (Domain Layer)

Services execute business use cases, coordinate domain-specific workflows,
and remain independent from HTTP and transport concerns. Services can be
invoked from handlers, background jobs, CLI commands, or any other runtime.

### Operations

Operations represent application use cases. Their responsibility is to
define execution flow by composing reusable steps into an explicit Railway
pipeline. Operations do not implement business logic.

`Rivulet::Operation` extends `Dry::Operation`. The `step` keyword unwraps a
`Success` (returning the inner value) and short-circuits on `Failure` (halting
the operation and returning the failure). As a result, the value passed to the
next step is a bare hash, not a monad — chain `result = step foo.(result)` and
forward `result`, not a wrapped monad.

```ruby
class Create < Rivulet::Operation
  include Import[
    validate:    'shared.steps.validate',
    authorize:   'shared.steps.authorize',
    create_post: 'steps.create_post',
    project:     'shared.steps.project'
  ]

  def call(input = {})
    result = step validate.(input, contract)
    result = step authorize.(result)
    result = step create_post.(result)
    result = step project.(result, projection)

    result
  end
end
```

Operations follow a canonical step order:

1. **validate** — run the contract; filter the input to the declared keys.
2. **authorize** — enforce access (a business rule; see
   [Authentication vs. Authorization](#authentication-vs-authorization)).
3. **business steps** — the operation's work (load, create, update, …).
4. **project** — shape the output; the last step.

Validate first so the pipeline runs on clean, declared data; authorize before
business logic so access is enforced before any side effects; project last so
the output shape is finalized. Not every operation needs every stage (e.g. a
`list` may skip `project` if it returns rows directly), but keep this order
when the stages are present.

Operations receive an input hash as their entry point. Each step may read,
add, or modify values in the input hash as it flows through the pipeline.

> The `validate`, `authorize`, and `project` steps above are **shared steps**
> that live in `services/shared/steps` and accept the contract or projection
> defined in the operation. Because the shared namespace is registered with
> the `shared.` prefix, they are imported as `'shared.steps.validate'` /
> `'shared.steps.authorize'` / `'shared.steps.project'`. Templates for these
> shared steps are not provided yet — create them before this pattern runs.
> `ApplicationContract` (in `app/application_contract.rb`) and
> `Rivulet::Projection` are base classes only, not runnable steps. `authorize`
> may also be per-domain (`'steps.authorize'`) when the policy is
> resource-specific.

A `validate` step runs the contract against the input hash and returns
`Success(result.to_h)` on success, or `Failure[:validation, result.errors.to_h]`
on errors:

```ruby
module Services
  module Shared
    module Steps
      class Validate < Rivulet::Step
        def call(input, contract)
          result = contract.call(input)
          return Success(result.to_h) if result.success?

          Failure[:validation, result.errors.to_h]
        end
      end
    end
  end
end
```

A `project` step applies a projection to `input[:resource]` (the persisted
instance) and stores the result in `input[:data]`:

```ruby
module Services
  module Shared
    module Steps
      class Project < Rivulet::Step
        def call(input, projection)
          input[:data] = projection.call(input[:resource])
          Success(input)
        end
      end
    end
  end
end
```

Register both in `app/services/shared/namespace.rb`:

```ruby
namespace('steps') do
  register('validate') { Services::Shared::Steps::Validate.new }
  register('project')  { Services::Shared::Steps::Project.new }
end
```

### Steps

Steps are the executable units within an operation. Each step performs one
clearly defined responsibility and returns `Success(input)` or `Failure(...)`.
A failure short-circuits the pipeline.

`Rivulet::Step` includes `Dry::Monads[:result]`, so `Success` and `Failure`
are available inside steps with no extra include.

```ruby
class CreatePost < Rivulet::Step
  def call(input)
    input[:resource] = input[:resource].create(input[:attributes])
    Success(input)
  end
end
```

Steps should be small, focused, and easy to test in isolation.

### Shared Components

Each layer maintains a `shared/` namespace for cross-cutting, reusable steps:

- `handlers/shared/` — transport-level concerns (authentication, header parsing, context).
- `services/shared/` — domain-agnostic business operations (authorization, validation, pagination).

### Authentication vs. Authorization

Split these concerns across layers by what they depend on:

- **Authentication** belongs in the **handler** layer (`handlers/shared/`).
  Establishing who the caller is depends on transport data — JWTs, session
  cookies, headers — so it runs as a handler step before the service is
  invoked and resolves a `current_user` into the request context.
- **Authorization** belongs in the **service** layer (`services/shared/` or a
  domain service). Access rights are part of the business requirements: who
  may read, create, update, or delete a resource is a domain rule, not a
  transport one. Authorization steps run inside the service pipeline, where
  they enforce policies against the resource and the acting user without
  depending on HTTP.

In short: the handler authenticates (who), the service authorizes (may they).

#### Deciding gray-area checks

Use this test: **would this rule need to hold if the service were called from
a non-HTTP entry point — a background job, a Kafka consumer, or a CLI
command?** If yes, it is authorization and belongs in the service. If it only
makes sense for an HTTP request (it depends on a token, cookie, or header),
it is authentication and belongs in the handler.

A common gray area is the **banned-user check**. "Is this user banned?" is a
business rule — a banned user must not perform actions whether they arrive
via HTTP, a Kafka consumer, or a CLI command — so it is authorization. It
belongs in the service (e.g. a shared `VerifyNotBanned` step), not in the
handler's `Authenticate` step; placing it in the handler would let non-HTTP
callers bypass it. The trap: loading the user from the JWT is authentication
(handler); checking a property of that user which governs whether they may
act (`banned?`) is authorization (service). The handler resolves
`current_user`; the service receives it and authorizes.

### Utils

Utils encapsulate implementation details (API clients, calculations, token
generation). Unlike steps, utils do not participate in Railway pipelines and
return direct results. They are registered in the container (under
`namespace('utils')`) and injected into steps via `Import`.

Every component under `app/handlers/` and `app/services/` must be registered
in the container — there are no plain modules:

- A **step** (`Rivulet::Step`) participates in a pipeline, operates on the
  input hash, and returns `Success`/`Failure`. Registered under
  `namespace('steps')`.
- A **util** returns direct results, does not participate in a pipeline, and
  is registered under `namespace('utils')`, injected into steps via `Import`.

Do not define a plain module and `include` it across steps. Plain objects
bypass the container: they are invisible to dependency injection, not
overridable per-domain, and scatter `include SomeModule` across files.
Reusable helpers go under `handlers/shared/namespace.rb` or
`services/shared/namespace.rb` — the `namespace('utils')` block is empty and
waiting for them.

### Handler Input

The framework builds the handler input hash before the operation runs. It
contains:

```ruby
{
  params:  { ... },          # path params + JSON body params
  context: {
    headers: { ... },        # normalized HTTP_* headers (HTTP_X_CUSTOM -> X-Custom)
    cookies: { ... },        # parsed cookies
    session: ...             # rack.session (nil unless session middleware)
  }
}
```

- `params` — merged path params (e.g. `:id` from `/posts/:id`) and parsed JSON
  body params. Path params take precedence over body params with the same key.
- `context.headers` — request headers with names normalized
  (`HTTP_X_CUSTOM` → `X-Custom`, `CONTENT_TYPE` → `Content-Type`).
- `context.cookies` — cookies parsed from the request.
- `context.session` — the Rack session, or `nil` when no session middleware
  is configured.

### Handler Output

Handler operations return a `Rivulet::Response` wrapped in a monad. The final
step in a handler pipeline produces the response on the success path:

```ruby
class BuildResponse < Rivulet::Step
  def call(input)
    response = Rivulet::Response.new(
      status: 200,
      body:   { data: input[:post] }
    )
    Success(response)
  end
end
```

On the failure path, a step short-circuits the pipeline and returns a
`Rivulet::Response` wrapped in a `Failure` monad. The framework unwraps
the response regardless of which path produced it:

```ruby
Failure(
  Rivulet::Response.new(
    status: 422,
    body:   { error: 'validation_failed' }
  )
)
```

#### Rivulet::Response

The standardized transport response object. Attributes (all with defaults):

| Attribute | Default | Description |
|---|---|---|
| `status` | `200` | HTTP status code |
| `body` | `[]` | Response payload (shape depends on `format`) |
| `headers` | `{}` | HTTP headers (merged over framework-generated headers) |
| `format` | `:json` | How the body is compiled into an HTTP response |

Supported formats:

- `:json` (default) — body is any JSON-serializable value; serialized with Oj;
  sets `Content-Type: application/json` and `Content-Length`.
- `:text` — body is converted to a string; sets
  `Content-Type: text/plain; charset=utf-8` and `Content-Length`.
- `:file` — body is a String path or a Hash with `:path` (required) and
  optional `:filename`, `:disposition` (default `inline`), `:mime_type`;
  streams the file and sets `Content-Type`, `Content-Length`, and
  `Content-Disposition`.

  ```ruby
  Rivulet::Response.new(
    status: 200,
    format: :file,
    body:   { path: '/app/files/report.pdf', disposition: 'attachment' }
  )
  ```

- `:stream` — body must be IO-like (responds to `gets`, `each`, `read`,
  `rewind`); wrapped in a streaming body with no automatic headers.
- `:as_is` — body is passed through unchanged with no automatic headers.

Statuses `204` and `304` require `body: nil` (a body with these statuses
is a validation error).

### Calling Services from Handlers

Handler operations do not call services directly from the operation body.
They delegate through a **step** that acts as the transport↔domain boundary:
it invokes the service, then translates the service result into a
`Rivulet::Response` on both the success and failure paths. The operation
returns the monad this step produces (see [Handler Output](#handler-output)),
which the framework's dispatch step unwraps.

Services are registered in the top-level `Services` container
(`app/services.rb`) under their domain key. A handler step reaches one with
`Services['users']`; the generated `Service` object forwards action names
via `method_missing` to the domain's `operations.<action>` key — the same
dispatch pattern handlers use:

```ruby
Services['users'].create_user(resource: User, attributes: input[:params])
# dispatches to Services::Users::Container['operations.create_user']
```

Services return `Success(input)` (where `input[:data]` holds the projected
output) or `Failure[:error_type, payload]` — never a `Rivulet::Response`.
The calling step builds the response on both paths:

```ruby
module Handlers
  module Users
    module Steps
      class CreateUser < Rivulet::Step
        def call(input)
          result = Services['users'].create_user(
            resource:   User,
            attributes: input[:params]
          )

          case result
          in Success(service_input)
            response = Rivulet::Response.new(
              status: 201,
              body:   { data: service_input[:data] }
            )
            Success(response)
          in Failure[:validation, errors]
            response = Rivulet::Response.new(
              status: 422,
              body:   { errors: errors }
            )
            Failure(response)
          in Failure[type, payload]
            response = Rivulet::Response.new(
              status: 500,
              body:   { error: type, detail: payload }
            )
            Failure(response)
          end
        end
      end
    end
  end
end
```

The handler operation chains this step (optionally after transport-level
steps such as auth or context enrichment) and returns the result:

```ruby
class Create < Rivulet::Operation
  include Import[create_user: 'steps.create_user']

  def call(input = {})
    result = step create_user.(input)
    result
  end
end
```

Such a step usually lives per-operation in `app/handlers/<domain>/steps/`,
since it knows the specific service action and model class. When the
delegation logic is uniform across domains, extract it to
`app/handlers/shared/steps/` and inject the service key and model class
rather than hardcoding them.

### Services

Services encapsulate business use cases and remain independent from transport
concerns. A service domain is organized into operations, steps, contracts,
projections, and utils. Generate a service with:

```bash
rivulet g service users --create --read --update --delete --list
```

Running `rivulet g service operation users.create_user` creates both the
operation file and its corresponding contract, and ensures the `projections/`
directory exists. Generate a projection separately with
`rivulet g service projection users.common`.

#### Service Input

Service operations receive an input hash of the form:

```ruby
{
  resource:   Post,                                  # a model class (DI slot)
  attributes: { name: 'John Doe', email: 'john.doe@example.com' }
}
```

The `resource` slot is a dependency-injection point: it enters as a model
class (e.g. `Post`, or any ancestor/subclass) and is substituted with a
persisted instance as the pipeline progresses — for example, a `create` step
replaces `input[:resource]` with the saved record. The contract is
responsible for validating the `resource` type (allowed classes/ancestors)
alongside `attributes`. This shape is distinct from the handler input
(`{ params:, context: }`) — services never receive transport structures.

#### Contracts

Contracts define and validate service input using `dry-validation`. They
describe exactly what a service needs and enforce correctness before business
logic runs. Contracts subclass `ApplicationContract` (in
`app/application_contract.rb`) and are registered in the service container
under the `contracts` namespace. `ApplicationContract` is a base class only —
the shared `validate` step that runs a contract must be created in
`services/shared/steps`.

A contract must declare and validate **every input the operation needs to
run** — not just the flat business attributes. This includes `:resource`
(the model class, type-checked), `:attributes` (the business fields), and
`:current_user` (for authorization). For example, a `list_users` operation
that queries the User model and checks the acting user declares both:

```ruby
class List < ApplicationContract
  params do
    required(:resource).value(type?: Class)      # model class to query
    required(:current_user).value(type?: User)   # acting user, for authz
    optional(:page).value(:integer)
    optional(:per_page).value(:integer)
  end
end
```

A `create_user` operation declares `:resource`, `:current_user`, and the
`:attributes` hash together:

```ruby
class CreateUser < ApplicationContract
  params do
    required(:resource).value(type?: Class)
    required(:current_user).value(type?: User)
    required(:attributes).hash do
      required(:name).filled(:string)
      required(:email).filled(:string)
    end
  end
end
```

> The shared `Validate` step returns `Success(result.to_h)`, and
> `result.to_h` carries **only the keys declared in the contract** —
> undeclared keys are dropped. So a complete contract is what makes
> `:resource`, `:current_user`, and `:attributes` available to the rest of
> the pipeline. This is why the `Validate` template stays as-is (no
> `input.merge(result.to_h)` needed): if the contract declares everything,
> `result.to_h` already carries it all. An empty or partial contract isn't a
> placeholder — it's a bug that silently drops the operation's inputs.

Use a custom predicate to tighten `:resource` to specific classes or
ancestors (e.g. `value <= User`) when only certain models are allowed.

#### Projections

Projections define a service's output structure using `dry-transformer`,
keeping persistence models out of the response. They transform results into
an explicit shape describing which fields are exposed to callers. Projections
subclass `Rivulet::Projection` and are registered under the `projections`
namespace. `Rivulet::Projection` is a base class only — the shared `project`
step that applies a projection must be created in `services/shared/steps`.

A projection declares its transformations in a `define!` block. `accept_keys`
keeps only the listed keys (a slice), exposing exactly the fields callers
should see and dropping internal ones:

```ruby
module Services
  module Users
    module Projections
      class Common < Rivulet::Projection
        define! do
          accept_keys [:id, :name, :email]
        end
      end
    end
  end
end
```

`Common.new.call(id: 1, name: 'Jane', email: 'j@e.org', password_digest: '...')`
returns `{ id: 1, name: 'Jane', email: 'j@e.org' }`. The shared `project` step
applies it: `projection.call(input[:resource])` (see the `project` step
above). Transformations compose left-to-right within `define!`, so you can
chain e.g. `rename_keys` or `map_value` after `accept_keys`.

Every projection must have a `define!` block with at least one transformation.
The generator produces empty projection classes — fill them before use: an
empty projection (no transformations) raises `NoMethodError` at runtime when
the `project` step calls it, and even if it didn't, it would leak internal
fields. Always declare the exposed fields explicitly, e.g. with `accept_keys`.

#### Background Jobs

Services are transport-agnostic and can be invoked from background jobs,
message consumers, CLI commands, or any other runtime — not just handlers.
Place background job definitions alongside the service domain they belong to.
A job calls a service operation the same way a handler does, passing an input
hash and consuming the result.

### Routing

Routes are defined in `config/routes.rb` via `Rivulet.routes.draw`:

```ruby
Rivulet.routes.draw do
  get  '/posts',     to: 'posts#index'
  post '/posts',     to: 'posts#create'
  get  '/posts/:id', to: 'posts#show'
  put  '/posts/:id/publish', to: 'posts#publish'
end
```

HTTP methods: `get`, `post`, `put`, `patch`, `delete`.

The `to:` option accepts two forms:

- String — `'posts#show'` maps to `Handlers['posts'].show`
- Hash — `{ to: :posts, action: :index }` (alternative explicit syntax)

Path parameters (e.g. `:id`) become part of the input hash available to
steps. Multiple params are supported in a single route:

```ruby
get '/organizations/:org_id/users/:id', to: 'users#show'
# input[:params] => { org_id: '1', id: '42' }
```

Scopes prefix a group of routes:

```ruby
scope(:organizations) do
  get    '/users',     to: 'users#index'
  post   '/users',     to: 'users#create'
  get    '/users/:id', to: 'users#show'
end
# produces /organizations/users, /organizations/users/:id, etc.
```

List all registered routes with `rivulet routes`.

#### Handler Dispatch

The generated `Handler` forwards actions via `method_missing` to
`Container['operations.<action>']` — e.g. `Handlers::Posts::Handler.new.show`
resolves `operations.show` in the posts container and calls it. The framework
invokes the route callable with `params:` and `context:`, which becomes the
operation's `input` hash (see [Handler Input](#handler-input)).

## Conventions

- Operations chain steps with `step foo.(result)` and return `result`.
  The operation defines flow; steps perform the work.
- Steps return `Success(input)` / `Failure(...)` and enrich a shared
  input hash. A failure short-circuits the pipeline.
- Handler output is `Success(Rivulet::Response)` / `Failure(Rivulet::Response)`,
  produced by a step — not constructed bare in the operation.
- Services return `Success(input)` / `Failure(...)` where the input
  contains the current execution state. Services never produce
  `Rivulet::Response` — that is a transport-layer object. On failure, use
  `Failure[:error_type, payload]` — a `Failure` monad wrapping a two-element
  array: a symbol error type and a payload. For example, validation failures
  use `Failure[:validation, result.errors.to_h]`. The handler layer maps
  this to an HTTP response.
- App code under `app/` is autoloaded by Zeitwerk (eager-loaded at startup).
  No manual requires — place files per the directory convention.
- Dependencies are injected via `include Import[name: 'steps.name']`;
  keys resolve against the domain's `Container`.
- `Import` is auto-built per class by an `inherited` hook that walks the class
  name up to `Operations` or `Steps` and appends `Container`. So
  `Services::Users::Steps::CreateUser` resolves keys against
  `Services::Users::Container`. Shared steps are reachable because each domain
  container does `import Services::Shared::Namespace` /
  `import Handlers::Shared::Namespace`.
- Container `namespace('steps') do ... end` blocks are maintained manually —
  generators regex-insert registrations after the `namespace` line. Preserve
  these blocks when hand-editing `container.rb`.
- Plain `Sequel::Model` subclasses in `app/models` work with zero setup. The
  framework sets `Sequel::Model.db` and `require_valid_table = false` at
  startup, so no `DB = Sequel.connect` boilerplate and no base class are needed.
- Handlers are registered in `app/handlers.rb`:
  `register('posts') { Handlers::Posts::Handler.new }`.
- Config: `config/application.rb`. Routes: `config/routes.rb`.

## Common Tasks

### Add an endpoint

1. Generate a handler: `docker compose exec app rivulet g handler posts --list`
2. Generate operations/steps:
   `docker compose exec app rivulet g handler operation posts.show`,
   `docker compose exec app rivulet g handler step posts.load_post`
3. Add a route in `config/routes.rb`: `get '/posts/:id', to: 'posts#show'`
4. Implement the steps, then the operation that chains them.

### Add a migration

1. `docker compose exec app rivulet g migration create_users`
2. Edit `db/migrations/<timestamp>_create_users.sql`
3. `docker compose exec app rivulet db migrate`

Migrations are plain SQL, forward-only. The filename must be
`YYYYMMDDHHMMSS_name.sql`. The runner executes the **entire file as one
statement** (`db.run(File.read(path))`) — no Ruby DSL, no `down`/rollback.
Applied versions are tracked in the `schema_migrations` table. Each migration
must be self-contained SQL; there is no `drop`/`alter` safety net.

## Gotchas

- All `rivulet` CLI commands run inside the container via
  `docker compose exec app rivulet` (with the stack up via `docker compose up`).
  Do not run `bundle exec rivulet` on the host.
- Zeitwerk eager-loads `app/` at startup — misplaced files won't be found.
- Steps must return a monad (`Success`/`Failure`); returning a bare value
  breaks the pipeline.
- No session middleware is configured by default, so `context.session` is
  `nil` unless you add Rack session middleware yourself.
- No auth gem ships in the Gemfile — build it from scratch. Authentication
  (password hashing, token issuance, `authenticate`) lives in
  `handlers/shared/`; authorization (`authorize_*`, access policies) lives
  in `services/shared/`, since access rights are a business requirement.
- No plain modules in `handlers/` or `services/` — every helper is either a
  `Rivulet::Step` (monad, pipeline) or a registered util (direct result,
  injected via `Import`). Don't `include` ad-hoc modules into steps; register
  them in the container instead.
- Keep nesting in routes shallow and meaningful — express context, not the
  full domain hierarchy.
