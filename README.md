<p align="center">
  <img src="docs/logo.png" alt="Rivulet" width="200">
</p>

<h1 align="center">Rivulet</h1>

A lightweight Rack framework built around Railway Oriented Programming, `dry-rb`, `falcon`, and `Sequel`.

## Requirements

* Docker

## Quick Start

### Create a New Application

Use the published base image to scaffold a new project:

```bash
docker run --rm \
  -v $(pwd):/app \
  mrvold/rivulet:latest \
  new blog
```

The image is pulled automatically on first run if you don't have it locally.

To include a database, pass `--with-db`:

```bash
docker run --rm \
  -v $(pwd):/app \
  mrvold/rivulet:latest \
  new blog --with-db=postgres
```

Supported adapters: `postgres`, `sqlite`, `mysql`. Omit the flag for no database.

### Run the Application

The generated project includes a `Dockerfile` and a `docker-compose.yml`.
When created with `--with-db=postgres` or `--with-db=mysql`, compose also runs
a database service. On first run, compose builds the application image from
the base image:

```bash
docker compose up
```

Rebuild after changing the application's `Gemfile`:

```bash
docker compose up --build
```

The application will be available at:

```text
http://localhost:9292
```

## Database

Create a migration:

```bash
bundle exec rivulet g migration create_users
```

Run migrations:

```bash
bundle exec rivulet db migrate
```

## CLI

Show all available commands:

```bash
bundle exec rivulet --help
```

Show generator options:

```bash
bundle exec rivulet g --help
```

## Documentation

* Architecture & Design — `docs/architecture.md`

## License

Apache 2.0
