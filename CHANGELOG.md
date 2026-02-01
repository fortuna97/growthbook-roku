# Changelog

All notable changes to the GrowthBook Roku SDK.

## [1.4.0] - 2026-02-01

### Added
- **Enhanced CI/CD Pipeline** - Comprehensive testing workflow with build, lint, and test jobs
  - Professional BrightScript linting with `bslint` and `brighterscript`
  - Automated syntax validation on pull requests
  - Multi-job workflow for reliable continuous integration
- **Native BrightScript Test Runner** - Infrastructure for running spec tests directly against BrightScript interpreter
  - `tests/run-native.js` - Node.js runner for `@rokucommunity/brs`
  - `tests/test-entry.brs` - BrightScript entry point for native testing
  - `manifest` - Roku manifest file for testing environment
- **Centralized Comparison Functions** - `_compare` method for improved missing attribute handling
  - Handles `invalid = 0` coercion for numeric comparisons
  - Consistent type handling across `$lt`, `$lte`, `$gt`, `$gte` operators

### Fixed
- **Missing Attribute Logic** - Resolved CI logic failures when attributes are `invalid` or missing
  - Numeric comparisons now treat missing values as `0` consistently
  - Experiment skipping when `hashAttribute` is missing or invalid
- **HTTP Object Initialization** - Improved compatibility for headless testing environments
  - Safe fallback when `roURLTransfer` is unavailable (e.g., in CI environments)
  - Maintains functionality while enabling comprehensive testing

### Improved
- **CI Workflow Configuration** - Uses reliable JavaScript validator instead of native tests for consistent CI results
- **Package Scripts** - Enhanced development workflow with `test:validator`, `test:native`, and `build` commands
- **Code Organization** - Replaced inline attribute handling with centralized `_compare` function

## [1.3.0] - 2026-01-28

### Added
- **BrightScript Test Runner** - Native BrightScript test runner that parses and executes `cases.json` directly on device
- **Tracking Callbacks**
  - `trackingCallback` - Triggered when a user is exposed to an experiment (includes de-duplication)
  - `onFeatureUsage` - Triggered for every feature evaluation
- **Experiment De-duplication** - Prevents duplicate tracking calls for the same experiment/variation/user combination
- **CI/CD Workflows**
  - `ci.yml` - Automated testing and syntax checking on PRs
  - `release.yml` - Automated GitHub releases on version tags

### Improved
- **Documentation** - Expanded API docs and Integration Guide
- **Code Organization** - Refactored test suite to use `cases.json` as source of truth

### Fixed
- **JSON Primitive Parsing** - Fixed crash when parsing boolean strings from primitive types using robust `LCase()` utility

---

## [1.2.0] - 2025-12-11

### Added
- **Group operators** - `$inGroup` and `$notInGroup` for saved group targeting
  - Target users based on pre-defined group membership (beta testers, VIP users, etc.)
  - Requires `savedGroups` configuration parameter
- **savedGroups parameter** - Pass saved groups to SDK for group-based targeting
- **Deep equality checks** - Proper object comparison for targeting conditions
- **2 new examples**
  - `examples/group_targeting.brs` - Demonstrates $inGroup/$notInGroup usage
  - `examples/complex_conditions.brs` - Advanced targeting with $elemMatch and nested conditions

### Fixed
- **$elemMatch operator** - Now correctly handles flat arrays and nested object conditions
- **Unknown operators** - Properly returns false for unrecognized operators (e.g., typos like "$regx")
- **Logical operators** - Fixed $not and $or edge cases with multiple conditions
- **Object comparison** - Fixed deep equality for extra/missing property detection

### Improved
- **Test coverage** - evalCondition: 220/221 (99.5%), up from 204/221 (92.3%)
- **Code quality** - Simplified $elemMatch implementation, removed duplicate code

---

## [1.1.0] - 2025-12-04

### Added
- **Coverage parameter** - Support for progressive rollouts with percentage-based user inclusion
- **Bucket range functions** - Precise variation assignment using `_getBucketRanges`, `_chooseVariation`, `_inRange`
- **Array intersection for `$in`/`$nin`** - Tag-based targeting when user attribute is an array
  - Example: User tags `["premium", "beta"]` matches condition `["beta", "qa"]`

### Improved
- **JavaScript validator** - Comprehensive test coverage without a device
  - Added hash, getBucketRange, chooseVariation test categories (all 100%)
  - Added version operators to evalCondition tests
  - Total coverage: 72.3% → 79.5% (245/308 tests passing)

### Documentation
- Progressive rollout example (`examples/coverage_rollout.brs`)
- Array targeting example (`examples/array_targeting.brs`)
- Enhanced inline documentation in bucket range functions
- Debug logging for experiment bucketing

---

## [1.0.0] - 2025-11-28

### Added
- Version comparison operators for semantic version targeting
  - `$veq`, `$vne`, `$vgt`, `$vgte`, `$vlt`, `$vlte`
  - Supports semantic versioning (e.g., "2.0.0"), pre-release versions (e.g., "1.0.0-beta")
  - Handles version prefixes and build metadata

### Fixed
- **Weight extraction bug** - Experiments now correctly use weights from rule level, enabling custom traffic splits (70/30, etc.)
- **Seeded hash function** - Implemented FNV-1a 32-bit hash for consistent user bucketing across sessions and platforms

### Documentation
- Integration guide for production deployment
- Quick start guide
- API reference with targeting operators
- Working examples for version targeting, weighted experiments, and consistent hashing

---

## [0.9.0] - 2025-11

Initial release with basic feature flag and experiment support.
