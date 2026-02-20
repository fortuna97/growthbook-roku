# GrowthBook Roku SDK - Testing Guide

## Overview

The GrowthBook Roku SDK has three layers of testing:

| Layer | Command | Tests | Runtime |
|-------|---------|-------|---------|
| **JS Validator** | `npm run test:validator` | 400 | Node.js |
| **Native BrightScript** | `npm run test:native` | 401 | brs-engine |
| **On-Device (brs-desktop)** | `npm run test:channel` | 401+ smoke tests | brs-desktop |

Run all automated tests:

```bash
npm test
```

This runs the JS validator followed by the native BrightScript runner.

---

## 1. JavaScript Validator

**Command:** `npm run test:validator`

Reimplements SDK logic in JavaScript and runs it against the official `cases.json` spec test suite. Fast feedback loop, no device or emulator needed.

**File:** `tests/validate-logic.js`

### Current Results (v2.0.1)

```
evalCondition:    221/221 (100%)
hash:             15/15  (100%)
getBucketRange:   13/13  (100%)
chooseVariation:  13/13  (100%)
feature:          46/46  (100%)
run:              73/73  (100%)
decrypt:          10/10  (100%)
stickyBucket:     9/9    (100%)
──────────────────────────────────
TOTAL: 400/400 tests passed (100%)
```

### When to Use

- During development for quick iteration
- In CI/CD for algorithm correctness
- Does **not** test actual BrightScript execution

---

## 2. Native BrightScript Tests

**Command:** `npm run test:native`

Runs the **actual `GrowthBook.brs`** source code through `brs-engine` (a BrightScript interpreter for Node.js) against the full `cases.json` spec suite.

**Files:**
- `tests/run-native.js` — Node.js orchestrator
- `tests/GrowthBookTestRunner.brs` — BrightScript test runner that parses `cases.json`
- `tests/TestUtilities.brs` — Helper functions (JSON comparison, type conversion)
- `tests/cases.json` — Official GrowthBook spec test suite

### Current Results (v2.0.1)

```
Spec categories tested:
  evalCondition:    221/221
  hash:             15/15
  getBucketRange:   13/13
  chooseVariation:  13/13
  feature:          46/46
  run:              73/73
  decrypt:          10/10
  stickyBucket:     9/9
──────────────────────────────────
TOTAL: 401/401 tests passed (100%)
```

### How It Works

1. `run-native.js` generates a temporary `test-entry.brs` entry point
2. Invokes `brs-engine` with the SDK source + test runner + utilities
3. `GrowthBookTestRunner.brs` loads `cases.json` and iterates each category
4. Results are parsed from stdout and reported as pass/fail

### Differences from JS Validator

- Tests **real BrightScript code** (not a JS reimplementation)
- Includes the `run` category (73 experiment evaluation tests) not covered by the JS validator
- Uses a `MockCipher` to simulate `roEVPCipher` decryption in the headless environment

---

## 3. On-Device Testing (brs-desktop)

**Command:** `npm run test:channel`

Builds a Roku channel package (`test-channel/pkg.zip`) that runs inside [brs-desktop](https://github.com/lvcabral/brs-desktop), a desktop Roku simulator with SceneGraph support.

### Quick Start

```bash
# Step 1: Build the test channel
npm run test:channel

# Step 2: Open in brs-desktop
# File -> Open App Package -> test-channel/pkg.zip
```

### What It Tests

**Part 1: Runtime Smoke Tests** — SDK behavior that `cases.json` cannot cover:
- SDK initialization and invalid config handling
- Performance benchmark (1000 evaluations <5s)
- Network component creation (`roURLTransfer`, `roMessagePort`)
- Encrypted features API surface (`_decrypt`, `decryptionKey`)
- Sticky bucket service round-trip
- Tracking plugin registration
- Refresh features API

**Part 2: Official Spec Tests** — Same `cases.json` suite as the native runner.

### When to Use

- Validating SceneGraph integration
- Testing in a full Roku-like runtime environment
- Verifying UI rendering of test results

See [test-channel/README.md](../test-channel/README.md) for channel structure and details.

---

## Test Files

```
tests/
├── validate-logic.js         # JS validator (327 spec tests)
├── run-native.js             # Native BrightScript test orchestrator
├── GrowthBookTestRunner.brs  # BrightScript spec test runner
├── TestUtilities.brs         # Helper functions for tests
└── cases.json                # Official GrowthBook spec test suite

test-channel/
├── manifest                  # Roku channel manifest
├── README.md                 # Test channel documentation
├── source/
│   ├── main.brs              # Channel entry point
│   └── TestRunner.brs        # Smoke tests + spec orchestration
└── components/
    ├── TestScene.xml          # SceneGraph UI layout
    └── TestScene.brs          # Results display logic
```

## Spec Test Categories

| Category | Tests | What It Validates |
|----------|-------|-------------------|
| `evalCondition` | 221 | Targeting condition operators ($gt, $in, $regex, $elemMatch, etc.) |
| `hash` | 15 | FNV-1a32 hash algorithm consistency |
| `getBucketRange` | 13 | Bucket range calculation for traffic splits |
| `chooseVariation` | 13 | Variation selection from bucket ranges |
| `feature` | 46 | Feature flag evaluation (rules, force, prerequisites) |
| `run` | 73 | Experiment evaluation (namespace, filters, sticky buckets) |
| `decrypt` | 10 | AES-128-CBC decryption of encrypted payloads |
| `stickyBucket` | 9 | Persistent experiment assignments |

Categories in `cases.json` not currently tested: `getQueryStringOverride` (16), `inNamespace` (16), `getEqualWeights` (6), `urlRedirect` (4). These are helper functions tested indirectly through `feature` and `run` categories.

## Adding Tests

When adding new SDK features, follow the checklist from [CONTRIBUTING.md](../CONTRIBUTING.md):

1. Add test cases to the JS validator (`validate-logic.js`) if applicable
2. Verify the native BrightScript runner passes (`npm run test:native`)
3. Add smoke tests to `test-channel/source/TestRunner.brs` for runtime behavior not covered by `cases.json`
4. Run `npm test` to confirm all layers pass

---

**Last Updated:** February 2026
**Native BrightScript Tests:** 401/401 (100%)
**JavaScript Validator:** 327/327 (100%)
