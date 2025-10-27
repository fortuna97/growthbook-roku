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
