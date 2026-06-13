# Rivulet

A small, powerful Rack web framework built on the `dry-rb` ecosystem and `Sequel`.

Rivulet is designed for developers who appreciate the modularity and type-safety of the `dry-rb` suite. It leverages `dry-operation` for pipeline-based business logic, `dry-monads` for error handling via `Success`/`Failure`, and `Sequel` for robust database interactions.

## Key Features

- **Built on `dry-rb`**: Utilizes `dry-operation`, `dry-monads`, `dry-configurable`, `dry-auto_inject`, and more to provide a predictable, composable architecture.
- **Pipeline-based Logic**: Business logic is encapsulated in **Operations** composed of discrete, reusable **Steps**.
- **Rails-like Routing**: A familiar DSL for defining routes (`get`, `post`, `resources`, `namespace`, `scope`).
- **Powerful CLI**: A comprehensive command-line interface for scaffolding resources, services, handlers, and managing database migrations.
- **Database Integration**: Seamlessly integrates with `Sequel` for all database operations.
- **Container-First Development**: Designed to run easily within Docker environments.

## Getting Started

### Prerequisites

- [Docker](https://www.docker.com/)

### Running with Docker

The easiest way to work with Rivulet is using the provided Docker configuration.

1.  **Build the image:**
    ```bash
    docker build -t rivulet .
    ```

2.  **Create a new application:**
    ```bash
    docker run --rm -v $(pwd):/app rivulet bundle exec rivulet new my_app
    ```

## CLI Usage

The `rivulet` CLI is your primary tool for application development and scaffolding.

### Application Management

| Command | Description |
| :--- | :--- |
| `new APP_NAME` | Generates a new Rivulet application. |
| `console` (or `c`) | Opens an interactive Ruby console within the app context. |
| `routes` | Lists all registered routes in the application. |

### Database Management

| Command | Description |
| :--- | :--- |
| `db migrate` | Runs pending database migrations. |

### Scaffolding (Generation)

Use the `generate` (or `g`) command to scaffold various components:

| Command | Description |
| :--- | :--- |
| `g resource NAME` | Generates a new resource. |
| `g service [operation\|step] NAME` | Generates a new service operation or step. |
| `g handler [operation\|step] NAME` | Generates a new handler operation or step. |
| `g migration NAME` | Creates a new database migration file (plain SQL). |
