# GrowthBook Roku SDK - Integration Guide

**Version:** 2.0.1  
**Last Updated:** February 2026  
**Target:** Production deployment

---

## Overview

This guide provides step-by-step instructions for integrating the GrowthBook Roku SDK into your production Roku channel. The SDK enables feature flags, A/B testing, and targeted rollouts with minimal overhead.

**What you'll achieve:**
- Feature flags with server-side control
- A/B experiments with configurable traffic splits
- User targeting by version, attributes, and segments
- Encrypted feature payloads for secure delivery
- Sticky bucketing for persistent experiment assignments
- Tracking plugins for analytics integration
- On-demand feature refresh without channel redeployment

**Performance:**
- SDK size: ~50KB
- Feature evaluation: <1ms per check
- Memory footprint: <500KB
- Zero external dependencies

---

## Prerequisites

- Roku channel project (BrightScript/SceneGraph)
- GrowthBook account with API access
- Client SDK key from GrowthBook dashboard
- Roku device for testing (Roku 3+, OS 9.0+)

---

## Installation

### Step 1: Add SDK File

Copy `GrowthBook.brs` to your channel's `source/` directory:

```
your-channel/
├── components/
├── images/
├── source/
│   ├── main.brs
│   └── GrowthBook.brs          ← Add this file
└── manifest
```

**Download:** [GrowthBook.brs](../source/GrowthBook.brs)

### Step 2: Verify Installation

Add a test in your `main.brs`:

```brightscript
sub Main()
    ' Test SDK is loaded
    testConfig = { features: {} }
    gb = GrowthBook(testConfig)
    if gb <> invalid
        print "✓ GrowthBook SDK loaded successfully"
    else
        print "✗ Failed to load GrowthBook SDK"
    end if
    
    ' Your existing code...
end sub
```

Run your channel. You should see: `✓ GrowthBook SDK loaded successfully`

---

## Basic Configuration

### Step 3: Initialize SDK (Singleton Pattern)

**Recommended:** Create one instance and reuse it globally.

**In your main.brs or init function:**

```brightscript
sub InitializeApp()
    ' Create global field for GrowthBook instance
    m.global.addFields({ gb: invalid })
    
    ' Initialize GrowthBook
    m.global.gb = GrowthBook({
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk_YOUR_CLIENT_KEY_HERE",  ' Replace with your key
        attributes: GetUserAttributes(),
        enableDevMode: false
    })
    
    ' Load features from GrowthBook API
    if m.global.gb.init()
        print "GrowthBook ready - features loaded"
    else
        print "GrowthBook failed to initialize"
    end if
end sub

function GetUserAttributes() as object
    return {
        id: GetDeviceId(),                    ' Required for experiments
        deviceType: "roku",
        appVersion: GetAppVersion(),          ' For version targeting
        country: GetUserCountry(),
        premium: IsUserPremium()
    }
end function

function GetDeviceId() as string
    di = CreateObject("roDeviceInfo")
    return di.GetChannelClientId()
end function

function GetAppVersion() as string
    appInfo = CreateObject("roAppInfo")
    return appInfo.GetVersion()
end function
```

### Step 4: Use Features Throughout Your App

**Access the global instance anywhere:**

```brightscript
' In any component or function
function ShowVideoPlayer()
    gb = m.global.gb
    
    ' Boolean feature flag
    if gb.isOn("new-player-ui")
        ShowNewPlayerUI()
    else
        ShowLegacyPlayerUI()
    end if
end function

function GetPlayerConfig() as object
    gb = m.global.gb
    
    ' Get feature values with defaults
    return {
        autoplay: gb.getFeatureValue("autoplay-enabled", false),
        quality: gb.getFeatureValue("default-quality", "HD"),
        maxRetries: gb.getFeatureValue("max-retries", 3)
    }
end function
```

---

## Feature Flag Patterns

### Pattern 1: Simple Boolean Flag

```brightscript
' Enable/disable features remotely
if m.global.gb.isOn("enable-4k-streaming")
    EnableHighResolutionStreaming()
end if

if m.global.gb.isOn("show-promotional-banner")
    DisplayBanner()
end if
```

### Pattern 2: String Configuration

