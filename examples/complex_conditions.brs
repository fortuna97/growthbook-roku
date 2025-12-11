'
' GrowthBook Roku SDK - Complex Conditions Example
' 
' This example shows how to:
' 1. Use $elemMatch for array element matching
' 2. Deep object equality comparisons
' 3. Nested logical operators ($and, $or, $not)
' 4. Real-world complex targeting scenarios
'

function Main()
    ' 1. Initialize with complex attributes
    '
    ' Real-world apps often have nested objects and arrays
    
    config = {
        apiHost: "https://cdn.growthbook.io",
        clientKey: "sdk_YOUR_CLIENT_KEY_HERE",
        attributes: {
            id: "user_12345",
            
            ' Nested object attributes
            subscription: {
                plan: "premium",
                status: "active",
                expiresAt: "2025-12-31"
            },
            
            ' Array of objects (e.g., devices, purchases)
            devices: [
                { type: "roku", model: "ultra", year: 2024 },
                { type: "mobile", model: "iphone", year: 2023 }
            ],
            
            ' Array of primitives
            watchHistory: ["movie_001", "movie_002", "series_001"],
            genres: ["action", "comedy", "sci-fi"],
            
            ' Numeric attributes
            watchTimeMinutes: 1500,
            accountAgeDays: 365
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
    
    ' 2. $elemMatch with nested objects
    '
    ' Check if user has a Roku device from 2024 or later:
    ' { 
    '   "devices": { 
    '     "$elemMatch": { 
    '       "type": "roku",
    '       "year": { "$gte": 2024 }
    '     }
    '   }
    ' }
    
    print ""
    print "=== Device Targeting with $elemMatch ==="
    if gb.isOn("4k-hdr-streaming")
        print "✓ 4K HDR enabled (user has modern Roku device)"
    else
        print "✗ 4K HDR not available"
    end if
    
    ' 3. $elemMatch with primitives
    '
    ' Check if user has watched specific content:
    ' {
    '   "watchHistory": {
    '     "$elemMatch": { "$eq": "movie_001" }
    '   }
    ' }
    
    print ""
    print "=== Watch History Targeting ==="
    if gb.isOn("sequel-recommendation")
        print "✓ Showing sequel recommendations (user watched movie_001)"
    else
        print "✗ Sequel recommendations not shown"
    end if
    
    ' 4. Deep object equality
    '
    ' Match exact subscription object:
    ' {
    '   "subscription": {
    '     "plan": "premium",
    '     "status": "active"
    '   }
    ' }
    '
    ' Note: This requires exact match of specified properties
    
    print ""
    print "=== Subscription Matching ==="
    if gb.isOn("premium-exclusive-content")
        print "✓ Premium exclusive content available"
    else
        print "✗ Premium content not available"
    end if
    
    ' 5. Complex nested conditions with $and, $or, $not
    '
    ' Target engaged premium users who aren't new:
    ' {
    '   "$and": [
    '     { "subscription.plan": "premium" },
    '     { "watchTimeMinutes": { "$gte": 1000 } },
    '     { "$not": { "accountAgeDays": { "$lt": 30 } } }
    '   ]
    ' }
    
    print ""
    print "=== Complex Nested Conditions ==="
    if gb.isOn("loyalty-rewards")
        print "✓ Loyalty rewards enabled (premium + engaged + not new)"
    else
        print "✗ Loyalty rewards not available"
    end if
    
    ' 6. $or with multiple conditions
    '
    ' Target users interested in action OR sci-fi:
    ' {
    '   "$or": [
    '     { "genres": { "$elemMatch": { "$eq": "action" } } },
    '     { "genres": { "$elemMatch": { "$eq": "sci-fi" } } }
    '   ]
    ' }
    
    print ""
    print "=== Genre-Based Targeting ==="
    if gb.isOn("new-action-scifi-releases")
        print "✓ Showing action/sci-fi new releases"
    else
        print "✗ Not showing genre-specific content"
    end if
    
    ' 7. $not for exclusion logic
    '
    ' Show to everyone EXCEPT users who watched series_001:
    ' {
    '   "$not": {
    '     "watchHistory": { "$elemMatch": { "$eq": "series_001" } }
    '   }
    ' }
    
    print ""
    print "=== Exclusion with $not ==="
    if gb.isOn("series-001-promo")
        print "✗ Not showing promo (user already watched)"
    else
        print "✓ Promo hidden (user already watched series_001)"
    end if
    
    ' 8. Display current user profile
    print ""
    print "=== User Profile Summary ==="
    print "  subscription: premium (active)"
    print "  devices: [roku-ultra-2024, mobile-iphone-2023]"
    print "  watchHistory: 3 items"
    print "  genres: [action, comedy, sci-fi]"
    print "  watchTimeMinutes: 1500"
    print "  accountAgeDays: 365"
    
end function

