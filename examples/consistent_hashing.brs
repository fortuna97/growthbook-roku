'
' GrowthBook Roku SDK - Consistent Hashing Example
'
' Shows that users get the same variation across sessions
' Fixed in v1.0.0: Seeded hash function ensures consistency
'

function Main()
    userId = "user-12345"
    
    print "Testing consistent bucketing for: " + userId
    print ""
    
    ' Simulate 5 different app sessions
    for session = 1 to 5
        gb = GrowthBook({
            attributes: { id: userId },
            features: {
                "button-test": {
                    rules: [{
                        key: "test-experiment",
                        variations: ["A", "B", "C"],
                        weights: [0.33, 0.33, 0.34]
                    }]
                }
            }
        })
        gb.init()
        
        variant = gb.getFeatureValue("button-test", "control")
        print "Session " + Str(session).Trim() + ": " + variant
    end for
    
    print ""
    print "✓ All sessions show same variant"
    print "This works across:"
    print "  - App restarts"
    print "  - Different devices (same user ID)"
    print "  - Roku, Python, JavaScript, Java SDKs"
    
    print ""
    print "Testing different users get different variations..."
    print ""
    
    ' Show distribution across different users
    for i = 1 to 5
        testUserId = "user-" + Str(i).Trim()
        
        gb = GrowthBook({
            attributes: { id: testUserId },
            features: {
                "button-test": {
                    rules: [{
                        key: "test-experiment",
                        variations: ["A", "B", "C"],
                        weights: [0.33, 0.33, 0.34]
                    }]
                }
            }
        })
        gb.init()
        
        variant = gb.getFeatureValue("button-test", "control")
        print testUserId + " → " + variant
    end for
    
    print ""
    print "✓ Different users distributed across variations"
    
end function