```brightscript
' Different button colors for A/B testing
ctaColor = m.global.gb.getFeatureValue("cta-button-color", "#0000FF")
m.ctaButton.color = ctaColor

' API endpoints
apiEndpoint = m.global.gb.getFeatureValue("api-endpoint", "https://api.example.com")
```

### Pattern 3: JSON Configuration

```brightscript
' Complex feature configuration
playerSettings = m.global.gb.getFeatureValue("player-settings", {
    autoplay: false,
    quality: "HD",
    showCaptions: true,
    bufferSize: 5
})

if playerSettings.autoplay = true
    StartAutoplay()
end if
```

### Pattern 4: Numeric Values

```brightscript
' Configurable limits
maxVideos = m.global.gb.getFeatureValue("videos-per-page", 12)
DisplayVideos(maxVideos)

timeout = m.global.gb.getFeatureValue("request-timeout-ms", 5000)
SetTimeout(timeout)
```

---

## A/B Testing (Experiments)

### Setting Up Experiments

**In GrowthBook Dashboard:**
1. Create experiment: "button-color-test"
2. Set variations: ["#0000FF", "#FF0000", "#00FF00"]
3. Set weights: [0.5, 0.25, 0.25] (50% / 25% / 25%)
4. Save and publish

**In Your Code:**

```brightscript
function RenderCTAButton()
    ' GrowthBook automatically assigns users to variations
    buttonColor = m.global.gb.getFeatureValue("button-color-test", "#0000FF")
    
    m.ctaButton.color = buttonColor
    
    ' Track button clicks for analytics
    m.ctaButton.observeField("buttonSelected", "OnCTAClicked")
end function

sub OnCTAClicked()
    ' Your analytics tracking here
    TrackEvent("cta_clicked", {
        button_color: m.ctaButton.color
    })
end sub
```

**How it works:**
- Each user gets consistent variation based on their `id` attribute
- Traffic split matches your configured weights (50/25/25)
- No user sees flickering or inconsistent experiences

---

## Targeting Rules

### Target by App Version

**Use Case:** Roll out new features only to users on latest version.

```brightscript
' In GrowthBook Dashboard, set targeting rule:
' appVersion >= "2.0.0"

' Users on v2.0.0+ see new feature automatically
if m.global.gb.isOn("new-search-feature")
    ShowNewSearch()
else
    ShowLegacySearch()
end if
```

**Supported version operators:**
- `$vgt`: Greater than (e.g., `"appVersion": { "$vgt": "1.9.0" }`)
- `$vgte`: Greater than or equal
- `$vlt`: Less than
- `$vlte`: Less than or equal
- `$veq`: Equals
- `$vne`: Not equals

**Examples:**
- Show feature only to v2.0.0+: `{ "appVersion": { "$vgte": "2.0.0" } }`
- Hide from old versions: `{ "appVersion": { "$vgt": "1.5.0" } }`
- Target specific version: `{ "appVersion": { "$veq": "2.1.0" } }`

### Target by User Attributes

```brightscript
' Premium users only
' Dashboard rule: premium = true
if m.global.gb.isOn("premium-content")
    ShowPremiumContent()
end if

' Country-specific features
' Dashboard rule: country = "US"
if m.global.gb.isOn("us-only-feature")
    ShowUSContent()
end if

' Multiple conditions
' Dashboard rule: premium = true AND country IN ["US", "CA", "UK"]
if m.global.gb.isOn("premium-us-ca-uk-feature")
    ShowRegionalPremiumContent()
end if
```

### Update User Attributes Dynamically

```brightscript
' When user upgrades to premium
sub OnUserUpgradedToPremium()
    m.global.gb.setAttributes({
        id: GetDeviceId(),
        premium: true,           ' ← Updated
        upgradeDate: GetCurrentDate()
    })
    
    ' Features will now evaluate with new attributes
    RefreshUI()
end sub
```

---

## Encrypted Features (v2.0.0)

If your GrowthBook project uses encrypted feature payloads, configure the SDK with your decryption key. The SDK automatically decrypts AES-128-CBC encrypted payloads.

**Requirements:** Roku OS 9.2+ (for `roEVPCipher`)

### Setup

