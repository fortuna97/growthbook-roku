'
' GrowthBook Roku SDK - Simple Feature Flag Example
' 
' This example shows how to:
' 1. Initialize the SDK
' 2. Load features
' 3. Check feature flags
'

' Include the SDK (automatically included when all .brs files are in source/)
' #include "GrowthBook.brs"

function Main()
    ' 1. Create GrowthBook instance with configuration
    config = {
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk_YOUR_CLIENT_KEY_HERE",
        attributes: {
            id: "user123",
            country: "US",
            subscription: "premium"
        },
        enableDevMode: true  ' Enable logging for debugging
    }
    
    gb = GrowthBook(config)
    
    ' 2. Initialize - load features from API
    if gb.init()
        print "✓ GrowthBook initialized successfully"
    else
        print "✗ Failed to initialize GrowthBook"
        ' Optionally load from cache or continue with defaults
    end if
    
    ' 3. Check feature flags
    
    ' Simple boolean flag
    if gb.isOn("enable-dark-mode")
        print "Dark mode is enabled"
        applyDarkTheme()
    else
        print "Dark mode is disabled"
        applyLightTheme()
    end if
    
    ' Get feature value with fallback
    maxVideos = gb.getFeatureValue("videos-per-row", 4)
    print "Videos per row: " + Str(maxVideos)
    
    ' Get complex feature value
    config = gb.getFeatureValue("player-config", {
        autoplay: false,
        quality: "HD"
    })
    print "Autoplay: " + Str(config.autoplay)
    print "Quality: " + config.quality
    
    ' Get detailed feature evaluation
    result = gb.evalFeature("new-ui")
    print "Feature: " + result.key
    print "Value: " + Str(result.value)
    print "Enabled: " + Str(result.on)
    print "Source: " + result.source
    
end function

function applyDarkTheme()
    print "Applying dark theme..."
    ' Your theme logic here
end function

function applyLightTheme()
    print "Applying light theme..."
    ' Your theme logic here
end function
