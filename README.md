# GrowthBook Roku SDK

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![BrightScript](https://img.shields.io/badge/BrightScript-2.0-purple.svg)](https://developer.roku.com/docs/references/brightscript/language/brightscript-language-reference.md)
[![Roku](https://img.shields.io/badge/Roku-SceneGraph-6f3f9f.svg)](https://developer.roku.com/)
[![Version](https://img.shields.io/badge/version-1.3.0-blue.svg)](CHANGELOG.md)
[![Production Ready](https://img.shields.io/badge/status-production%20ready-green.svg)](docs/INTEGRATION_GUIDE.md)

Official [GrowthBook](https://www.growthbook.io/) SDK for Roku/BrightScript applications. Add feature flags and A/B testing to your Roku channels with a simple, lightweight SDK.

**Current Version:** v1.3.0 — [View Changelog](CHANGELOG.md) | [Integration Guide](docs/INTEGRATION_GUIDE.md) | [Quick Start](docs/QUICKSTART.md)

## Features

- 🚀 **Lightweight** - Core SDK is ~50KB, minimal memory footprint
- ⚡ **Fast** - Feature evaluation in <1ms, optimized for Roku devices
- 🎯 **Powerful Targeting** - Target users by app version, attributes, and segments
- 🧪 **A/B Testing** - Run experiments with accurate traffic splits (70/30, 50/25/25, etc.)
- 🔄 **Consistent Bucketing** - Same user always sees same variation (cross-platform)
- 📊 **Analytics Ready** - Built-in experiment tracking callbacks
- 🔒 **Secure** - Support for encrypted feature payloads
- 🎨 **No Dependencies** - Pure BrightScript, works on all Roku devices (Roku 3+, OS 9.0+)

## Quick Start

### 1. Installation

Copy `GrowthBook.brs` to your Roku channel's `source/` directory:

```brightscript
your-roku-channel/
├── source/
│   ├── main.brs
│   └── GrowthBook.brs  ← Add this file
└── manifest
```

### 2. Initialize

```brightscript
' In your main.brs or scene component
function initGrowthBook() as object
    config = {
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk-abc123",  ' Your GrowthBook client key
        attributes: {
            id: "user-123",
            deviceType: "roku",
            premium: true
        }
    }
    
    gb = GrowthBook(config)
    
    ' Load features from GrowthBook API
    if gb.init()
        print "GrowthBook ready!"
    end if
    
    return gb
end function
```

### 3. Use Feature Flags

```brightscript
' Boolean feature flag
if gb.isOn("new-player-ui") then
    showNewPlayer()
else
    showLegacyPlayer()
end if

' Get feature value with fallback
buttonColor = gb.getFeatureValue("cta-color", "#0000FF")
maxVideos = gb.getFeatureValue("videos-per-page", 12)

' JSON feature configuration
playerConfig = gb.getFeatureValue("player-settings", {
    autoplay: false,
    quality: "HD"
})
```

### Important: Instance Management (SINGLETON PATTERN IS SUGGESTED)

**Create one instance and resuse it.**

```brightscript
' Initialize ONCE when app starts
m.global.addFields({ gb: invalid })

function InitApp()
    m.global.gb = GrowthBook({
        clientKey: "sdk_YOUR_KEY",
        attributes: { id: GetUserId() }
    })
    m.global.gb.init()
end function

' Reuse the same instance throughout your app
function ShowFeature()
    if m.global.gb.isOn("feature-key") then
        ' Feature logic
    end if
end function

' Update attributes when needed (e.g., user login)
function OnUserLogin(newUserId)
    m.global.gb.setAttributes({ id: newUserId })
    ' Features are now re-evaluated with new user ID
end function
```

### Why This Matters

**Creating a new instance for each feature check causes:**

| Problem | Impact |
|---------|--------|
| **Redundant API calls** | Every `init()` call fetches features again (expensive) |
| **Memory waste** | Each instance consumes ~150KB of memory |
| **Inconsistent variations** | Different hash seeds mean same user gets different variations |
| **Poor performance** | Network latency on every feature evaluation |
| **Broken experiments** | Inconsistent variation assignment for A/B tests |

### Best Practice: Singleton at App Level

```brightscript
' In your app's global initialization
function Main()
    ' Create ONCE
    globalNode = CreateObject("roSGNode", "GlobalNode")
    
    ' Initialize GrowthBook once
    gb = GrowthBook({
        clientKey: "sdk_YOUR_KEY",
        attributes: { id: "user123" }
    })
    if gb.init()
        ' Store globally to reuse everywhere
        globalNode.addFields({ growthBook: gb })
    end if
    
    ' Now use it throughout your app
    ' Access via: globalNode.growthBook
end function
```

### Updating Attributes vs. Recreating Instance

```brightscript
' ✅ DO THIS: Update attributes without recreating instance
m.global.gb.setAttributes({
    id: newUserId,
    subscription: "premium",
    country: "US"
})

' ❌ DON'T DO THIS: Creating new instance to change attributes
m.global.gb = GrowthBook({ ... })  ' Wrong!
m.global.gb.init()                 ' Wrong!
```

---

## Detailed Examples

### Example 1: Basic Configuration & Instantiation

```brightscript
'
' Complete example showing SDK configuration and initialization
'

function InitializeGrowthBook() as object
    ' Step 1: Create configuration object
    config = {
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk_YOUR_CLIENT_KEY",
        
        ' Set user attributes for targeting
        attributes: {
            id: "user-" + GetUserId(),           ' Unique user ID
            email: GetUserEmail(),                ' User email
            subscription: GetSubscriptionTier(), ' free, basic, premium, enterprise
            country: "US",                        ' User location
            isPremium: (GetSubscriptionTier() = "premium")
        },
        
        ' Enable debug logging during development
        enableDevMode: false
    }
    
    ' Step 2: Create GrowthBook instance
    gb = GrowthBook(config)
    
    ' Step 3: Initialize - load features from API
    if gb.init()
        print "✓ GrowthBook initialized successfully"
        print "  Features loaded: " + Str(gb.features.Count())
    else
        print "✗ Failed to initialize GrowthBook"
        ' Optionally continue with defaults or cached features
        return invalid
    end if
    
    return gb
end function

function GetUserId() as string
    ' Get from your app's user data
    return "12345"
end function

function GetUserEmail() as string
    return "user@example.com"
end function

function GetSubscriptionTier() as string
    ' Return: "free", "basic", "premium", or "enterprise"
    return "premium"
end function

' Usage in your main application
sub Main()
    gb = InitializeGrowthBook()
    
    if gb <> invalid
        ' Now ready to use feature flags
        if gb.isOn("app-feature")
            print "Feature is enabled!"
        end if
    end if
end sub
```

### Example 2: Setting Attributes & Evaluating Features

```brightscript
'
' Comprehensive example showing attribute management and feature evaluation
'

sub ManageUserAttributesAndFeatures()
    ' Initialize with basic attributes
    gb = GrowthBook({
        clientKey: "sdk_YOUR_KEY",
        attributes: {
            id: "user-123",
            country: "US"
        }
    })
    gb.init()
    
    ' =========================================================
    ' SECTION 1: Initial Feature Evaluation
    ' =========================================================
    
    print "--- Initial State ---"
    if gb.isOn("enable-new-ui")
        print "✓ New UI is enabled"
        LoadNewUserInterface()
    else
        print "✗ New UI is disabled, using legacy"
        LoadLegacyUserInterface()
    end if
    
    
    ' =========================================================
    ' SECTION 2: User Logs In - Update Attributes
    ' =========================================================
    
    ' When user logs in, update their attributes
    gb.setAttributes({
        id: "user-456",                    ' Now we know their real ID
        email: "john@example.com",         ' Email address
        subscription: "premium",           ' Premium subscriber
        country: "US",
        accountAgeInDays: 365,             ' Account created a year ago
        watchTimeMinutes: 50000            ' User has watched a lot
    })
    
    print ""
    print "--- After User Login ---"
    
    
    ' =========================================================
    ' SECTION 3: Evaluate Features with New Attributes
    ' =========================================================
    
    ' Feature 1: Premium feature (only for premium users)
    if gb.isOn("premium-features")
        print "✓ Premium features available"
        ShowPremiumContent()
    else
        print "✗ Premium features not available"
    end if
    
    ' Feature 2: Get specific value with fallback
    maxQuality = gb.getFeatureValue("max-video-quality", "1080p")
    print "  Max quality: " + maxQuality
    
    ' Feature 3: Complex object configuration
    playerSettings = gb.getFeatureValue("player-config", {
        autoplay: false,
        quality: "HD",
        subtitles: "on",
        dolbyVision: false
    })
    
    print "  Player autoplay: " + Str(playerSettings.autoplay)
    print "  Player quality: " + playerSettings.quality
    
    
    ' =========================================================
    ' SECTION 4: Detailed Feature Evaluation
    ' =========================================================
    
    ' Get detailed evaluation including source and targeting info
    result = gb.evalFeature("advanced-search")
    
    print ""
    print "--- Feature Evaluation Details ---"
    print "Feature: " + result.key
    print "Enabled: " + Str(result.on)
    print "Value: " + Str(result.value)
    print "Source: " + result.source  ' defaultValue, force, experiment, or unknownFeature
    
    if result.source = "experiment"
        print "Experiment: " + result.experimentId
        print "Variation: " + Str(result.variationId)
    end if
    
    
    ' =========================================================
    ' SECTION 5: Attribute Updates Over Time
    ' =========================================================
    
    ' User upgrades subscription
    print ""
    print "--- User Upgrades Subscription ---"
    gb.setAttributes({
        id: "user-456",
        email: "john@example.com",
        subscription: "enterprise",        ' Now enterprise user!
        country: "US",
        accountAgeInDays: 365,
        watchTimeMinutes: 50000
    })
    
    ' Re-evaluate premium features
    if gb.isOn("premium-features")
        print "✓ Enterprise features now available"
    end if
    
    ' Get enterprise-specific feature
    apiLimit = gb.getFeatureValue("api-rate-limit", 1000)
    print "  API rate limit: " + Str(apiLimit) + " requests/day"
    
end sub

function LoadNewUserInterface()
    print "Loading new UI..."
end function

function LoadLegacyUserInterface()
    print "Loading legacy UI..."
end function

function ShowPremiumContent()
    print "Showing premium content..."
end function
```

### Example 3: Advanced Targeting & Experiment Tracking

```brightscript
'
' Advanced example with complex targeting conditions and experiment tracking
'

sub AdvancedTargetingAndExperiments()
    ' Initialize with tracking callback
    config = {
        clientKey: "sdk_YOUR_KEY",
        attributes: {
            id: "user-789",
            subscription: "premium",
            country: "US",
            accountAge: 200,
            isTestUser: false
        },
        
        ' Callback fired when user enters an experiment
        trackingCallback: sub(experiment, result)
            print "[EXPERIMENT TRACKED]"
            print "  Experiment ID: " + experiment.key
            print "  Variation ID: " + Str(result.variationId)
            print "  Value: " + Str(result.value)
            
            ' Send to your analytics platform
            SendAnalyticsEvent({
                event: "experiment_exposed",
                experimentId: experiment.key,
                variationId: result.variationId,
                userId: experiment.userId
            })
        end sub
    }
    
    gb = GrowthBook(config)
    gb.init()
    
    
    ' =========================================================
    ' TARGETING BY SUBSCRIPTION LEVEL
    ' =========================================================
    
    print "--- Premium Features (Subscription Targeting) ---"
    
    ' This feature only shows for premium/enterprise users
    if gb.isOn("advanced-analytics")
        print "✓ Advanced analytics available for premium users"
        ShowAdvancedAnalytics()
    end if
    
    
    ' =========================================================
    ' TARGETING BY COUNTRY
    ' =========================================================
    
    print ""
    print "--- Regional Features (Country Targeting) ---"
    
    ' Feature targeted to US & Canada only
    if gb.isOn("hdr-streaming")
        print "✓ HDR streaming enabled for North America"
    else
        print "✗ HDR streaming not available in your region"
    end if
    
    
    ' =========================================================
    ' A/B TESTING - BUTTON COLOR EXPERIMENT
    ' =========================================================
    
    print ""
    print "--- A/B Testing: Button Color ---"
    
    ' Get button color from experiment
    ' User will be consistently assigned to same variation
    buttonColorResult = gb.evalFeature("button-color-test")
    
    ' buttonColorResult will contain:
    ' - value: the assigned color
    ' - variationId: 0 or 1 (which variation they're in)
    ' - source: "experiment" if in test, "defaultValue" if not
    ' - experimentId: ID of the experiment
    
    buttonColor = buttonColorResult.value
    if buttonColorResult.source = "experiment"
        print "User in A/B test (Variation " + Str(buttonColorResult.variationId) + ")"
        print "Button color: " + Str(buttonColor)
    else
        print "Using default button color: " + Str(buttonColor)
    end if
    
    ' Store for later conversion tracking
    m.global.addFields({
        currentButtonColor: buttonColor,
        buttonExperimentId: buttonColorResult.experimentId
    })
    
    
    ' =========================================================
    ' A/B TESTING - PROGRESSIVE ROLLOUT
    ' =========================================================
    
    print ""
    print "--- Progressive Rollout: New Video Player ---"
    
    ' This feature gradually rolls out to percentage of users
    ' based on consistent hash of user ID
    useNewPlayer = gb.isOn("new-video-player-rollout")
    
    if useNewPlayer
        print "✓ Using new video player (progressive rollout)"
        m.player = CreateObject("roSGNode", "NewVideoPlayer")
    else
        print "✗ Using legacy video player"
        m.player = CreateObject("roSGNode", "LegacyVideoPlayer")
    end if
    
    
    ' =========================================================
    ' COMPLEX TARGETING - MULTI-CONDITION
    ' =========================================================
    
    print ""
    print "--- Complex Targeting: Premium US Users Only ---"
    
    ' This feature requires multiple conditions:
    ' - subscription = "premium" OR "enterprise"
    ' - country = "US"
    ' - accountAge > 30 days
    
    if gb.isOn("vip-support-exclusive")
        print "✓ VIP support available"
        ShowVIPSupport()
    else
        print "✗ VIP support not available for this user"
    end if
    
    
    ' =========================================================
    ' FEATURE VALUE WITH COMPLEX OBJECT
    ' =========================================================
    
    print ""
    print "--- Complex Feature Configuration ---"
    
    playerConfig = gb.getFeatureValue("player-configuration", {
        autoplay: false,
        quality: "1080p",
        bitrateLimit: 10000,
        enableSubtitles: true,
        enableDolbyVision: false,
        cacheSize: 500
    })
    
    print "Player settings:"
    print "  Autoplay: " + Str(playerConfig.autoplay)
    print "  Quality: " + playerConfig.quality
    print "  Bitrate limit: " + Str(playerConfig.bitrateLimit) + " Kbps"
    print "  Subtitles: " + Str(playerConfig.enableSubtitles)
    print "  Dolby Vision: " + Str(playerConfig.enableDolbyVision)
    print "  Cache size: " + Str(playerConfig.cacheSize) + " MB"
    
    ' Apply to player
    m.player.autoplay = playerConfig.autoplay
    m.player.quality = playerConfig.quality
    m.player.bitrateLimit = playerConfig.bitrateLimit
    
    
    ' =========================================================
    ' CONVERSION TRACKING (Manual)
    ' =========================================================
    
    ' When user completes an action (like purchase):
    ' You track it manually with the experiment context
    
end sub

function ShowAdvancedAnalytics()
    print "Showing advanced analytics dashboard..."
end function

function ShowVIPSupport()
    print "Showing VIP support options..."
end function

sub SendAnalyticsEvent(event as object)
    ' Send event to your analytics service
    ' Example: send to Roku analytics, Firebase, Mixpanel, etc.
    print "[ANALYTICS] Event: " + event.event
end sub
```

## Installation

### Option 1: Manual Installation (Recommended)

1. Download [`GrowthBook.brs`](./source/GrowthBook.brs)
2. Copy to your channel's `source/` directory
3. Initialize in your main scene or component

### Option 2: Git Submodule

```bash
cd your-roku-channel
git submodule add https://github.com/growthbook/growthbook-roku.git lib/growthbook
```

Then reference the SDK:

```brightscript
' In your main.brs
' Roku will automatically include all .brs files from source/
```

## Documentation

### Configuration Options

| Option | Type | Description |
|--------|------|-------------|
| `apiHost` | string | GrowthBook API host (default: `https://cdn.growthbook.io`) |
| `clientKey` | string | **Required** - Your SDK client key from GrowthBook |
| `decryptionKey` | string | Optional - Decrypt encrypted feature payloads |
| `attributes` | object | User attributes for targeting (e.g., `{id: "user-123", premium: true}`) |
| `trackingCallback` | function | Callback fired when user is placed in an experiment |
| `enableDevMode` | boolean | Enable verbose logging for debugging |

### Core Methods

#### `init() as boolean`

Load features from GrowthBook API. Returns `true` on success.

```brightscript
if gb.init()
    print "Features loaded successfully"
end if
```

#### `isOn(featureKey as string) as boolean`

Check if a boolean feature flag is enabled.

```brightscript
if gb.isOn("dark-mode") then
    applyDarkTheme()
end if
```

#### `getFeatureValue(featureKey as string, fallback as dynamic) as dynamic`

Get the value of a feature flag with a fallback.

```brightscript
theme = gb.getFeatureValue("theme-color", "#0000FF")
maxItems = gb.getFeatureValue("max-items", 20)
```

#### `setAttributes(attributes as object)`

Update user attributes for targeting.

```brightscript
gb.setAttributes({
    id: userId,
    subscription: "premium",
    country: "US"
})
```

#### `evalFeature(featureKey as string) as object`

Get detailed feature evaluation result.

```brightscript
result = gb.evalFeature("pricing-test")
print result.value       ' The feature value
print result.source      ' Where it came from: "defaultValue", "force", "experiment"
print result.on          ' Boolean: is feature "on"
```

## Examples

See the `examples/` directory for complete working examples:

- `simple_flag.brs` - Basic feature flag usage
- `experiments.brs` - A/B testing with tracking
- `targeting.brs` - Advanced audience targeting
- `coverage_rollout.brs` - Progressive feature rollouts
- `array_targeting.brs` - Tag-based targeting with arrays
- `version_targeting.brs` - Semantic version targeting
- `weighted_experiments.brs` - Custom traffic splits
- `consistent_hashing.brs` - User bucketing consistency

## Testing

### Run Tests Without a Device

Use the JavaScript mock to validate core logic:

```bash
npm test
```

### Validate BrightScript Syntax

```bash
npm install -g @rokucommunity/bsc
npm run lint
```

### Deploy to Roku Device

```bash
export ROKU_DEV_TARGET=192.168.1.100
export ROKU_DEV_PASSWORD=your-password

npm run deploy
```

See [TESTING.md](./TESTING.md) for comprehensive testing guide.

## Performance

Benchmarks on Roku Ultra (2023):

| Operation | Time | Notes |
|-----------|------|-------|
| SDK Initialization | ~50ms | Without network call |
| Feature Load (API) | 500-2000ms | First load from network |
| Feature Evaluation | <1ms | Cached, in-memory |
| Experiment Evaluation | <2ms | With hashing & targeting |

**Memory Usage:** ~150KB total (SDK + cached features)

## Browser Support

Works on all Roku devices:

- ✅ Roku Ultra
- ✅ Roku Streaming Stick
- ✅ Roku Express
- ✅ Roku TV
- ✅ Roku Premiere
- ✅ Legacy Roku devices (Roku 2/3)

Minimum Roku OS: 9.0+

## Limitations

- No Server-Sent Events (SSE) streaming support (Roku limitation)
- No Visual Editor experiments (SceneGraph only)
- AES decryption requires `roEVPCipher` component (Roku OS 9.2+)
- Network requests are asynchronous only

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

### Development Setup

1. Fork and clone the repo
2. Make changes to `source/GrowthBook.brs`
3. Test with `npm test`
4. Deploy to Roku device for integration testing
5. Submit a pull request

### Running Tests

```bash
# Install dependencies
npm install

# Run unit tests
npm test

# Validate syntax
npm run lint

# Deploy to test device
npm run deploy
```

## FAQ

**Q: Does this work with SceneGraph?**  
A: Yes! Initialize GrowthBook in your Scene component and access it throughout your SceneGraph tree.

**Q: Can I use this offline?**  
A: Yes, features are cached after the first load. Pass features directly to skip network calls:

```brightscript
gb = GrowthBook({features: myFeaturesObject})
```

**Q: How do I target by device type?**  
A: Set device info as attributes:

```brightscript
deviceInfo = CreateObject("roDeviceInfo")
gb.setAttributes({
    id: userId,
    deviceType: deviceInfo.GetModel(),
    osVersion: deviceInfo.GetVersion()
})
```

**Q: Does this support remote evaluation?**  
A: No, Roku SDK uses local evaluation only. Features are evaluated on the device.

## Related SDKs

- [JavaScript SDK](https://github.com/growthbook/growthbook/tree/main/packages/sdk-js)
- [Python SDK](https://github.com/growthbook/growthbook-python)
- [Ruby SDK](https://github.com/growthbook/growthbook-ruby)
- [PHP SDK](https://github.com/growthbook/growthbook-php)
- [Go SDK](https://github.com/growthbook/growthbook-golang)

## Resources

- 📚 [GrowthBook Documentation](https://docs.growthbook.io)
- 🎓 [Roku Developer Docs](https://developer.roku.com/docs)
- 💬 [GrowthBook Slack Community](https://slack.growthbook.io)
- 🐛 [Issue Tracker](https://github.com/growthbook/growthbook-roku/issues)

## License

MIT License - see [LICENSE](./LICENSE) file for details.

## Support

- 📧 Email: support@growthbook.io
- 💬 Slack: [Join our community](https://slack.growthbook.io)
- 🐛 Issues: [GitHub Issues](https://github.com/growthbook/growthbook-roku/issues)

---

Made with ❤️ by the [GrowthBook](https://www.growthbook.io) team
