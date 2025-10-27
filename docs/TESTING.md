# GrowthBook Roku SDK - Testing Guide

## Overview

The GrowthBook Roku SDK uses **Rooibos**, a professional BrightScript unit testing framework, to test the actual `.brs` code directly on Roku devices or simulators.

## Test Files

- **GrowthBookTests.brs** - Basic unit tests for core SDK functionality
- **GrowthBookScenarioTests.brs** - Behavioral tests based on `cases.json` from the JS SDK
- **TestUtilities.brs** - Helper functions and utilities for testing
- **cases.json** - Language-agnostic test cases (source of truth for all SDKs)

## Why Rooibos?

**Rooibos** is the industry-standard testing framework for Roku/BrightScript development because it:

- ✅ Tests **actual BrightScript code** (not mocks or translations)
- ✅ Runs **directly on Roku devices** or simulators
- ✅ Provides **proper assertion library** for BrightScript
- ✅ Supports **code coverage** reporting
- ✅ Integrates with **CI/CD pipelines**
- ✅ Used by **major Roku channels** in production

## Installation

### 1. Install Rooibos Framework

```bash
# Via npm (recommended)
npm install -g rooibos-cli

# Or download from GitHub
# https://github.com/georgejecook/rooibos
```

### 2. Install Roku Development Tools

```bash
# Install BrighterScript compiler
npm install -g brighterscript

# Ensure you have Roku Developer tools
# https://developer.roku.com/develop/getting-started
```

## Running Tests

### On Roku Device

```bash
# Set your Roku device IP
export ROKU_DEV_TARGET=192.168.1.100
export ROKU_DEV_PASSWORD=your-password

# Run tests
npm test
```

### On Roku Simulator

```bash
# Start Roku simulator, then run:
npm test
```

### Using Rooibos CLI

```bash
# Run all tests
rooibos

# Run specific test file
rooibos tests/GrowthBookTests.brs

# Run with coverage
rooibos --coverage

# Run with verbose output
rooibos --verbose
```

## Test Structure

### Test Files

```
tests/
├── GrowthBookTests.brs      # Main test suite
├── cases.json                # BDD reference cases from JS SDK
└── rooibos.json              # Rooibos configuration
```

### Test Suite Structure

```brightscript
' @suite GrowthBook SDK Tests
function TestSuite__GrowthBook() as object
    this = BaseTestSuite()
    this.Name = "GrowthBookTestSuite"
    
    ' Add test cases
    this.addTest("testInitWithClientKey", testInitWithClientKey)
    this.addTest("testIsOnEnabled", testIsOnEnabled)
    ' ... more tests
    
    return this
end function

' @test Initialize with client key
function testInitWithClientKey() as string
    gb = GrowthBook({ clientKey: "sdk_test123" })
    return m.assertEqual(gb.clientKey, "sdk_test123")
end function
```

## Test Categories

### 1. Initialization Tests

Tests SDK initialization with different configurations:
- Client key initialization
- Direct feature loading
- Error handling for missing config

```brightscript
function testInitWithFeatures() as string
    features = { "feature1": { defaultValue: true } }
    gb = GrowthBook({ features: features })
    result = gb.init()
    
    m.assertTrue(result)
    return m.assertTrue(gb.isInitialized)
end function
```

### 2. Feature Flag Tests

Tests feature flag evaluation:
- Boolean flags (isOn)
- Feature values (getFeatureValue)
- Missing features

```brightscript
function testIsOnEnabled() as string
    features = { "new-ui": { defaultValue: true } }
    gb = GrowthBook({ features: features })
    gb.init()
    
    return m.assertTrue(gb.isOn("new-ui"))
end function
```

### 3. Condition Evaluation Tests

Tests targeting condition operators:
- Equality checks
- Comparison operators ($gt, $lt, $gte, $lte)
- Array operators ($in, $nin)
- Logical operators ($and, $or, $not)

```brightscript
function testConditionGreaterThan() as string
    gb = GrowthBook({ attributes: { score: 100 } })
    condition = { score: { "$gt": 50 } }
    
    return m.assertTrue(gb._evaluateConditions(condition))
end function
```

### 4. Hashing Tests

Tests consistent user bucketing:
- Hash consistency (same input → same output)
- Hash distribution (different inputs → different outputs)
- Hash range (0-99)

```brightscript
function testHashConsistency() as string
    gb = GrowthBook({})
    hash1 = gb._hashAttribute("user123")
    hash2 = gb._hashAttribute("user123")
    
    return m.assertEqual(hash1, hash2)
end function
```

## Rooibos Assertions

### Available Assertions

```brightscript
' Equality
m.assertEqual(actual, expected)
m.assertNotEqual(actual, expected)

' Boolean
m.assertTrue(value)
m.assertFalse(value)

' Null checks
m.assertInvalid(value)
m.assertNotInvalid(value)

' Array/Object
m.assertArrayCount(array, expectedCount)
m.assertArrayContains(array, value)
m.assertAAHasKey(aa, key)
m.assertAANotHasKey(aa, key)
```

### Example Test with Multiple Assertions

```brightscript
function testEvalFeatureStructure() as string
    gb = GrowthBook({ features: { "test": { defaultValue: true } } })
    gb.init()
    result = gb.evalFeature("test")
    
    m.assertNotInvalid(result.key)
    m.assertNotInvalid(result.on)
    m.assertNotInvalid(result.off)
    m.assertNotInvalid(result.source)
    return m.assertNotInvalid(result.value)
end function
```

