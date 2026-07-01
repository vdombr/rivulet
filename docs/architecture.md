# Rivulet Architecture & Design

## Design Philosophy

Rivulet is designed for **predictability** and **explicit error handling**. By leveraging Railway Oriented Programming (ROP), the framework eliminates hidden control flows commonly found in traditional web frameworks. Every step of a request's lifecycle is an explicit transformation, making the system easy to trace, test, and extend.

### Put More Effort into Writing than Reading

One of the core principles of Rivulet is making business domains and workflows easy to understand. This is achieved through architectural conventions and design restrictions that encourage self-documenting code.

Operations, steps, contracts, routes, and containers should communicate not only execution flow but also intent.

### Design for Reuse, Not for Abstraction

Rivulet does not discourage copy-paste when it improves clarity or avoids premature abstraction. Reuse should emerge from real patterns rather than from attempts to eliminate every duplication.

At the same time, developers are encouraged to design components so they can be easily extracted, shared, and connected as plug-and-play building blocks when reuse becomes valuable.

Operations, steps, shared components, and utilities should favor explicit interfaces and minimal coupling, making them easy to move between domains, applications, or shared libraries without significant modification.

The goal is not to maximize abstraction, but to make reuse straightforward when it naturally occurs.

### Be Explicit, Less Magic

There are no hidden variables, implicit context objects, or parent classes that redefine behavior behind the scenes.

All dependencies, parameters, and execution context are passed explicitly through the application flow.

## Architecture

Rivulet separates transport concerns from domain concerns through two independent execution layers.

### Handlers

Handlers represent the transport layer.

They are responsible for:

* Processing incoming requests.
* Preparing execution context.
* Delegating work to services in the domain layer.
* Producing HTTP responses.

### Services

Services represent the domain layer.

They are responsible for:

* Executing business use cases.
* Coordinating domain-specific workflows.
* Managing resource lifecycles.
* Remaining independent from HTTP and transport concerns.

Services can be executed from handlers, background jobs, CLI commands, message consumers, or any other runtime environment.

### Shared Architectural Model

Services are organized around domains rather than technical layers.

```text
services/
├── shared/
└── users/
    ├── operations/
    ├── steps/
    └── utils/
```

Each service domain contains its own operations, steps, and utilities, while reusable domain-agnostic components live under `services/shared`.

Handlers follow the same domain-oriented approach:

```text
handlers/
├── shared/
└── users/
    ├── operations/
    ├── steps/
    └── utils/
```

Handler domains contain transport-specific operations, steps, and utilities, while reusable request-processing components live under `handlers/shared`.

Although handlers and services serve different responsibilities, they share the same architectural concepts:

* Operations define execution flow.
* Steps perform work.
* Shared components provide reusable pipeline behavior.
* Utils encapsulate implementation details.

This consistency allows developers to use the same programming model throughout the framework while maintaining a clear separation between transport and domain concerns.

## Routing

Rivulet provides a lightweight routing DSL inspired by Rails.

Routes map incoming requests to handler operations.

Examples:

```ruby
get  '/users/:id', to: 'users#show'
post '/users',     to: 'users#create'
```

An alternative explicit syntax is also supported:

```ruby
get :users, to: :users, action: :index
```

### URL Parameters

Routes support dynamic path segments through named parameters.

```ruby
get '/users/:id', to: 'users#show'
```

produces:

```ruby
{
  params: {
    id: "123"
  }
}
```

Nested resources are supported as well:

```ruby
get '/organizations/:org_id/users/:id', to: 'users#show'
```

which produces:

```ruby
{
  params: {
    org_id: "1",
    id: "42"
  }
}
```

Path parameters become part of the request input and are available throughout the execution pipeline.

### Routing Philosophy

Routing belongs to the transport layer and should not influence domain behavior.

Its responsibility is to expose use cases through HTTP and transform request data into a format that can be consumed by handlers and services.

Once execution reaches a service operation, the origin of a parameter becomes irrelevant. A service should behave identically regardless of whether it was invoked from an HTTP request, a background job, a Kafka consumer, a CLI command, or any other entry point.

Services should depend on input data, not on how that data was delivered.

### Context over Hierarchy

Route structure should communicate the context required to execute an operation.

For example:

```ruby
get '/organizations/:org_id/users'
```

clearly indicates that users are being accessed within the context of a specific organization.

Nested routes are encouraged when the relationship between resources is meaningful to the operation being performed.

Examples:

```text
/organizations/:org_id/users
/orders/:order_id/items
```

However, nesting should remain reasonable.

Avoid using URLs to mirror the entire domain model:

```text
/organizations/:org_id/departments/:department_id/teams/:team_id/users/:id
```

Deep route hierarchies often introduce implementation details into the transport layer and make APIs harder to understand.

The goal is to express execution context, not to model the complete object graph.

### Resource and Action Routes