```brightscript
gb = GrowthBook({
    apiHost: "https://cdn.growthbook.io",
    clientKey: "sdk_YOUR_KEY",
    decryptionKey: "your-base64-decryption-key",  ' From GrowthBook dashboard
    attributes: { id: "user-123" }
})
gb.init()  ' Encrypted features are decrypted transparently
```

### How It Works

1. API returns `encryptedFeatures` (base64-encoded IV + ciphertext) instead of plain `features`
2. SDK uses AES-128-CBC with the provided key to decrypt
3. Decrypted JSON is parsed normally — no changes to `isOn()`, `getFeatureValue()`, etc.
4. If decryption fails (wrong key, corrupted data), SDK logs an error and continues with empty features

### Encrypted Saved Groups

If your project also encrypts saved groups, the SDK handles `encryptedSavedGroups` the same way:

```brightscript
gb = GrowthBook({
    clientKey: "sdk_YOUR_KEY",
    decryptionKey: "your-key",  ' Decrypts both features and saved groups
    savedGroups: {}              ' Will be populated from encrypted response
})
```

---

## Sticky Bucketing (v2.0.0)

Sticky bucketing ensures users always see the same experiment variation, even when:
- User attributes change (e.g., anonymous to logged-in)
- Experiment traffic allocation changes
- Bucket ranges are re-assigned

### Setup with In-Memory Service

For testing or single-session use:

```brightscript
sbs = GrowthBookInMemoryStickyBucketService()

gb = GrowthBook({
    clientKey: "sdk_YOUR_KEY",
    attributes: { id: "user-123" },
    stickyBucketService: sbs
})
gb.init()
```

### Setup with Registry Service (Production)

For persistent storage across app restarts:

```brightscript
sbs = GrowthBookRegistryStickyBucketService()

gb = GrowthBook({
    clientKey: "sdk_YOUR_KEY",
    attributes: { id: "user-123" },
    stickyBucketService: sbs
})
gb.init()
```

### Anonymous to Logged-In Transition

Sticky bucketing supports `fallbackAttribute` for seamless user transitions:

```brightscript
' Before login: user identified by device ID
gb.setAttributes({
    deviceId: "roku-abc123",
    id: ""
})

' After login: user identified by account ID
' Sticky bucket preserves the variation from deviceId
gb.setAttributes({
    deviceId: "roku-abc123",
    id: "user-456"
})
```

The experiment's `fallbackAttribute` (configured in GrowthBook dashboard) tells the SDK to check the `deviceId` assignment when the primary `id` has no prior assignment.

---

## Tracking Plugins (v2.0.0)

Tracking plugins provide a structured way to send experiment exposure and feature usage events to your analytics platform.

### Built-In Plugin

The SDK includes `GrowthBookTrackingPlugin` for sending batched HTTP events:

```brightscript
plugin = GrowthBookTrackingPlugin({
    ingestorHost: "https://analytics.example.com",
    clientKey: "sdk_YOUR_KEY",
    batchSize: 10
})

gb = GrowthBook({
    clientKey: "sdk_YOUR_KEY",
    attributes: { id: "user-123" }
})
gb.init()
gb.registerTrackingPlugin(plugin)

' Now all experiment exposures and feature evaluations
' are automatically sent to your endpoint
```

### Using with trackingCallback

Tracking plugins work alongside the existing `trackingCallback`. Both are called:

```brightscript
gb = GrowthBook({
    clientKey: "sdk_YOUR_KEY",
    attributes: { id: "user-123" },
    trackingCallback: sub(experiment, result)
        ' Direct callback - fires immediately
        print "Experiment: " + experiment.key
    end sub
})
gb.init()

' Plugin - receives events via plugin interface
gb.registerTrackingPlugin(myPlugin)
```

---

## Refreshing Features (v2.0.0)

For long-running Roku apps, you can refresh features on demand:

```brightscript
' Refresh when user navigates to a new section
sub OnScreenChanged()
    if m.global.gb.refreshFeatures()
        print "Features updated"
        RefreshUI()
    end if
end sub
```

---

## Production Best Practices

### 1. Error Handling