## Growthbook Test Scenarios Reference

The `tests/cases.json` file contains language-agnostic behavioral test cases from the JavaScript SDK. Use these as a reference for what behavior to test:

```json
{
  "specVersion": "0.7.1",
  "evalCondition": [ /* 221 test cases */ ],
  "feature": [ /* 46 test cases */ ],
  "hash": [ /* 15 test cases */ ],
  "chooseVariation": [ /* 13 test cases */ ]
}
```

### Using Behavioral Test Cases

The Behavioral Test cases describe **expected behavior** across all GrowthBook SDKs. When writing tests:

1. **Reference the cases** to understand expected behavior
2. **Write BrightScript tests** that validate the same behavior
3. **Keep tests in sync** when cases.json is updated

Example Behavioral Test case:

```json
[
  "$gt - pass",
  { "age": { "$gt": 18 } },
  { "age": 25 },
  true
]
```

Corresponding BrightScript test:

```brightscript
function testConditionGreaterThan() as string
    gb = GrowthBook({ attributes: { age: 25 } })
    condition = { age: { "$gt": 18 } }
    result = gb._evaluateConditions(condition)
    return m.assertTrue(result)
end function
```

## Code Coverage

### Generate Coverage Report

```bash
# Run tests with coverage
rooibos --coverage

# Coverage report will be in:
# coverage/index.html
```

### Coverage Goals

| Component | Target |
|-----------|--------|
| Core initialization | 100% |
| Feature evaluation | 100% |
| Condition operators | 95% |
| Hash function | 100% |
| Overall | 95% |

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test GrowthBook Roku SDK

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '16'
      
      - name: Install Dependencies
        run: |
          npm install -g rooibos-cli
          npm install -g brighterscript
      
      - name: Run Tests
        run: rooibos --ci
        env:
          ROKU_DEV_TARGET: ${{ secrets.ROKU_DEV_TARGET }}
          ROKU_DEV_PASSWORD: ${{ secrets.ROKU_DEV_PASSWORD }}
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v2
        with:
          files: ./coverage/coverage.xml
```

## Debugging Tests

### Enable Verbose Output

```bash
# Show detailed test output
rooibos --verbose

# Show timing information
rooibos --printTestTimes
```

### Test-Specific Debugging

```brightscript
function testDebugExample() as string
    gb = GrowthBook({ enableDevMode: true })  ' Enable SDK logging
    
    ' Add debug prints
    print "Testing feature evaluation..."
    result = gb.evalFeature("test-feature")
    print "Result:"; result
    
    return m.assertEqual(result.source, "defaultValue")
end function
```

### Run Single Test

```bash
# Run only one test function
rooibos --filter "testInitWithClientKey"
```

## Best Practices

### 1. Test Naming

Use descriptive, behavior-focused names:

```brightscript
' ✅ Good
function testIsOnReturnsTrueForEnabledFeature() as string

' ❌ Bad  
function test1() as string
```

### 2. Arrange-Act-Assert Pattern

```brightscript
function testFeatureEvaluation() as string
    ' Arrange
    features = { "feature": { defaultValue: "value" } }
    gb = GrowthBook({ features: features })
    gb.init()
    
    ' Act
    result = gb.evalFeature("feature")
    
    ' Assert
    return m.assertEqual(result.value, "value")
end function
```

### 3. Test Independence

Each test should be independent:

```brightscript
' ✅ Good - creates fresh instance
function testFeature1() as string
    gb = GrowthBook({ features: {...} })
    ' test code
end function

function testFeature2() as string
    gb = GrowthBook({ features: {...} })  ' New instance
    ' test code
end function
```

### 4. Test Edge Cases

```brightscript
function testGetFeatureValueWithInvalidFallback() as string
    gb = GrowthBook({ features: {} })
    gb.init()
    result = gb.getFeatureValue("missing", invalid)
    return m.assertInvalid(result)
end function
```

## Troubleshooting

### Tests Not Running

1. **Check Roku device connection:**

   ```bash
   curl -d '' http://192.168.1.100:8060/keypress/Home
   ```

2. **Verify Rooibos installation:**

   ```bash
   rooibos --version
   ```

3. **Check configuration:**

   ```bash
   cat rooibos.json
   ```

### Tests Failing

1. **Run with verbose output:**

   ```bash
   rooibos --verbose
   ```

2. **Check SDK code changes:**
   - Ensure tests match current SDK implementation
   - Update tests when SDK behavior changes

3. **Verify test data:**
   - Check that test features/attributes are valid
   - Ensure expected values match SDK output

## Resources

- **Rooibos Framework**: https://github.com/georgejecook/rooibos
- **Roku Developer Docs**: https://developer.roku.com/docs
- **BDD Test Cases**: `tests/cases.json`
- **SDK Source**: `source/GrowthBook.brs`

## Contributing Tests

When adding new SDK features:

1. **Write tests first** (TDD approach)
2. **Cover happy path and edge cases**
3. **Run full test suite** before committing
4. **Update this documentation** if adding new test patterns

---

**Last Updated**: October 2025  
**Rooibos Version**: 5.x  
**Test Count**: 22 unit tests