Resource-oriented routes are encouraged:

```ruby
get    '/users/:id'
post   '/users'
patch  '/users/:id'
delete '/users/:id'
```

However, not every business operation maps naturally to CRUD semantics.

When an action represents a meaningful business operation, it may be expressed explicitly in the route:

```ruby
put  '/users/:id/block'
put  '/users/:id/unblock'

post '/orders/:id/cancel'
post '/organizations/:id/invite'
```

Clarity is more important than strict adherence to REST conventions.

### Design Guidelines

Routes should:

* Be easy to map to a handler or service operation.
* Express only the context required for the use case.
* Use path parameters for resource identification.
* Keep nesting shallow and meaningful.
* Prioritize readability and discoverability.

Routes should not:

* Mirror the entire domain hierarchy.
* Expose persistence-layer relationships.
* Depend on implementation details of the domain layer.

A well-designed route should make the purpose of an operation obvious while remaining independent from the implementation of the underlying business logic.

## Operations

Operations represent application use cases.

Their responsibility is to define execution flow rather than implement business logic.

An operation composes reusable steps into an explicit Railway pipeline and orchestrates how data moves through the system.

Example:

```ruby
def call(input = {})
  result = step validate.(input, contract)
  result = step create_user.(result)
  result = step project.(result, projection)

  result
end
```

### Data Flow

Operations receive an input hash as their entry point.

Each step receives the current state of the input and may:

* Read existing values.
* Add new values.
* Modify existing values.
* Return a transformed version of the input.

As execution progresses, the input is enriched and transformed by each step.

For example, a service operation may start with:

```ruby
{
  resource: Post,
  attributes: { ... }
}
```

then, after validation, remain the same shape (now validated):

```ruby
{
  resource: Post,
  attributes: { ... }
}
```

and after a create step that substitutes the persisted instance:

```ruby
{
  resource: #<Post instance>,
  attributes: { ... }
}
```

