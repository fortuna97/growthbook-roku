'
' GrowthBook Roku SDK - Advanced Targeting Example
' 
' This example shows how to:
' 1. Use complex audience targeting
' 2. Target by device attributes
' 3. Implement progressive rollouts
' 4. Handle conditional features
'

function Main()
    ' Get device information for targeting
    deviceInfo = CreateObject("roDeviceInfo")
    
    ' 1. Initialize with rich user attributes
    config = {
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk_YOUR_CLIENT_KEY_HERE",
        attributes: {
            ' User attributes
            id: getUserId(),
            email: getUserEmail(),
            subscription: getUserSubscriptionTier(),
            
            ' Device attributes
            deviceType: deviceInfo.GetModel(),
            osVersion: deviceInfo.GetVersion(),
            isStick: (deviceInfo.GetModel() = "8004"),
            
            ' Behavior attributes
            accountAge: getAccountAgeDays(),
            watchTimeMinutes: getWatchTimeMinutes(),
            
            ' Location
            country: getUserCountry(),
            region: getUserRegion()
        }
    }
    
    gb = GrowthBook(config)
    gb.init()
    
    ' 2. Target premium users only
    if gb.isOn("premium-exclusive-feature")
        print "Showing premium feature"
        showPremiumContent()
    end if
    
    ' 3. Target by device type
    if gb.isOn("4k-streaming-enabled")
        print "4K streaming available"
        print "  Quality options: 1080p, 2K, 4K"
    else
        print "4K streaming disabled"
        print "  Quality options: 720p, 1080p"
    end if
    
    ' 4. Progressive rollout by percentage
    ' (Controlled via GrowthBook dashboard)
    useNewUI = gb.isOn("new-ui-rollout")
    if useNewUI
        loadNewUI()
    else
        loadLegacyUI()
    end if
    
    ' 5. Regional targeting
    uiLanguage = gb.getFeatureValue("ui-language", "en-US")
    print "UI Language: " + uiLanguage
    
    ' 6. Conditional features based on multiple attributes
    result = gb.evalFeature("advanced-search")
    if result.on and result.source <> "unknownFeature"
        print "Advanced search is available"
        print "  Reason: " + result.source
        if result.experimentId <> ""
            print "  Experiment: " + result.experimentId
        end if
    end if
    
    ' 7. Get configuration based on targeting
    playerConfig = gb.getFeatureValue("player-settings", {
        autoplay: false,
        quality: "HD",
        subtitles: "off"
    })
    
    ' Override defaults based on device
    if deviceInfo.GetModel() = "8004"  ' Roku Stick
        playerConfig.quality = "HD"  ' Limit to HD on Stick
    end if
    
    ' Apply configuration
    configurePlayer(playerConfig)
    
end function

function updateUserAttributes(gb as object, attributes as object)
    ' Update attributes at runtime (e.g., after login)
    ' This is useful when user properties change
    gb.setAttributes(attributes)
    print "User attributes updated"
end function

function showPremiumContent()
    print "Loading premium content..."
end function

function loadNewUI()
    print "Loading new UI..."
end function

function loadLegacyUI()
    print "Loading legacy UI..."
end function

function configurePlayer(config as object)
    print "Player configured:"
    if config.autoplay then print "  Autoplay: true" else print "  Autoplay: false"
    print "  Quality: " + config.quality
    print "  Subtitles: " + config.subtitles
end function

function getUserId() as string
    ' Get from your app's user data
    return "user_" + Str(RandInt(10000)).Trim()
end function

function getUserEmail() as string
    return "user@example.com"
end function

function getUserSubscriptionTier() as string
    ' "free", "basic", "premium", "enterprise"
    return "premium"
end function

function getAccountAgeDays() as integer
    ' Calculate days since account creation
    return 365
end function

function getWatchTimeMinutes() as integer
    ' Get from app database
    return 12000
end function

function getUserCountry() as string
    ' Get from device or app
    return "US"
end function

function getUserRegion() as string
    ' Get from device or app
    return "California"
end function

function RandInt(max as integer) as integer
    randomizer = CreateObject("roRandom")
    return randomizer.GetRandomNumber(max)
end function
