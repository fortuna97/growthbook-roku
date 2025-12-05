'
' GrowthBook Roku SDK - Version Targeting Example
'
' Shows how to use version comparison operators for phased rollouts
' New in v1.0.0: $vgt, $vgte, $vlt, $vlte, $veq, $vne
'

function Main()
    ' Initialize with app version
    gb = GrowthBook({
        attributes: {
            id: GetDeviceId(),
            appVersion: "2.1.0"
        },
        features: {
            ' New feature for v2.0.0+
            "new-search-ui": {
                defaultValue: false,
                rules: [{
                    condition: { appVersion: { "$vgte": "2.0.0" } },
                    force: true
                }]
            },
            
            ' 4K streaming for v2.1.0+
            "enable-4k": {
                defaultValue: false,
                rules: [{
                    condition: { appVersion: { "$vgte": "2.1.0" } },
                    force: true
                }]
            },
            
            ' Update banner for old versions
            "show-update-banner": {
                defaultValue: false,
                rules: [{
                    condition: { appVersion: { "$vlt": "2.0.0" } },
                    force: true
                }]
            }
        }
    })
    gb.init()
    
    print "App Version: 2.1.0"
    print ""
    
    ' Check version-targeted features
    if gb.isOn("new-search-ui")
        print "✓ New Search UI enabled (v2.0.0+)"
        ShowNewSearch()
    else
        print "Using legacy search"
    end if
    
    if gb.isOn("enable-4k")
        print "✓ 4K Streaming enabled (v2.1.0+)"
        Enable4K()
    else
        print "HD streaming only"
    end if
    
    if gb.isOn("show-update-banner")
        print "⚠ Update banner shown (< v2.0.0)"
    else
        print "No update needed"
    end if
    
end function

function ShowNewSearch()
    print "Loading new search UI..."
end function

function Enable4K()
    print "Enabling 4K streaming..."
end function

function GetDeviceId() as string
    di = CreateObject("roDeviceInfo")
    return di.GetChannelClientId()
end function
