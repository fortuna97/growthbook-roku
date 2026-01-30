# GrowthBook Roku SDK - Architecture Guide

This document describes the architecture and design principles of the GrowthBook Roku SDK.

## Table of Contents

- [Overview](#overview)
- [Core Design Principles](#core-design-principles)
- [Project Structure](#project-structure)
- [Core Components](#core-components)
- [Data Flow](#data-flow)
- [Feature Evaluation Pipeline](#feature-evaluation-pipeline)
- [Memory Management](#memory-management)
- [Performance Considerations](#performance-considerations)

## Overview

The GrowthBook Roku SDK is a lightweight, pure-BrightScript implementation for feature flags and A/B testing on Roku devices. It focuses on:

- **Simplicity**: Single-file distribution, no dependencies
- **Performance**: Sub-millisecond feature evaluation
- **Reliability**: Deterministic variation assignment
- **Integration**: Easy integration with existing Roku apps

## Core Design Principles

### 1. **No External Dependencies**

The SDK is written entirely in BrightScript with no external libraries. This ensures:
- Minimal memory footprint
- Works on all Roku devices (OS 9.0+)
- No version conflicts with host app

### 2. **Local Evaluation**

All feature evaluation happens on-device:
- No round-trips to server for every evaluation
- Works offline with cached features
- Instant evaluation (<1ms per feature)

### 3. **Deterministic Assignment**

Experiment variation assignment uses consistent hashing:
- Same user always gets same variation
- Variations don't change between app restarts
- No server state required

### 4. **Stateless Design**

The SDK maintains minimal state:
- Features are cached in memory
- User attributes provided at init or updated explicitly
- No persistent state files

## Project Structure

```
growthbook-roku/
├── source/
│   └── GrowthBook.brs              # Main SDK implementation
├── tests/
│   └── test_sdk.js                 # Unit tests (Node.js)
├── examples/
│   ├── simple_flag.brs             # Basic usage
│   ├── experiments.brs             # A/B testing
│   └── targeting.brs               # Advanced targeting
├── docs/
│   ├── ARCHITECTURE.md             # This file
│   └── API.md                      # API reference
├── package.json                    # NPM configuration
├── TESTING.md                      # Testing guide
├── CONTRIBUTING.md                 # Contribution guidelines
├── README.md                       # User documentation
└── LICENSE                         # MIT License
```

## Core Components

### 1. **SDK Instance** (`GrowthBook`)

The main object created with user configuration.

```brightscript
gb = GrowthBook({
    apiHost: "https://cdn.growthbook.io",
    clientKey: "sdk_key123",
    attributes: { id: "user123" },
    trackingCallback: sub(experiment, result) ... end sub
})
```

**Responsibilities:**
- Configuration management
- Feature loading and caching
- Delegation to evaluation functions
- Callback invocation

**Properties:**
- `apiHost`: GrowthBook API endpoint
- `clientKey`: API key for fetching features
- `attributes`: User targeting attributes
- `features`: In-memory feature cache
- `isInitialized`: Initialization status

### 2. **Feature Loader** (`_loadFeaturesFromAPI`)

Fetches features from GrowthBook API.

**Process:**
1. Make HTTP GET to `/api/features/{clientKey}`
2. Parse JSON response
3. Cache features in memory
4. Update initialization status

**Error Handling:**
- Network failures: Return false
- Parse errors: Log and return false
- Can use cached features or defaults as fallback

### 3. **Feature Evaluator** (`evalFeature`)

Evaluates a feature against user attributes.

**Evaluation Flow:**
```
1. Check if feature exists
2. Check targeting rules (in order)
   ├─ Evaluate conditions
   ├─ If match: apply rule value
   └─ If experiment: evaluate variations
3. Fall back to default value
4. Return evaluation result with source
```

**Return Structure:**
```javascript
{
    key: "feature-key",
    value: <any>,           // Feature value
    on: boolean,            // Is feature enabled
    off: boolean,           // Opposite of 'on'
    source: "defaultValue|force|experiment|unknownFeature",
    ruleId: "rule-123",     // Which rule matched
    experimentId: "exp-123", // Which experiment
    variationId: 0          // Which variation (0-based)
}
```

### 4. **Condition Evaluator** (`_evaluateConditions`)

Evaluates targeting conditions against user attributes.

**Supports:**
- **Logical operators**: `$and`, `$or`, `$not`
- **Comparison operators**: `$eq`, `$ne`, `$lt`, `$lte`, `$gt`, `$gte`
- **Array operators**: `$in`, `$nin`
- **Direct equality**: `{ country: "US" }`

**Example:**
```javascript
{
    "$and": [
        { country: "US" },
        { subscription: { "$in": ["premium", "enterprise"] } },
        { accountAge: { "$gt": 30 } }
    ]
}
```

### 5. **Experiment Manager** (`_evaluateExperiment`)

Assigns users to experiment variations using hashing.

**Process:**
1. Hash user ID to 0-99
2. Bucket based on hash and weights
3. Assign to variation
4. Fire tracking callback
5. Return variation value

**Bucketing Algorithm:**
```
1. hash = djb2(userId) % 100      // 0-99
2. bucket = hash / 100.0            // 0.0-1.0
3. cumulative = 0
4. for each variation:
     cumulative += weight
     if bucket <= cumulative:
       return variation
```

### 6. **Hashing** (`_hashAttribute`)

DJB2 variant hash function for consistent variation assignment.

**Characteristics:**
- Consistent: same input always produces same output
- Distributed: uniform distribution 0-99
- Fast: O(n) on attribute length

**Implementation:**
```brightscript
hash = 5381
for each char in value:
    hash = ((hash * 33) + char) mod 2147483647
return (hash mod 100)
```

## Data Flow

### Initialization Flow

```
User Creates SDK
       ↓
Config Applied
       ↓
Features Provided? ──Yes→ Use Cached Features
       ↓ No
Client Key Provided? ──No→ Fail
       ↓ Yes
Load from API
       ↓
Parse JSON
       ↓
Cache Features
       ↓
Set Initialized
       ↓
Return Success
```

### Feature Evaluation Flow

```
User Calls evalFeature("key")
       ↓
Feature Exists?
       │ No → Return "unknownFeature"
       ↓ Yes
Rules Exist?
       │ No → Go to Default
       ↓ Yes
For Each Rule:
  Conditions Match?
    │ No → Continue
    ↓ Yes
  Variations?
    │ No → Return Forced Value
    ↓ Yes
  Evaluate Experiment
    │ → Get User Hash
    │ → Allocate to Variation
    │ → Track Experiment
    ↓
    Return Variation Value
Default Value Exists?
  │ No → Return Unknown
  ↓ Yes
Return Default Value
```

### Experiment Tracking Flow

```
User Gets Variation
       ↓
Variation Assigned
       ↓
Tracking Callback Set?
       │ No → Done
       ↓ Yes
Invoke Callback with:
  - experiment (rule object)
  - result (evaluation result)
       ↓
User Handles in Analytics
```

## Feature Evaluation Pipeline

The evaluation pipeline implements a waterfall approach:

### Stage 1: Rules Check
Evaluates feature rules in order. First matching rule wins:

```brightscript
if feature.rules <> invalid
    for each rule in feature.rules
        if _evaluateConditions(rule.condition)
            ' Rule matched - use this value
            result.value = rule.value
            result.source = "force"
            return result
        end if
    end for
end if
```

### Stage 2: Experiment Evaluation
If rule has variations, assign to one:

```brightscript
if rule.variations <> invalid
    ' Hash user for consistent assignment
    hash = _hashAttribute(userId)
    bucket = (hash mod 100) / 100.0
    
    ' Find variation by cumulative weight
    cumulative = 0
    for each variation in rule.variations
        cumulative += variation.weight
        if bucket <= cumulative
            result.variationId = index
            result.value = variation
            result.source = "experiment"
            
            ' Track experiment
            _trackExperiment(rule, result)
            
            return result
        end if
    end for
end if
```

### Stage 3: Default Value
If no rules matched, use default:

```brightscript
if feature.defaultValue <> invalid
    result.value = feature.defaultValue
    result.source = "defaultValue"
    return result
end if
```

### Stage 4: Unknown
No value found:

```brightscript
result.source = "unknownFeature"
result.on = false
result.off = true
return result
```

## Memory Management

### Memory Footprint

| Component | Size |
|-----------|------|
| SDK Code | 50 KB |
| 100 Features | 40-60 KB |
| Attributes | 1-5 KB |
| Runtime State | 10-20 KB |
| **Total** | **100-135 KB** |

### Optimization Strategies

**1. Feature Caching**
- Features cached in memory after fetch
- No repeated API calls within session
- Can be refreshed manually if needed

**2. Lazy Evaluation**
- Features only evaluated when accessed
- No background processing
- Evaluation is on-demand

**3. Minimal State**
- Only essential state kept in memory
- Attributes stored once, updated when needed
- Features not duplicated

### Memory Cleanup

Currently no automatic cleanup. For large feature sets:
- Consider feature namespacing on server
- Implement feature rotation if needed
- Reload features when memory critical

## Performance Considerations

### Performance Metrics

**Initialization:**
- With cache: ~5-10ms
- With API call: 500-2000ms (network dependent)

**Feature Evaluation:**
- isOn(): <1ms
- getFeatureValue(): <1ms
- evalFeature(): <2ms (includes hashing)

**Memory:**
- Per feature: ~400-800 bytes
- Per attribute: ~50-100 bytes
- Per evaluation: 0 bytes (no accumulation)

### Performance Optimization

**1. Batch Operations**
```brightscript
' Avoid individual updates
attributes = {
    id: userId,
    country: country,
    subscription: subscription
}
gb.setAttributes(attributes)  ' Batch update
```

**2. Minimize API Calls**
```brightscript
' Load once at startup
if not gb.isInitialized
    gb.init()
end if

' Reuse gb instance throughout app
```

**3. Cache Features Locally**
```brightscript
' On first run, persist features
features = gb.features
saveToFile("features.json", features)

' On app restart
gb = GrowthBook({ features: loadFromFile("features.json") })
```

**4. Selective Reloads**
```brightscript
' Only reload when user logs in
if newUserLogin
    gb.setAttributes(newAttributes)
    gb.init()  ' Refresh features
end if
```

## Error Handling Strategy

**API Errors:**
- Log error with dev mode
- Fall back to cached features
- Return false from init()

**Parse Errors:**
- Log parsing error
- Use empty features object
- Don't crash app

**Evaluation Errors:**
- Condition evaluation: return false for safety
- Unknown features: return unknown source
- Missing attributes: treat as undefined

**Network Errors:**
- Timeout: configurable, default 10s
- Connection error: return false
- Cached features still available

## Extension Points

The SDK is designed for extensibility:

### Adding New Operators

To add a new condition operator (e.g., `$regex`):

1. Update `_evaluateConditions()`:
```brightscript
if condition_value.$regex <> invalid
    ' Add regex matching logic
end if
```

2. Document in TESTING.md
3. Add tests
4. Update examples

### Custom Hashing

To use custom hashing for variation assignment:

1. Create custom hash function
2. Pass user/variation to custom function
3. Use result for bucketing

### Analytics Integration

Tracking callback provides integration point:

```brightscript
trackingCallback: sub(experiment, result)
    ' Send to your analytics platform
    analyticsTrack({
        experimentId: experiment.key,
        variationId: result.variationId
    })
end sub
```

## Future Improvements

Potential enhancements:

1. **Streaming Features**: SSE support (Roku limitation)
2. **Feature Refresh**: Auto-refresh mechanism
3. **Encryption**: Payload decryption support
4. **Analytics**: Built-in event tracking
5. **Offline Mode**: Better offline fallbacks
6. **Visual Editor**: SceneGraph component support

---

For implementation details, see [source/GrowthBook.brs](../source/GrowthBook.brs)

For usage examples, see [examples/](../examples/)

For testing approach, see [TESTING.md](../TESTING.md)
