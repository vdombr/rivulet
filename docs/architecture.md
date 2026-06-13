# Rivulet Architecture & Design

## Design Philosophy
Rivulet is designed for **predictability** and **explicit error handling**. By leveraging Railway Oriented Programming (ROP), the framework eliminates the "hidden" control flows common in traditional web frameworks. Every step of a request's lifecycle is an explicit transformation, making the system easy to trace, test, and extend.

### Put more effort into writing than reading
One of the main principles of this framework is to make the business domain and its logic easy to understand. This is achieved through an architectural backbone of conventions and design restrictions. Contracts, operations, routes, and containers should present not only control flow, but also self-documentation.

### Be explicit, less magic
There are no hidden variables or parent/ancestor classes that redefine methods or fail when a method is not implemented. All parameters and context needed to execute logic are passed explicitly through the data flow.

## Architecture
Rivulet utilizes a layered architecture that separates the transport layer from business logic:

*   **Routing**: Uses a Rails-style DSL to map HTTP verbs and paths to specific controllers.
*   **Handlers (Transport Layer)**: Act as the interface between the network and the application. They are responsible for parsing requests and formatting responses.
*   **Services (Domain Layer)**: Encapsulate all business logic. Services are decoupled from the HTTP layer, making them easily executable in isolation or via CLI.
*   **Models (Data Layer)**: Utilize Sequel models for database interaction, though the framework supports a Repository pattern for greater abstraction.

The framework relies on `dry-operation` and `dry-monads` to implement the **Railway Pattern**, ensuring that failures are treated as first-class citizens in the application flow.

## Conventions

Rivulet is built around **contractual interfaces**. The framework's strength lies in its "plug-and-play" nature, achieved through strict adherence to expected input and output shapes:

### Handlers
A handler must act as a pure transformation of a request. 
*   **Input**: A hash containing `params` (request data) and `context` (headers/current user).
*   **Output**: A hash containing `body`, `headers`, and `status`.

### Services
Services follow a functional approach to business logic.
*   **Input**: A hash containing the target `resource` and required `attributes`.
*   **Output**: A `Success` monad (containing the updated resource) or a `Failure` monad (containing a standardized error symbol).
*   **Validation**: Services are expected to utilize contracts (e.g., `dry-validation`) to enforce data integrity before processing.
*   **Projection**: Services must not leak their data layer into upper layers through `resource`. Projections are used to define which fields are returned in the output.
