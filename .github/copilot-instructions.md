# LLM Agent Instructions for `que-scheduler` Repository

This document provides guidance and best practices for LLM coding agents working on the `que-scheduler` codebase.

## General Principles:

*   **Understand the Goal:** Before making changes, ensure you have a clear understanding of the issue or feature request. Ask for clarification if needed.
*   **Targeted Changes:** Strive to make minimal, targeted changes. Avoid altering unrelated code or reformatting files unnecessarily, as this can introduce noise and potential regressions.
*   **Read Existing Code:** Familiarize yourself with the surrounding code and patterns before introducing new logic. Aim for consistency with the existing style.
*   **Dependencies:** Be mindful of adding new gem dependencies. Only add them if necessary and ensure they are added to the `que-scheduler.gemspec` file.
*   **Testing is Crucial:** All code changes *must* be accompanied by tests, or existing tests must be updated. Changes should not be submitted if tests are failing.

## Development Workflow:

1.  **Create a Plan:** Before writing code, outline the steps you will take. Use the `set_plan` tool.
2.  **Implement Changes:** Write or modify the code according to your plan.
3.  **Write/Update Tests:** Ensure your changes are covered by RSpec tests.
4.  **Run Tests:** Execute the test suite to confirm your changes pass and haven't broken existing functionality.
5.  **Commit and Submit:** Use clear and descriptive commit messages.

## Running Tests (`./specs.sh`):

Executing tests is a critical step. The primary script for running tests is `./specs.sh`.

### Test Environment Prerequisites:

*   **Ruby:** Version 3.0 or higher (CI uses 3.2, 3.3, 3.4).
*   **Bundler:** For Ruby gem management.
    *   Ensure it's installed (`gem install bundler`).
    *   Install project dependencies: `bundle install`.
*   **PostgreSQL:** Version 9.6 is used in CI.
    *   The tests require a running PostgreSQL instance.
    *   Connection details (likely expected via environment variables or default Rails conventions):
        *   Host: (e.g., `localhost` or a Docker container IP)
        *   Port: `5432`
        *   User: `postgres`
        *   Password: `postgres`
        *   Database: `postgres` (or a specific test database name)
*   **Environment Setup:** The CI workflow (`.github/workflows/specs.yml`) is the definitive source for setup:
    1.  `actions/checkout@v4`
    2.  `ruby/setup-ruby@v1` (this step usually handles Bundler installation)
    3.  `./specs.sh` (runs the RSpec tests)
    4.  `./quality.sh` (runs linters/static analysis)

### To Run Tests Locally (Conceptual):

1.  Ensure Ruby (e.g., 3.2) is installed and active.
2.  Install Bundler: `gem install bundler`.
3.  Navigate to the project root.
4.  Install dependencies: `bundle install`.
5.  Ensure a PostgreSQL 9.6 server is running and accessible with credentials: user `postgres`, password `postgres` on the default port `5432`, with a database named `postgres`. (Environment variables like `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` might be respected by the test setup or `database.yml` if used).
6.  Execute the test script: `./specs.sh`.

**Note:** If `./specs.sh` fails due to environment issues, consult the CI configuration in `.github/workflows/specs.yml` for the exact setup commands and service configurations.

## Code Style and Quality:

*   **RuboCop:** This project likely uses RuboCop for linting and style enforcement. Pay attention to its output and try to fix any reported offenses. The `./quality.sh` script might run RuboCop.
*   **Comments:** Add comments to explain complex logic or non-obvious decisions.
*   **Sorbet:** This project is transitioning to Sorbet for type checking.
    *   When modifying existing files that use Sorbet, ensure type signatures (`sig`) are updated or added appropriately.
    *   For new classes or methods, try to add Sorbet type signatures.
    *   `T::Struct` is preferred over `Hashie::Dash` for structured data.

## Specific Gotchas for this Repository:

*   **`Hashie::Dash` to `T::Struct` Migration:** The project is moving from `Hashie::Dash` to `T::Struct`. When encountering `Hashie::Dash`, the goal is to replace it. This involves:
    *   Changing inheritance from `Hashie::Dash` to `T::Struct`.
    *   Replacing `property` with `const`.
    *   Defining types for each `const` (e.g., `String`, `T.nilable(Integer)`, `T::Array[String]`).
    *   Removing `include Hashie::Extensions::Dash::PropertyTranslation`.
    *   Adjusting constructor calls (`new(...)`) and data access to align with `T::Struct` conventions.
    *   Adding `extend T::Sig` to the class and `sig` blocks to methods.
*   **Gemfile vs. Gemspec:** Runtime dependencies should be in `que-scheduler.gemspec`. Development dependencies are typically in the `Gemfile` or also in the `gemspec`'s `add_development_dependency` section.

By following these guidelines, you can contribute effectively to the `que-scheduler` repository. If you are unsure about any step, please ask for clarification.
