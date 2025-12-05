'
' GrowthBook Roku SDK - A/B Testing & Experiments Example
' 
' This example shows how to:
' 1. Set up experiment tracking
' 2. Handle experiment variations
' 3. Track conversion events
'

function Main()
    ' 1. Initialize with tracking callback
    config = {
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk_YOUR_CLIENT_KEY_HERE",
        attributes: {
            id: "user123",
            country: "US"
        },
        trackingCallback: sub(experiment, result)
            ' This callback is called when a user enters an experiment
            print "Experiment Tracked:"
            print "  Experiment: " + experiment.key
            print "  Variation: " + Str(result.variationId).Trim()
            print "  Value: " + Str(result.value).Trim()
            
            ' Send to analytics platform
            sendToAnalytics({
                event: "experiment_viewed",
                experimentId: experiment.key,
                variationId: result.variationId
            })
        end sub
    }
    
    gb = GrowthBook(config)
    gb.init()
    
    ' 2. Get experiment variation
    ' This will automatically call the tracking callback
    buttonColorResult = gb.evalFeature("button-color-test")
    
    buttonColor = "blue"  ' Default fallback
    
    if buttonColorResult.source = "experiment"
        print "User is in experiment!"
        print "Assigned variation: " + Str(buttonColorResult.variationId).Trim()
        buttonColor = buttonColorResult.value
    else if buttonColorResult.source = "defaultValue"
        ' User doesn't qualify for experiment or it's not running
        buttonColor = buttonColorResult.value
    end if
    
    print "Button color: " + buttonColor
    
    ' 3. Use experiment variations
    ' Example: Progressive rollout
    useNewPlayer = gb.isOn("new-video-player-rollout")
    if useNewPlayer
        print "Loading new video player..."
        player = InitNewPlayer()
    else
        print "Loading legacy video player..."
        player = InitLegacyPlayer()
    end if
    
    ' 4. Track conversions in your event handlers
    ' When user purchases:
    ' onPurchaseComplete(buttonColor)
    
end function

function onPurchaseComplete(buttonColor as string)
    ' Track the purchase with experiment context
    sendToAnalytics({
        event: "purchase_completed",
        buttonColor: buttonColor,
        timestamp: GetTickCount()
    })
    
    print "Purchase tracked with button color: " + buttonColor
end function

function sendToAnalytics(data as object)
    ' Send to your analytics platform
    print "Analytics: " + FormatJson(data)
    
    ' In real implementation:
    ' http = CreateObject("roURLTransfer")
    ' http.SetUrl("https://your-analytics.com/track")
    ' http.PostFromString(FormatJson(data))
end function

function InitNewPlayer()
    print "New player initialized"
    return CreateObject("roSGNode", "VideoPlayer")
end function

function InitLegacyPlayer()
    print "Legacy player initialized"
    return CreateObject("roSGNode", "LegacyVideoPlayer")
end function

function FormatJson(obj as object) as string
    ' Simple JSON formatting (normally use FormatJson built-in)
    return "{ ... }"
end function
