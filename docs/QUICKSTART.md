# GrowthBook Roku SDK - Quick Start

Get up and running with GrowthBook in 5 minutes.

---

## 1. Install (30 seconds)

Copy [`GrowthBook.brs`](../source/GrowthBook.brs) to your `source/` directory:

```
your-channel/
├── source/
│   ├── main.brs
│   └── GrowthBook.brs  ← Add this
```

---

## 2. Initialize (2 minutes)

**In your `main.brs`:**

```brightscript
sub Main()
    ' Create global instance
    m.global.addFields({ gb: invalid })
    
    ' Initialize GrowthBook
    m.global.gb = GrowthBook({
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk_YOUR_KEY_HERE",     ' Get from GrowthBook dashboard
        attributes: {
            id: GetDeviceId(),               ' Required for experiments
            appVersion: "1.0.0"              ' Your app version
        }
    })
    
    ' Load features
    if m.global.gb.init()
        print "✓ GrowthBook ready!"
    end if
    
    ' Your app code...
    ShowHomeScreen()
end sub

function GetDeviceId() as string
    di = CreateObject("roDeviceInfo")
    return di.GetChannelClientId()
end function
```

---

## 3. Use Features (2 minutes)

### Boolean Flags

```brightscript
' Enable/disable features
if m.global.gb.isOn("new-ui")
    ShowNewUI()
else
    ShowOldUI()
end if
```

### Feature Values

```brightscript
' Get configuration values
buttonColor = m.global.gb.getFeatureValue("button-color", "#0000FF")
maxVideos = m.global.gb.getFeatureValue("max-videos", 12)
```

### A/B Testing

```brightscript
' Users automatically assigned to variations
variant = m.global.gb.getFeatureValue("homepage-layout", "default")

if variant = "grid"
    ShowGridLayout()
else if variant = "list"
    ShowListLayout()
else
    ShowDefaultLayout()
end if
```

---

## 4. Create Your First Feature (GrowthBook Dashboard)

1. Go to **Features** → **Add Feature**
2. Key: `new-ui`
3. Type: Boolean
4. Default Value: `false`
5. Click **Save**
6. Toggle to `true` to enable for all users

**Your channel will pick up the change immediately!**

---

## 5. Create Your First Experiment (GrowthBook Dashboard)

1. Go to **Experiments** → **Add Experiment**
2. Key: `button-color-test`
3. Variations: 
   - `"#0000FF"` (blue)
   - `"#FF0000"` (red)
4. Traffic: 50% / 50%
5. Click **Start Experiment**

**Users are automatically split 50/50 consistently!**

---

## Examples

### Feature Flag

```brightscript
if m.global.gb.isOn("enable-4k")
    Enable4KStreaming()
end if
```

### Configuration Value

```brightscript
timeout = m.global.gb.getFeatureValue("timeout-ms", 5000)
SetRequestTimeout(timeout)
```

### Version Targeting

**In GrowthBook Dashboard:**
- Rule: `appVersion >= "2.0.0"`

**In Your Code:**
```brightscript
' Automatically shown only to users on v2.0.0+
if m.global.gb.isOn("new-search")
    ShowNewSearch()
end if
```

### JSON Config

```brightscript
playerConfig = m.global.gb.getFeatureValue("player-settings", {
    autoplay: false,
    quality: "HD"
})

if playerConfig.autoplay then StartAutoplay()
```

---

## Common Patterns

### Singleton Access Helper

```brightscript
' Add helper function
function GB() as object
    return m.global.gb
end function

' Use anywhere
if GB().isOn("feature") then DoSomething()
```

### Safe Access with Fallback

```brightscript
function GetFeature(key as string, default as dynamic) as dynamic
    if m.global.gb <> invalid
        return m.global.gb.getFeatureValue(key, default)
    end if
    return default
end function
```

---

## Next Steps

- ✅ [Full Integration Guide](INTEGRATION_GUIDE.md) - Production deployment
- ✅ [API Reference](API.md) - Complete method documentation
- ✅ [Examples](../examples/) - More code samples

---

## Troubleshooting

**SDK not loading?**
- Check `GrowthBook.brs` is in `source/` directory
- Verify file name is exact: `GrowthBook.brs` (case-sensitive)

**Features not working?**
- Check `clientKey` is correct
- Verify `init()` returns `true`
- Enable dev mode: `enableDevMode: true` in config

**Experiments inconsistent?**
- Verify `id` attribute is stable (use device ID, not random)
- Check user ID is set before evaluating features

---

**Ready to go!** 🚀 Start building with GrowthBook.
