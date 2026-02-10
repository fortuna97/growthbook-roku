# Changelog

All notable changes to the GrowthBook Roku SDK.

## [2.0.0] - 2026-02-10

### Added
- **Encrypted Features** - AES-128-CBC decryption for encrypted feature payloads (`roEVPCipher`, Roku OS 9.2+)
  - Supports `encryptedFeatures` and `encryptedSavedGroups` in API responses
  - Configure with `decryptionKey` option
- **Sticky Bucketing** - Persistent experiment assignments across sessions
  - `GrowthBookInMemoryStickyBucketService()` for testing and simple use
  - `GrowthBookRegistryStickyBucketService()` for persistent storage via `roRegistrySection`
  - Supports `fallbackAttribute` for anonymous-to-logged-in user transitions
  - Version blocking via `minBucketVersion` and `bucketVersion`
- **Tracking Plugin System** - Extensible plugin architecture for event tracking
  - `registerTrackingPlugin()` to add plugins at runtime
  - Plugins receive `onExperimentViewed` and `onFeatureUsage` events
  - Built-in `GrowthBookTrackingPlugin` for data warehouse integration with batched HTTP delivery
- **Refresh Features API** - On-demand feature updates via `refreshFeatures()`
- **Fallback Attribute Support** - `fallbackAttribute` in hash context for sticky bucketing prerequisites
- **Decrypt & Sticky Bucket Test Coverage** - Both test runners (BrightScript + JS validator) now cover all spec categories
  - 327/327 spec tests passing (100%)

### Improved
- **Platform Compatibility** - Cipher operations wrapped in try/catch for cross-platform resilience
- **Feature Parsing** - `_parseFeatures()` now handles encrypted payloads, encrypted saved groups, and plain saved groups

---

## [1.3.1] - 2026-02-03

### Changes
- **Ropm support** - Added support for ropm
- Minor documentation updates

---

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
