'
' GrowthBook Roku SDK - Array Targeting Example
' 
' This example shows how to:
' 1. Use array attributes for tag-based targeting
' 2. Target users with multiple tags/roles
' 3. Use $in and $nin operators with arrays
'

function Main()
    ' 1. Initialize with array attributes
    '
    ' User can have multiple tags, roles, or subscriptions
    ' The $in operator checks if ANY element matches
    
    config = {
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk_YOUR_CLIENT_KEY_HERE",
        attributes: {
            id: "user123",
            
            ' Array attributes for flexible targeting
            tags: ["premium", "beta-tester", "early-adopter"],
            roles: ["viewer", "commenter"],
            subscriptions: ["movies", "sports"]
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
    
    ' 2. Tag-based feature targeting
    '
    ' In GrowthBook dashboard, configure targeting:
    ' { "tags": { "$in": ["beta-tester", "qa-team"] } }
    '
    ' This matches if user has ANY of the specified tags
    
    if gb.isOn("beta-features")
        print "✓ Beta features enabled (user is beta-tester)"
        enableBetaFeatures()
    else
        print "✗ Beta features disabled"
    end if
    
    ' 3. Subscription-based content
    '
    ' Target users with specific content subscriptions
    ' { "subscriptions": { "$in": ["sports", "live-events"] } }
    
    if gb.isOn("live-sports-stream")
        print "✓ Live sports available"
        showLiveSportsSection()
    end if
    
    ' 4. Exclusion targeting with $nin
    '
    ' Exclude users with certain tags
    ' { "tags": { "$nin": ["banned", "suspended"] } }
    
    if gb.isOn("community-features")
        print "✓ Community features enabled"
    else
        print "✗ Community features disabled (user may be restricted)"
    end if
    
    ' 5. Update tags at runtime
    print ""
    print "Updating user tags..."
    
    gb.setAttributes({
        id: "user123",
        tags: ["premium", "beta-tester", "early-adopter", "vip"],
        roles: ["viewer", "commenter", "moderator"],
        subscriptions: ["movies", "sports", "premium-content"]
    })
    
    ' Re-evaluate features with new tags
    if gb.isOn("vip-exclusive")
        print "✓ VIP exclusive content now available"
    end if
    
    ' 6. Display current targeting status
    print ""
    print "Current User Tags:"
    print "  tags: [premium, beta-tester, early-adopter, vip]"
    print "  roles: [viewer, commenter, moderator]"
    print "  subscriptions: [movies, sports, premium-content]"
    
end function

function enableBetaFeatures()
    print "  [Beta] Enabling experimental features..."
end function

function showLiveSportsSection()
    print "  [Sports] Loading live sports section..."
end function
