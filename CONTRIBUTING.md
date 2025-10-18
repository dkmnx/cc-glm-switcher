# Contributing

We welcome contributions! Please follow these guidelines to ensure a smooth review process.

## Development Workflow

1. **Fork the repository** and clone your fork locally
2. **Create a feature branch** from the main branch:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```
3. **Make your changes** following the guidelines below
4. **Test thoroughly** before submitting:
   ```bash
   # Run the complete test suite
   ./tests/run_all_tests.sh

   # Run with verbose output for debugging
   ./tests/run_all_tests.sh --verbose

   # Test with dry-run functionality
   ./cc_glm_switcher.sh glm --dry-run
   ./cc_glm_switcher.sh cc --dry-run
   ```
5. **Ensure all tests pass** before submitting your PR
6. **Submit a pull request** with a clear description of your changes

## Code Quality Standards

### Shell Script Guidelines
- **Use shellcheck**: All shell scripts must pass shellcheck validation:
  ```bash
  # Check the main script
  shellcheck cc_glm_switcher.sh

  # Check test scripts
  shellcheck tests/*.sh
  ```
- **Follow best practices**:
  - Use `set -euo pipefail` for error handling
  - Quote variables properly: `"$VAR"` instead of `$VAR`
  - Use `readonly` for constants
  - Add comments for complex logic
  - Use functions for reusable code

### Code Style
- **Indentation**: Use 4 spaces (no tabs)
- **Line length**: Keep lines under 100 characters when possible
- **Naming conventions**:
  - Functions: `snake_case` with descriptive names
  - Variables: `UPPER_SNAKE_CASE` for constants, `lower_snake_case` for variables
  - Files: `lowercase-with-dashes.sh`

## Commit Message Standards

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. All commit messages must follow this format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Commit Types
- `feat`: New features or functionality
- `fix`: Bug fixes
- `docs`: Documentation changes
- `style`: Code style changes (formatting, missing semicolons, etc.)
- `refactor`: Code refactoring without functional changes
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates, etc.

### Examples
```bash
feat: add GLM model switching functionality
fix: resolve backup file permission issues
docs: update installation instructions
refactor: simplify JSON validation logic
test: add tests for error handling scenarios
chore: update dependencies in README
```

### Detailed Example
```bash
feat(backup): implement backup retention policy

- Add MAX_BACKUPS configuration option
- Automatically remove oldest backups when limit exceeded
- Preserve most recent backups
- Add backup listing functionality

Closes #42
```

## Testing Requirements

- **Add tests** for all new functionality
- **Update existing tests** if your changes affect current behavior
- **Ensure 100% test pass rate** before submitting
- **Test edge cases** and error conditions
- **Use the test framework** from `tests/test_helper.sh`

## Pull Request Guidelines

- **Title**: Use conventional commit format for PR titles
- **Description**: Clearly explain what your changes do and why
- **Screenshots**: Include screenshots for UI changes if applicable
- **Testing**: Mention how you tested your changes
- **Breaking changes**: Clearly highlight any breaking changes

## Review Process

1. **Automated checks**: CI will run tests and shellcheck validation
2. **Code review**: Maintainers will review your code for quality and functionality
3. **Testing feedback**: You may be asked to add tests or modify existing ones
4. **Approval**: PR will be merged once approved and all checks pass

## Getting Help

- **Questions**: Feel free to ask questions in your PR or open an issue
- **Discussions**: Use GitHub Discussions for broader topics
- **Documentation**: Check existing documentation and examples first

Thank you for contributing to the project! 🎉