'
' GrowthBook Roku SDK - Weighted Experiments Example
'
' Shows A/B testing with custom traffic splits (70/30, 50/25/25, etc.)
' Fixed in v1.0.0: Weights now work correctly
'

function Main()
    gb = GrowthBook({
        attributes: {
            id: GetDeviceId()
        },
        features: {
            ' 70/30 split test
            "button-color": {
                rules: [{
                    key: "button-test",
                    variations: ["green", "blue"],
                    weights: [0.7, 0.3]
                }]
            },
            
            ' Multi-variant: 25% each
            "homepage-layout": {
                rules: [{
                    key: "layout-test",
                    variations: ["grid", "list", "carousel", "default"],
                    weights: [0.25, 0.25, 0.25, 0.25]
                }]
            },
            
            ' Gradual rollout: 5% get new feature
            "new-player": {
                rules: [{
                    key: "player-rollout",
                    variations: [true, false],
                    weights: [0.05, 0.95]
                }]
            }
        }
    })
    gb.init()
    
    ' 70/30 split test
    buttonColor = gb.getFeatureValue("button-color", "blue")
    print "Button color: " + buttonColor + " (70% green, 30% blue)"
    
    if buttonColor = "green"
        ShowGreenButton()
    else
        ShowBlueButton()
    end if
    
    ' Multi-variant test
    layout = gb.getFeatureValue("homepage-layout", "default")
    print "Layout: " + layout + " (25% each)"
    
    if layout = "grid"
        ShowGridLayout()
    else if layout = "list"
        ShowListLayout()
    else if layout = "carousel"
        ShowCarouselLayout()
    else
        ShowDefaultLayout()
    end if
    
    ' Gradual rollout
    if gb.isOn("new-player")
        print "New player enabled (5% rollout)"
        ShowNewPlayer()
    else
        print "Legacy player (95%)"
        ShowLegacyPlayer()
    end if
    
end function

function ShowGreenButton()
    print "Showing green button"
end function

function ShowBlueButton()
    print "Showing blue button"
end function

function ShowGridLayout()
    print "Loading grid layout"
end function

function ShowListLayout()
    print "Loading list layout"
end function

function ShowCarouselLayout()
    print "Loading carousel layout"
end function

function ShowDefaultLayout()
    print "Loading default layout"
end function

function ShowNewPlayer()
    print "Loading new video player"
end function

function ShowLegacyPlayer()
    print "Loading legacy player"
end function

function GetDeviceId() as string
    di = CreateObject("roDeviceInfo")
    return di.GetChannelClientId()
end function