```brightscript
function SafeFeatureCheck(featureKey as string, defaultValue as dynamic) as dynamic
    gb = m.global.gb
    
    if gb = invalid
        print "Warning: GrowthBook not initialized"
        return defaultValue
    end if
    
    return gb.getFeatureValue(featureKey, defaultValue)
end function

' Usage
maxRetries = SafeFeatureCheck("max-retries", 3)
```

### 2. Fallback for Network Failures

```brightscript
sub InitializeApp()
    m.global.gb = GrowthBook({
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk_YOUR_KEY",
        attributes: GetUserAttributes(),
        features: GetDefaultFeatures()  ' ← Fallback features
    })
    
    ' Try to fetch from API, fallback to defaults if offline
    success = m.global.gb.init()
    if not success
        print "Using default features (offline mode)"
    end if
end sub

function GetDefaultFeatures() as object
    ' Embedded fallback features for offline resilience
    return {
        "enable-4k-streaming": { defaultValue: true },
        "videos-per-page": { defaultValue: 12 },
        "api-endpoint": { defaultValue: "https://api.example.com" }
    }
end function
```

### 3. Lazy Initialization (Optional)

```brightscript
' Initialize only when needed
function GetGrowthBook() as object
    if m.global.gb = invalid
        InitializeGrowthBook()
    end if
    return m.global.gb
end function
```

### 4. Singleton Access Helper

```brightscript
' Create helper function for cleaner code
function GB() as object
    return m.global.gb
end function

' Usage becomes cleaner
if GB().isOn("new-feature") then ShowNewFeature()
```

---

## Testing Your Integration

### Test 1: Verify SDK Loads

```brightscript
sub TestSDKLoads()
    gb = GrowthBook({ features: {} })
    if gb <> invalid
        print "✓ SDK loads successfully"
    else
        print "✗ SDK failed to load"
    end if
end sub
```

### Test 2: Verify Feature Flags Work

```brightscript
sub TestFeatureFlags()
    gb = GrowthBook({
        features: {
            "test-feature": { defaultValue: true }
        }
    })
    gb.init()
    
    if gb.isOn("test-feature")
        print "✓ Feature flags working"
    else
        print "✗ Feature flag failed"
    end if
    
    value = gb.getFeatureValue("test-feature", false)
    if value = true
        print "✓ Feature values working"
    else
        print "✗ Feature value failed"
    end if
end sub
```

### Test 3: Verify Targeting Rules

```brightscript
sub TestTargeting()
    gb = GrowthBook({
        attributes: {
            id: "test-user",
            premium: true,
            appVersion: "2.0.0"
        },
        features: {
            "premium-only": {
                defaultValue: false,
                rules: [{
                    condition: { premium: true },
                    force: true
                }]
            }
        }
    })
    gb.init()
    
    if gb.isOn("premium-only")
        print "✓ Targeting rules working"
    else
        print "✗ Targeting failed"
    end if
end sub
```

### Test 4: Verify Experiments

```brightscript
sub TestExperiments()
    gb = GrowthBook({
        attributes: {
            id: "user-123"
        },
        features: {
            "button-color": {
                rules: [{
                    key: "color-test",
                    variations: ["blue", "red", "green"],
                    weights: [0.5, 0.3, 0.2]
                }]
            }
        }
    })
    gb.init()
    
    color = gb.getFeatureValue("button-color", "blue")
    print "User assigned to color: "; color
    
    ' Verify same user gets same variation consistently
    color2 = gb.getFeatureValue("button-color", "blue")
    if color = color2
        print "✓ Consistent bucketing working"
    else
        print "✗ Bucketing inconsistent"
    end if
end sub
```

---

## Troubleshooting

### Issue: "GrowthBook not initialized"

**Symptoms:** `m.global.gb` is `invalid`

**Solutions:**
1. Verify `GrowthBook.brs` is in `source/` directory
2. Check `InitializeApp()` is called before using SDK
3. Verify `m.global.addFields({ gb: invalid })` is executed

### Issue: Features not loading

**Symptoms:** `init()` returns `false`

**Solutions:**
1. Verify `clientKey` is correct
2. Check network connectivity
3. Verify API host is reachable: `https://cdn.growthbook.io`
4. Check Roku device logs for error messages

