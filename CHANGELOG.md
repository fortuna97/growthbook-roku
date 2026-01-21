# Changelog

All notable changes to the GrowthBook Roku SDK.

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
