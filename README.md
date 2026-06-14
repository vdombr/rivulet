<p align="center">
  <img src="docs/logo.png" alt="Rivulet" width="200">
</p>

<h1 align="center">Rivulet</h1>

A lightweight Rack framework built around Railway Oriented Programming, `dry-rb`, and `Sequel`.

## Requirements

* Docker

## Quick Start

### Build the Framework Image

```bash
docker build -t rivulet .
```

### Create a New Application

```bash
docker run --rm \
  -v $(pwd):/app \
  rivulet \
  bundle exec rivulet new blog
```

### Enter the Project

```bash
cd blog
```

### Run the Application

```bash
docker run --rm \
  -p 9292:9292 \
  -v $(pwd):/app \
  rivulet
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
