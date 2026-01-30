# Contributing to GrowthBook Roku SDK

We welcome contributions from the community! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and constructive in all interactions with other contributors.

## Getting Started

### Prerequisites

- Node.js 14+ (for testing)
- BrightScript tools (automatically installed as dev dependencies):
  - `bslint` - Grammar and best practices validation
  - `brighterscript` - Advanced BrightScript compiler
- (Optional) Roku device for integration testing

### Setup Development Environment

```bash
# Clone the repository
git clone https://github.com/growthbook/growthbook-roku.git
cd growthbook-roku

# Install dependencies
npm install

# Run tests to verify setup
npm test
```

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
# or for bug fixes:
git checkout -b fix/your-bug-fix-name
```

### 2. Make Your Changes

- Follow the code style conventions (see below)
- Write clear, descriptive commit messages
- Test your changes

### 3. Test Your Changes

```bash
# Run all tests
npm test

# Validate BrightScript grammar & best practices (recommended)
npm run lint

# Check BrightScript compilation syntax
npm run syntax

# Alternative: Check syntax compilation directly  
npm run syntax

# Run specific test file
node tests/validate-logic.js
```

### 4. Update Documentation

- Update relevant `.md` files
- Add examples if applicable
- Update CHANGELOG.md

### 5. Submit a Pull Request

- Push your branch to GitHub
- Create a pull request with clear description
- Link related issues
- Wait for review and address feedback

## Code Style

### BrightScript Style Guide

**File Structure:**
```brightscript
' File header comment
' Purpose and overview

' ===================================================================
' Function name and purpose
' ===================================================================
function FunctionName(param1 as type, param2 as type) as returnType
    ' Implementation
    return result
end function
```

**Naming Conventions:**
- Functions: `PascalCase` for public, `_camelCase` for private
- Variables: `camelCase`
- Constants: `UPPER_SNAKE_CASE`

**Comments:**
```brightscript
' Single line comment
' 
' Multi-line comment
' with multiple lines
'

' Section comment
' ===================================================================

' Inline comment for complex logic
```

**Formatting:**
- 4-space indentation
- Blank line between functions
- Line length: max 100 characters

### JavaScript Test Style

**Test Organization:**
```javascript
runner.test('Feature name - action', () => {
  // Arrange
  const gb = new GrowthBookTest({ /* ... */ });
  
  // Act
  const result = gb.someMethod();
  
  // Assert
  assert.strictEqual(result, expected);
});
```

**Naming:**
- Test names: descriptive, start with verb or feature name
- Variables: `camelCase`
- Use clear assertion messages

## Adding Features

### Feature Checklist

- [ ] Write unit tests first (TDD approach preferred)
- [ ] Implement feature in `source/GrowthBook.brs`
- [ ] All tests pass: `npm test`
- [ ] BrightScript syntax valid: `npm run lint`
- [ ] Add example if applicable in `examples/`
- [ ] Update README.md if user-facing
- [ ] Update TESTING.md if testing-related
- [ ] Update CHANGELOG.md
- [ ] Add JSDoc/comments

### Example: Adding a New Method

1. **Write test first:**
```javascript
runner.test('myNewMethod returns correct value', () => {
  const gb = new GrowthBookTest({ features: {...} });
  const result = gb.myNewMethod('param');
  assert.strictEqual(result, expected);
});
```

2. **Implement in BrightScript:**
```brightscript
function GrowthBook_myNewMethod(param as string) as string
    ' Implementation here
    return result
end function
```

3. **Add to SDK instance:**
```brightscript
instance = {
    ' ... other methods
    myNewMethod: GrowthBook_myNewMethod
}
```

4. **Test and document**

## Bug Fixes

### Bug Fix Process

1. Create an issue if one doesn't exist
2. Create a test that reproduces the bug
3. Fix the bug
4. Verify test passes
5. Update documentation if needed
6. Submit PR with reference to issue

### Example Bug Fix

```javascript
// Test that demonstrates the bug
runner.test('Bug: isOn returns true when should be false', () => {
  const gb = new GrowthBookTest({
    features: { 'buggy': { defaultValue: false } }
  });
  gb.init();
  
  // This test fails before fix
  assert.strictEqual(gb.isOn('buggy'), false);
});
```

## Documentation

### README Updates

- Document new features
- Add examples
- Update table of contents if needed
- Keep examples current

### API Documentation

Each public function should be documented:

```brightscript
' ===================================================================
' methodName - Brief description
' 
' Parameters:
'   param1 (type) - Description
'   param2 (type) - Description
' 
' Returns:
'   type - Description of return value
' 
' Example:
'   result = gb.methodName("param1", "param2")
' ===================================================================
function GrowthBook_methodName(param1 as string, param2 as type) as returnType
    ' ...
end function
```

## Testing Guidelines

### Unit Test Requirements

- Test happy path
- Test edge cases
- Test error conditions
- Use descriptive names
- Test one thing per test

### Integration Test Requirements

- Test feature interaction
- Test real-world scenarios
- Test with actual feature data structure

### Performance Testing

For performance-critical code:
```javascript
runner.test('Performance: hashAttribute is fast', () => {
  const gb = new GrowthBookTest();
  const start = Date.now();
  
  for (let i = 0; i < 1000; i++) {
    gb._hashAttribute(`user${i}`);
  }
  
  const elapsed = Date.now() - start;
  assert(elapsed < 100, `Too slow: ${elapsed}ms`);
});
```

## Version Management

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

Update `package.json` version when appropriate.

## Pull Request Review

### What We Look For

- ✅ Tests pass
- ✅ No breaking changes (or justified)
- ✅ Clear commit messages
- ✅ Follows code style
- ✅ Documentation updated
- ✅ No unnecessary dependencies

### Review Process

1. Automated tests run
2. Maintainer review
3. Request changes or approve
4. You address feedback
5. Maintainer merges

## Release Process

When releasing a new version:

1. Update `package.json` version
2. Update CHANGELOG.md
3. Create git tag: `git tag v1.0.0`
4. Push: `git push origin main --tags`
5. Publish: `npm publish`

## Getting Help

- Check [existing issues](https://github.com/growthbook/growthbook-roku/issues)
- Read [documentation](https://docs.growthbook.io)
- Join [Slack community](https://slack.growthbook.io)
- Ask on [GitHub Discussions](https://github.com/growthbook/growthbook-roku/discussions)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Feel free to open an issue or ask in our [Slack community](https://slack.growthbook.io).

Thank you for contributing! 🎉
