# GrowthBook Roku SDK - API Reference

Complete API documentation for the GrowthBook Roku SDK.

## Table of Contents

- [SDK Initialization](#sdk-initialization)
- [Core Methods](#core-methods)
- [Configuration Options](#configuration-options)
- [Result Objects](#result-objects)
- [Error Handling](#error-handling)
- [Examples](#examples)

## SDK Initialization

### `GrowthBook(config)`

Creates a new GrowthBook SDK instance.

**Parameters:**
- `config` (object) - Configuration object

**Returns:**
- GrowthBook SDK instance

**Example:**
```brightscript
gb = GrowthBook({
    apiHost: "https://cdn.growthbook.io",
    clientKey: "sdk_YOUR_KEY",
    attributes: {
        id: "user123",
        country: "US"
    }
})
```

## Core Methods

### `init() as boolean`

Loads features from GrowthBook API or uses provided features.

**Parameters:** None

**Returns:**
- `true` if features loaded successfully
- `false` if initialization failed

**Behavior:**
1. If features were provided in config, use those
2. If clientKey provided, fetch from API
3. Otherwise fail with error

**Example:**
```brightscript
if gb.init()
    print "Ready to use GrowthBook"
else
    print "Failed to load features"
end if
```

**Error Scenarios:**
- No `clientKey` and no features provided: returns `false`
- Network error: returns `false`, logs error
- JSON parse error: returns `false`, logs error

---

### `isOn(featureKey) as boolean`

Check if a boolean feature is enabled.

**Parameters:**
- `featureKey` (string) - Feature identifier

**Returns:**
- `true` if feature is enabled
- `false` if disabled or missing

**Behavior:**
- Returns `true` for boolean features with `defaultValue: true`
- Returns `false` for missing features
- Coerces non-boolean values to boolean

**Example:**
```brightscript
if gb.isOn("dark-mode")
    applyDarkTheme()
end if
```

**Note:** For detailed evaluation info, use `evalFeature()` instead.

---

### `getFeatureValue(featureKey, fallback) as dynamic`

Get the value of a feature with a fallback.

**Parameters:**
- `featureKey` (string) - Feature identifier
- `fallback` (dynamic) - Value if feature not found

**Returns:**
- Feature value if found
- `fallback` if feature missing or empty

**Behavior:**
- Returns feature's `defaultValue` if object
- Returns feature value directly if primitive
- Returns fallback if feature doesn't exist

**Example:**
```brightscript
' String value
color = gb.getFeatureValue("button-color", "#0000FF")

' Numeric value
maxItems = gb.getFeatureValue("items-per-page", 20)

' Complex object
config = gb.getFeatureValue("player-config", {
    autoplay: false,
    quality: "HD"
})
```

---

### `evalFeature(featureKey) as object`

Get detailed feature evaluation result.

**Parameters:**
- `featureKey` (string) - Feature identifier

**Returns:**
- Feature evaluation result object (see [Result Objects](#result-objects))

**Behavior:**
1. Evaluates targeting rules
2. Resolves experiment variations
3. Falls back to default value
4. Returns comprehensive result

**Example:**
```brightscript
result = gb.evalFeature("new-ui")

if result.on
    print "Feature enabled"
    print "Value: " + Str(result.value)
    print "Source: " + result.source
    
    if result.experimentId <> ""
        print "Experiment: " + result.experimentId
    end if
end if
```

---

### `setAttributes(attributes) as void`

Update user attributes for targeting and experiments.

**Parameters:**
- `attributes` (object) - User attributes to set

**Returns:** Nothing

**Behavior:**
- Replaces existing attributes with new ones
- Attributes used for targeting on next evaluation
- Can be called multiple times

**Example:**
```brightscript
gb.setAttributes({
    id: "user123",
    country: "US",
    subscription: "premium",
    accountAge: 365
})

' Later, update when user logs in
gb.setAttributes({
    id: newUserId,
    country: newCountry,
    subscription: newTier
})
```

**Common Attributes:**
- `id` (string) - User ID (required for experiments)
- `email` (string) - User email
- `name` (string) - User name
- `country` (string) - User's country
- `subscription` (string) - Subscription tier
- `accountAge` (integer) - Account age in days
- `isPremium` (boolean) - Premium user flag

---

## Configuration Options

Pass configuration object to `GrowthBook()`:

```brightscript
config = {
    apiHost: "https://cdn.growthbook.io",
    clientKey: "sdk_YOUR_KEY",
    decryptionKey: "",
    attributes: { ... },
    trackingCallback: sub(experiment, result) ... end sub,
    enableDevMode: false,
    features: { ... }
}
gb = GrowthBook(config)
```

### `apiHost` (string, optional)

**Default:** `"https://cdn.growthbook.io"`

GrowthBook API endpoint. Use custom host for self-hosted.

```brightscript
config.apiHost = "https://growthbook.mycompany.com"
```

### `clientKey` (string, required for API loading)

**Default:** `""`

SDK client key from GrowthBook dashboard. Required to fetch features from API.

```brightscript
config.clientKey = "sdk_abcdef123456"
```

### `decryptionKey` (string, optional)

**Default:** `""`

Key for decrypting encrypted feature payloads. Requires Roku OS 9.2+.

```brightscript
config.decryptionKey = "your_decryption_key"
```

### `attributes` (object, optional)

**Default:** `{}`

User attributes for targeting. Can be updated with `setAttributes()`.

```brightscript
config.attributes = {
    id: "user123",
    country: "US",
    isPremium: true
}
```

### `trackingCallback` (function, optional)

**Default:** `invalid`

Callback invoked when user enters an experiment.

```brightscript
config.trackingCallback = sub(experiment, result)
    ' Send to analytics
    analyticsTrack("experiment_viewed", {
        experimentId: experiment.key,
        variationId: result.variationId
    })
end sub
```

**Callback Parameters:**
- `experiment` (object) - Experiment/rule object
- `result` (object) - Evaluation result

### `enableDevMode` (boolean, optional)

**Default:** `false`

Enable verbose logging for debugging.

```brightscript
config.enableDevMode = true
' SDK will print debug messages to console
```

### `features` (object, optional)

**Default:** `{}`

Pre-loaded features (offline mode). If provided, API won't be called.

```brightscript
config.features = {
    "feature1": { defaultValue: true },
    "feature2": { defaultValue: "value" }
}
```

### `savedGroups` (object, optional)

**Default:** `{}`

**New in v1.2.0** - Pre-defined user groups for group-based targeting.

```brightscript
config.savedGroups = {
    "beta_testers": ["user_001", "user_002", "user_003"],
    "vip_customers": ["user_100", "user_101"],
    "employees": ["emp_001", "emp_002"]
}
```

Used with `$inGroup` and `$notInGroup` operators (see [Group Operators](#group-operators)).

---

## Targeting and Conditions

GrowthBook supports powerful targeting rules to show features to specific user segments.

### Comparison Operators

#### Numeric Comparisons

| Operator | Meaning | Example |
|----------|---------|---------|
| `$eq` | Equal to | `{ "age": { "$eq": 25 } }` |
| `$ne` | Not equal to | `{ "age": { "$ne": 25 } }` |
| `$gt` | Greater than | `{ "age": { "$gt": 18 } }` |
| `$gte` | Greater than or equal | `{ "age": { "$gte": 21 } }` |
| `$lt` | Less than | `{ "age": { "$lt": 65 } }` |
| `$lte` | Less than or equal | `{ "age": { "$lte": 64 } }` |

#### Version Comparisons

**New in v1.0.0** - Semantic version comparison operators.

| Operator | Meaning | Example |
|----------|---------|---------|
| `$veq` | Version equals | `{ "appVersion": { "$veq": "2.0.0" } }` |
| `$vne` | Version not equals | `{ "appVersion": { "$vne": "1.0.0" } }` |
| `$vgt` | Version greater than | `{ "appVersion": { "$vgt": "1.9.0" } }` |
| `$vgte` | Version greater/equal | `{ "appVersion": { "$vgte": "2.0.0" } }` |
| `$vlt` | Version less than | `{ "appVersion": { "$vlt": "3.0.0" } }` |
| `$vlte` | Version less/equal | `{ "appVersion": { "$vlte": "2.9.9" } }` |

**Examples:**

```javascript
// Roll out to users on v2.0.0 or newer
{
  "appVersion": { "$vgte": "2.0.0" }
}

// Version range
{
  "$and": [
    { "appVersion": { "$vgte": "2.0.0" } },
    { "appVersion": { "$vlt": "3.0.0" } }
  ]
}
```

**In your code:**
```brightscript
attributes: {
    id: GetDeviceId(),
    appVersion: "2.1.0"  ' Use semantic versioning
}
```

#### Array Operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `$in` | Value in array | `{ "country": { "$in": ["US", "CA"] } }` |
| `$nin` | Value not in array | `{ "country": { "$nin": ["XX"] } }` |
| `$all` | Array contains all | `{ "tags": { "$all": ["premium"] } }` |
| `$size` | Array size | `{ "tags": { "$size": 3 } }` |

**Array Intersection (v1.1.0+):**

When the user attribute is an array, `$in` and `$nin` perform intersection matching:

```javascript
// User attribute
attributes: {
    tags: ["premium", "beta", "early-adopter"]
}

// Condition: match if ANY tag is in the list
{ "tags": { "$in": ["beta", "qa"] } }
// Result: TRUE (user has "beta")

// Condition: exclude if ANY tag matches
{ "tags": { "$nin": ["banned", "suspended"] } }
// Result: TRUE (user has neither)
```

**Use cases:**
- Tag-based audience targeting
- Multi-role permission checks
- Feature access by subscription tiers

### Logical Operators

| Operator | Meaning |
|----------|---------|
| `$and` | All conditions true |
| `$or` | At least one true |
| `$not` | Inverts condition |
| `$nor` | None can be true |

### Group Operators

**New in v1.2.0** - Target users based on saved group membership.

| Operator | Meaning | Example |
|----------|---------|---------|
| `$inGroup` | User is in saved group | `{ "id": { "$inGroup": "beta_testers" } }` |
| `$notInGroup` | User is NOT in saved group | `{ "id": { "$notInGroup": "banned_users" } }` |

**Configuration:**

```brightscript
config = {
    clientKey: "sdk_YOUR_KEY",
    attributes: {
        id: "user_12345"
    },
    savedGroups: {
        "beta_testers": ["user_12345", "user_67890"],
        "vip_customers": ["user_99999"],
        "banned_users": ["user_banned_1"]
    }
}
gb = GrowthBook(config)
```

**Targeting Rules:**

```javascript
// Target beta testers
{ "id": { "$inGroup": "beta_testers" } }

// Exclude banned users
{ "id": { "$notInGroup": "banned_users" } }

// Combine with other conditions
{
  "$and": [
    { "id": { "$inGroup": "beta_testers" } },
    { "country": { "$in": ["US", "CA"] } }
  ]
}
```

**Behavior:**
- `$inGroup`: Returns `true` if user's attribute value exists in the saved group array
- `$notInGroup`: Returns `true` if group doesn't exist OR user is not in the group
- Group names must match exactly (case-sensitive)

### Element Match Operator

**New in v1.2.0** - Match elements within arrays.

| Operator | Meaning | Example |
|----------|---------|---------|
| `$elemMatch` | Array element matches condition | `{ "devices": { "$elemMatch": { "type": "roku" } } }` |

**Primitive Arrays:**

```javascript
// User attribute
attributes: {
    watchHistory: ["movie_001", "movie_002", "series_001"]
}

// Check if user watched a specific movie
{ "watchHistory": { "$elemMatch": { "$eq": "movie_001" } } }

// Check for numeric values
attributes: { scores: [85, 92, 78] }
{ "scores": { "$elemMatch": { "$gte": 90 } } }  // true (92 >= 90)
```

**Object Arrays:**

```javascript
// User attribute
attributes: {
    devices: [
        { type: "roku", model: "ultra", year: 2024 },
        { type: "mobile", model: "iphone", year: 2023 }
    ]
}

// Check for Roku device from 2024+
{
  "devices": {
    "$elemMatch": {
      "type": "roku",
      "year": { "$gte": 2024 }
    }
  }
}
```

---

## Result Objects

### Evaluation Result

Returned by `evalFeature()`:

```javascript
{
    key: "feature-key",           // Feature identifier
    value: <any>,                  // Feature value
    on: true,                      // Is feature enabled
    off: false,                    // Is feature disabled
    source: "defaultValue",        // Where value came from
    ruleId: "rule-123",           // Which rule matched (if any)
    experimentId: "exp-456",      // Which experiment (if any)
    variationId: 0                // Which variation 0-indexed
}
```

### Source Values

Indicates where the feature value came from:

| Source | Meaning |
|--------|---------|
| `"defaultValue"` | Using feature's default value |
| `"force"` | Forced by a targeting rule |
| `"experiment"` | Assigned from experiment variation |
| `"unknownFeature"` | Feature doesn't exist |

---

## Error Handling

### Network Errors

```brightscript
' Gracefully handle network failures
if not gb.init()
    ' Use cached features or defaults
    print "Could not load features from API"
    
    ' Continue with app using fallback values
end if
```

### Feature Not Found

```brightscript
' isOn returns false for missing features
if gb.isOn("missing-feature")
    ' This won't execute
end if

' getFeatureValue returns fallback for missing
value = gb.getFeatureValue("missing", "default")
' value = "default"

' evalFeature returns unknownFeature source
result = gb.evalFeature("missing")
' result.source = "unknownFeature"
' result.on = false
```

### Invalid Configuration

```brightscript
' No clientKey and no features provided
gb = GrowthBook({})
if not gb.init()
    ' Error: must provide clientKey or features
end if
```

### Debug Mode

Enable logging to diagnose issues:

```brightscript
gb = GrowthBook({
    clientKey: "sdk_key",
    enableDevMode: true
})
gb.init()

' Console output:
' [GrowthBook] Loading features from: https://...
' [GrowthBook] Features loaded successfully: 42 features
```

---

## Examples

### Basic Feature Flag

```brightscript
gb = GrowthBook({
    clientKey: "sdk_test123",
    attributes: { id: "user123" }
})
gb.init()

if gb.isOn("enable-new-ui")
    showNewUI()
else
    showOldUI()
end if
```

### A/B Test with Tracking

```brightscript
gb = GrowthBook({
    clientKey: "sdk_test123",
    attributes: { id: "user123" },
    trackingCallback: sub(exp, result)
        print "User in experiment: " + exp.key
    end sub
})
gb.init()

result = gb.evalFeature("button-color-test")
buttonColor = result.value
' Analytics sees exposure automatically
```

### Configuration Management

```brightscript
playerConfig = gb.getFeatureValue("player-settings", {
    autoplay: false,
    quality: "HD",
    subtitles: "on"
})

player.autoplay = playerConfig.autoplay
player.quality = playerConfig.quality
player.subtitles = playerConfig.subtitles
```

### Advanced Targeting

```brightscript
gb.setAttributes({
    id: userId,
    subscription: "premium",
    country: "US",
    accountAge: 365
})

' All conditions must match
if gb.isOn("premium-us-feature")
    showFeature()
end if
```

### Runtime Attribute Updates

```brightscript
' Initial attributes
gb.setAttributes({ id: "guest" })

' ... user logs in ...

' Update attributes
gb.setAttributes({
    id: "user123",
    subscription: "premium",
    accountAge: 500
})

' Feature evaluation now uses new attributes
if gb.isOn("premium-feature")
    showPremiumFeature()
end if
```

### Offline/Cached Features

```brightscript
' Store features locally
cachedFeatures = gb.features
' Save to file or registry

' On app restart
gb = GrowthBook({
    features: loadedCachedFeatures,
    attributes: { id: "user123" }
})
gb.init()
' Works offline
```

---

## Limitations

- No streaming (SSE) support due to Roku limitations
- Local evaluation only (no remote evaluation)
- No Visual Editor experiments (SceneGraph only)
- AES decryption requires Roku OS 9.2+
- Single-threaded synchronous API

## Related Resources

- [GrowthBook Documentation](https://docs.growthbook.io)
- [Roku Developer Docs](https://developer.roku.com/docs)
- [Architecture Guide](./ARCHITECTURE.md)
- [Testing Guide](../TESTING.md)
