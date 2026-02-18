# GrowthBook SDK Test Channel for brs-desktop

Validates the GrowthBook SDK v2.0.1 by running **actual BrightScript code** against the official spec test suite (`cases.json`) inside [brs-desktop](https://github.com/lvcabral/brs-desktop).

## Quick Start

### Step 1: Prepare the Channel
```bash
npm run test:channel
```

This copies the SDK and test files into the test-channel and creates `pkg.zip`.

### Step 2: Install brs-desktop
Download from: https://github.com/lvcabral/brs-desktop/releases/latest

### Step 3: Run
1. Start brs-desktop
2. File -> Open App Package -> select `test-channel/pkg.zip`
3. Tests run automatically

## What It Tests

### Part 1: Runtime Smoke Tests
- SDK initialization and invalid config handling
- Performance benchmark (1000 evaluations <5s)
- Network component creation (`roURLTransfer`, `roMessagePort`)
- Encrypted features API surface (`_decrypt`, `decryptionKey` config)
- Sticky bucket service round-trip (`GrowthBookInMemoryStickyBucketService`)
- Tracking plugin registration (`GrowthBookTrackingPlugin`, `registerTrackingPlugin`)
- Refresh features API surface (`refreshFeatures`)

### Part 2: Official Spec Tests (cases.json)
- `evalCondition` - Targeting condition evaluation (221 tests)
- `hash` - FNV-1a32 hash algorithm (15 tests)
- `getBucketRange` - Bucket range calculation (13 tests)
- `chooseVariation` - Variation selection (13 tests)
- `feature` - Feature flag evaluation (46 tests)
- `run` - Experiment evaluation (73 tests)
- `decrypt` - AES-128-CBC decryption (10 tests, skipped if roEVPCipher unavailable)
- `stickyBucket` - Sticky bucketing assignments (9 tests)

## Channel Structure

```
test-channel/
├── manifest
├── source/
│   ├── main.brs                  # Entry point
│   ├── TestRunner.brs            # Smoke tests + spec test orchestration
│   ├── GrowthBook.brs            # (copied by npm run test:channel)
│   ├── GrowthBookTestRunner.brs  # (copied by npm run test:channel)
│   ├── TestUtilities.brs         # (copied by npm run test:channel)
│   └── cases.json                # (copied by npm run test:channel)
└── components/
    ├── TestScene.xml             # SceneGraph UI
    └── TestScene.brs             # Results display
```

## Why This Matters

The JS validator (`npm run test:validator`) reimplements SDK logic in JavaScript. This test-channel runs the **actual `GrowthBook.brs`** BrightScript code against the same spec, proving the real SDK works correctly in a Roku-like runtime.