Handler operations use a different input shape — `{ params:, context: }` —
as described in [Handler Conventions](#handler-conventions).

This approach eliminates hidden state and makes every transformation explicit.

### Responsibilities

Operations should:

* Define use-case execution flow.
* Compose steps into pipelines.
* Pass data between pipeline stages.
* Prepare arguments for individual steps.
* Remain easy to read and reason about.

Operations should not:

* Contain business logic.
* Access databases directly.
* Communicate with external services directly.
* Implement reusable workflow behavior.

The operation defines the workflow. The steps perform the work.

## Steps

Steps are the executable units within an operation.

They represent the individual actions required to complete a use case and serve as the primary building blocks of a Railway pipeline.

A step should perform one clearly defined responsibility, such as:

* Validating input data.
* Loading a resource.
* Persisting changes.
* Authorizing access.
* Applying a projection.
* Transforming execution context.

Each step receives the current execution state and returns either:

* `Success(input)`
* `Failure(input)`

Following the Railway Pattern, a failure immediately short-circuits execution and returns control to the caller.

Because steps operate on a shared execution context, they can incrementally enrich and transform the input as it flows through the pipeline.

Steps should be:

* Small and focused.
* Easy to test in isolation.
* Reusable across multiple operations when appropriate.
* Responsible for a single piece of work.

Steps should not:

* Orchestrate execution flow.
* Contain unrelated responsibilities.
* Depend on hidden state.

Operations define the workflow. Steps perform the work.

## Shared

Shared components provide reusable pipeline steps within a layer.

Each layer maintains its own Shared namespace:

* `handlers/shared`
* `services/shared`

Shared components encapsulate cross-cutting concerns that are reused throughout a layer while remaining independent from a specific domain.

### Handler Shared

Handler Shared components focus on transport-level concerns.

Examples include:

* JWT validation and decoding.
* Current user resolution.
* Request metadata extraction.
* Header normalization.
* Context enrichment.

### Service Shared

Service Shared components focus on domain-agnostic business operations.

Examples include:

* Contract validation.
* Pagination.
* Sorting and filtering.
* Resource loading.
* Projection generation.
* Generic authorization policies.

These steps can be reused across multiple services without introducing coupling to a specific resource or domain.

### Design Guidelines

Shared components should:

* Operate on abstract requests, resources, collections, or execution context.
* Remain independent of any specific business domain.
* Be composable within Railway pipelines.
* Encapsulate commonly repeated workflow operations.

Shared components should not:

* Contain business-specific rules.
* Depend on a particular resource type unless explicitly intended.
* Replace domain services.

When logic becomes specific to a business capability, it should be implemented within a dedicated service instead of Shared.

## Utils

Utils are single-purpose objects responsible for encapsulating implementation details.

Their purpose is to keep operations and steps focused on orchestration rather than low-level execution logic.

Unlike Steps and Shared components, utilities do not participate in Railway pipelines and should return direct results rather than monads.

Utilities typically expose a simple interface with explicit arguments and return direct results.

Utilities are registered within the container and injected using `include Import[]` in steps.

### Typical Use Cases

* External API clients.
* Complex calculations.
* Data transformation.
* Serialization and deserialization.
* Token generation and verification.
* File processing.

### Shared and Domain Utilities

Utilities may belong either to a specific domain or to a Shared namespace.

Domain-specific utilities support a single service or handler domain.

Examples:

* Payment gateway clients.
* Pricing calculators.
* Report generators.

Shared utilities provide functionality reusable across multiple domains.

Examples:

* JWT helpers.
* Generic HTTP clients.
* Cryptographic utilities.
* Serialization helpers.

### Design Guidelines

Utils should:

* Have a single responsibility.
* Accept explicit arguments.
* Return direct results.
* Be easy to test in isolation.
* Encapsulate implementation details.

Utils should not:

* Control application flow.
* Orchestrate workflows.
* Depend on pipeline state.
* Replace services or shared steps.

Services and Shared Steps define what should happen. Utilities define how a specific task is performed.

## Handler Conventions

Handlers act as pure request transformations.

### Input

Handlers receive a hash containing:

* `params`
* `context`

The context typically contains request metadata such as headers, authentication data, and current user information.

### Output

Handlers always return a `Rivulet::Response` wrapped in a monad:

* `Success(Rivulet::Response)`
* `Failure(Rivulet::Response)`

This guarantees that the framework always receives a valid response object regardless of whether execution reaches the end of the pipeline or terminates early through a failure path.

### Rivulet::Response

`Rivulet::Response` is the standardized transport response object used throughout the framework.

Successful response:

```ruby
Success(
  Rivulet::Response.new(
    status: 200,
    body: {
      data: resource
    },
    headers: {
      "Content-Type" => "application/json"
    }
  )
)
```

Failure response:

```ruby
Failure(
  Rivulet::Response.new(
    status: 422,
    body: {
      error: "validation_failed"
    }
  )
)
```

Attributes:

* `status` — HTTP status code.
* `body` — response payload.
* `headers` — optional HTTP headers.

The framework extracts the enclosed response object regardless of whether it arrives through a success path or a short-circuited failure path.

## Service Conventions

Services encapsulate business use cases and remain independent from transport concerns.

### Input

Services typically receive an input hash containing the resources and attributes required to execute the use case.

For example:

```ruby
{
  resource: Post,
  attributes: { name: 'John Doe', email: 'john.doe@example.com' }
}
```

The `resource` slot acts as a dependency-injection point: it enters as a
model class (e.g. `Post`, or any ancestor/subclass) and may be substituted
with a persisted instance as the pipeline progresses (e.g. after a create
step). The contract is responsible for validating the `resource` type —
including allowed classes or ancestors — alongside the `attributes`.

### Output

Services return either:

* `Success(input)`
* `Failure(input)`

where the input hash contains the current execution state.

### Validation

Services are expected to utilize contracts for data validation before performing business operations.

A shared `Validate` step runs the contract against the input and returns
`Success(result.to_h)` on success, or
`Failure[:validation, result.errors.to_h]` on errors:

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

### Projection

Projections define the output contract of a service.

Rather than exposing persistence-layer models directly, services transform their results into an explicit structure that describes exactly which fields, relationships, and transformations are available to callers.

Rivulet currently uses `dry-transformer` for building projections. Keeping projections declarative makes service outputs predictable, easy to reason about, and independent from underlying persistence implementations. This creates a clear boundary between domain logic and the data exposed to higher layers.

## Contracts

Contracts define and validate the input required by a service operation.

Rivulet uses `dry-validation` to describe expected data structures and enforce input correctness before business logic is executed.

Beyond validation, contracts serve as explicit documentation of a service's requirements.

A contract should describe exactly what a service needs in order to perform its work.

For example, if a service only requires an IP address and a User-Agent, the contract should explicitly define those attributes:

```ruby
required(:ip).filled(:string)
required(:user_agent).filled(:string)
```

rather than accepting a larger object such as:

```ruby
required(:request)
```

and extracting values internally.

Explicit contracts make dependencies visible, improve testability, and reduce coupling between services and transport-specific objects.

### Responsibilities

Contracts should:

* Validate input data.
* Define the input boundary of a service.
* Describe required and optional attributes explicitly.
* Remain independent of transport-layer abstractions.

Contracts should not:

* Contain business logic.
* Perform side effects.
* Depend on HTTP request objects or framework-specific structures.

### Design Philosophy

Services should receive only the data they actually require.

Passing explicit attributes through contracts creates a clear and stable interface between callers and service operations, regardless of whether the service is invoked from HTTP, background jobs, message consumers, or CLI commands.

The smaller and more explicit a contract is, the easier the service becomes to understand, test, and reuse.