**Debug:**
```brightscript
m.global.gb = GrowthBook({
    clientKey: "sdk_YOUR_KEY",
    enableDevMode: true  ' ← Enable debug logs
})

if not m.global.gb.init()
    print "Init failed - check logs above"
end if
```

### Issue: Version targeting not working

**Symptoms:** Version-based rules don't match expected behavior

**Solutions:**
1. Verify `appVersion` attribute is set correctly
2. Check version format: use semantic versioning ("2.0.0", not "2.0" or "v2.0.0")
3. Test version comparison in GrowthBook dashboard preview
4. Use version operators: `$vgt`, `$vgte`, `$vlt`, `$vlte`, `$veq`, `$vne`

**Example:**
```brightscript
' Correct format
attributes: {
    appVersion: "2.1.3"  ' ✓ Good: semantic versioning
}

' Incorrect formats
attributes: {
    appVersion: "2.1"     ' ✗ Bad: incomplete version
    appVersion: "v2.1.3"  ' ✗ Bad: "v" prefix (SDK strips it, but avoid)
}
```

### Issue: Experiments show wrong traffic split

**Symptoms:** 50/50 split when expecting 70/30

**Solutions:**
1. Fixed in v1.0.0 ✓
2. Verify weights are set at experiment level in GrowthBook dashboard
3. Check weights array matches variations count
4. Test with multiple user IDs to verify distribution

**Correct Configuration:**
```javascript
// In GrowthBook Dashboard
{
  "variations": ["A", "B"],
  "weights": [0.7, 0.3]  // 70% A, 30% B
}
```

### Issue: Inconsistent variation assignment

**Symptoms:** User sees different variations on different sessions

**Solutions:**
1. Fixed in v1.0.0 ✓
2. Verify user `id` attribute is stable across sessions
3. Don't use random IDs - use device ID or user account ID
4. Check that `id` attribute is set before evaluating features

**Correct:**
```brightscript
attributes: {
    id: GetDeviceId()  ' ✓ Stable across sessions
}
```

**Incorrect:**
```brightscript
attributes: {
    id: Str(Rnd(999999))  ' ✗ Changes every time
}
```

---

## Performance Optimization

### Minimize SDK Calls in Loops

**❌ Inefficient:**
```brightscript
for i = 0 to videos.Count() - 1
    maxQuality = m.global.gb.getFeatureValue("max-quality", "HD")  ' Called 100 times
    videos[i].quality = maxQuality
end for
```

**✅ Efficient:**
```brightscript
maxQuality = m.global.gb.getFeatureValue("max-quality", "HD")  ' Called once
for i = 0 to videos.Count() - 1
    videos[i].quality = maxQuality
end for
```

### Cache Feature Results

```brightscript
function GetAppConfig() as object
    ' Cache configuration on first access
    if m.cachedConfig = invalid
        gb = m.global.gb
        m.cachedConfig = {
            autoplay: gb.getFeatureValue("autoplay", false),
            quality: gb.getFeatureValue("quality", "HD"),
            maxVideos: gb.getFeatureValue("max-videos", 12)
        }
    end if
    return m.cachedConfig
end function
```

---

## Support & Resources

### Documentation
- [API Reference](API.md) - Complete method documentation
- [Architecture](ARCHITECTURE.md) - SDK internals
- [Examples](../examples/) - Working code samples

### GrowthBook Resources
- [GrowthBook Documentation](https://docs.growthbook.io)
- [Feature Flags Guide](https://docs.growthbook.io/features)
- [A/B Testing Guide](https://docs.growthbook.io/experiments)

### Getting Help
- GitHub Issues: [growthbook/growthbook-roku](https://github.com/growthbook/growthbook-roku/issues)
- GrowthBook Slack: [Join Community](https://slack.growthbook.io)

---

## Next Steps

1. ✅ Complete integration using this guide
2. ✅ Test basic feature flags
3. ✅ Set up first experiment in GrowthBook dashboard
4. ✅ Configure encrypted features (if needed)
5. ✅ Enable sticky bucketing for stable experiment assignments
6. ✅ Register tracking plugins for analytics
7. ✅ Deploy to production
8. ✅ Monitor feature usage and experiment results

**Ready for production!** This SDK has been tested against 327/327 GrowthBook spec tests and validated for enterprise deployment.
