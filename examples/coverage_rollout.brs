'
' GrowthBook Roku SDK - Progressive Rollout Example
' 
' This example shows how to:
' 1. Use coverage parameter for gradual feature releases
' 2. Roll out features to a percentage of users
' 3. Monitor rollout progress
'

function Main()
    ' 1. Initialize GrowthBook
    config = {
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk_YOUR_CLIENT_KEY_HERE",
        attributes: {
            id: getUserId(),
            country: "US"
        },
        enableDevMode: true
    }
    
    gb = GrowthBook(config)
    
    if gb.init()
        print "✓ GrowthBook initialized"
    else
        print "✗ Failed to initialize"
        return
    end if
    
    ' 2. Progressive rollout example
    '
    ' In GrowthBook dashboard, configure a feature with:
    ' - Rule with coverage: 0.1 (10% of users)
    ' - Gradually increase to 0.5 (50%), then 1.0 (100%)
    '
    ' The SDK uses consistent hashing, so:
    ' - Same user always gets same result
    ' - Coverage increase never removes existing users
    
    result = gb.evalFeature("new-video-player")
    
    if result.on
        print "✓ User included in rollout"
        print "  Loading new video player..."
        loadNewVideoPlayer()
    else
        print "✗ User not in rollout yet"
        print "  Loading legacy video player..."
        loadLegacyVideoPlayer()
    end if
    
    ' 3. Check rollout status
    print ""
    print "Rollout Status:"
    print "  Feature: " + result.key
    if result.on then print "  In rollout: true" else print "  In rollout: false"
    print "  Source: " + result.source
    
    ' 4. Multiple rollouts with different coverages
    features = ["new-search", "new-recommendations", "new-player-ui"]
    
    print ""
    print "Feature Rollout Status:"
    for each featureKey in features
        featureResult = gb.evalFeature(featureKey)
        status = "OFF"
        if featureResult.on then status = "ON"
        print "  " + featureKey + ": " + status
    end for
    
end function

function loadNewVideoPlayer()
    print "  [New Player] Initializing..."
end function

function loadLegacyVideoPlayer()
    print "  [Legacy Player] Initializing..."
end function

function getUserId() as string
    ' Use consistent user ID for stable bucketing
    deviceInfo = CreateObject("roDeviceInfo")
    return deviceInfo.GetChannelClientId()
end function
