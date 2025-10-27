'
' GrowthBook Scenario Tests
' Simple, readable tests that demonstrate the SDK works correctly
' These can be manually reviewed without running on device
'

' ================================================================
' Scenario 1: Basic Feature Flag
' ================================================================
function ScenarioTest_BasicFeatureFlag() as string
    ' Setup: Create SDK with a simple boolean feature
    gb = GrowthBook({
        features: {
            "new-ui": { defaultValue: true },
            "old-feature": { defaultValue: false }
        }
    })
    gb.init()
    
    ' Test: Check if features work
    result1 = gb.isOn("new-ui")        ' Should be TRUE
    result2 = gb.isOn("old-feature")   ' Should be FALSE
    result3 = gb.isOn("missing")       ' Should be FALSE
    
    ' Expected: TRUE, FALSE, FALSE
    return "new-ui: " + Str(result1) + ", old-feature: " + Str(result2) + ", missing: " + Str(result3)
end function

' ================================================================
' Scenario 2: Feature Values
' ================================================================
function ScenarioTest_FeatureValues() as string
    ' Setup: Create SDK with different value types
    gb = GrowthBook({
        features: {
            "button-color": { defaultValue: "#FF0000" },
            "max-items": { defaultValue: 10 },
            "welcome-msg": { defaultValue: "Hello!" }
        }
    })
    gb.init()
    
    ' Test: Get feature values
    color = gb.getFeatureValue("button-color", "#000000")
    maxItems = gb.getFeatureValue("max-items", 5)
    message = gb.getFeatureValue("welcome-msg", "Hi")
    missing = gb.getFeatureValue("not-exists", "fallback")
    
    ' Expected: "#FF0000", 10, "Hello!", "fallback"
    return "color: " + color + ", maxItems: " + Str(maxItems) + ", msg: " + message + ", missing: " + missing
end function

' ================================================================
' Scenario 3: User Targeting - Simple
' ================================================================
function ScenarioTest_SimpleTargeting() as string
    ' Setup: SDK with user attributes
    gb = GrowthBook({
        attributes: {
            userId: "user-123",
            country: "US",
            isPremium: true
        }
    })
    gb.init()
    
    ' Test: Evaluate conditions
    condition1 = { country: "US" }
    condition2 = { country: "CA" }
    condition3 = { isPremium: true }
    condition4 = { isPremium: false }
    
    result1 = gb._evaluateConditions(condition1)  ' Should be TRUE (US = US)
    result2 = gb._evaluateConditions(condition2)  ' Should be FALSE (US ≠ CA)
    result3 = gb._evaluateConditions(condition3)  ' Should be TRUE
    result4 = gb._evaluateConditions(condition4)  ' Should be FALSE
    
    ' Expected: TRUE, FALSE, TRUE, FALSE
    return "US: " + Str(result1) + ", CA: " + Str(result2) + ", premium: " + Str(result3) + ", not-premium: " + Str(result4)
end function

' ================================================================
' Scenario 4: Advanced Targeting - $gt/$lt
' ================================================================
function ScenarioTest_NumericComparison() as string
    ' Setup: User with age attribute
    gb = GrowthBook({
        attributes: { age: 25 }
    })
    gb.init()
    
    ' Test: Numeric comparisons
    result1 = gb._evaluateConditions({ age: { "$gt": 18 } })      ' Should be TRUE (25 > 18)
    result2 = gb._evaluateConditions({ age: { "$lt": 30 } })      ' Should be TRUE (25 < 30)
    result3 = gb._evaluateConditions({ age: { "$gte": 25 } })     ' Should be TRUE (25 >= 25)
    result4 = gb._evaluateConditions({ age: { "$gt": 30 } })      ' Should be FALSE (25 > 30)
    
    ' Expected: TRUE, TRUE, TRUE, FALSE
    return "gt 18: " + Str(result1) + ", lt 30: " + Str(result2) + ", gte 25: " + Str(result3) + ", gt 30: " + Str(result4)
end function

' ================================================================
' Scenario 5: Advanced Targeting - $in operator
' ================================================================
function ScenarioTest_InOperator() as string
    ' Setup: User with country
    gb = GrowthBook({
        attributes: { country: "US" }
    })
    gb.init()
    
    ' Test: $in operator
    result1 = gb._evaluateConditions({ country: { "$in": ["US", "CA", "UK"] } })  ' TRUE
    result2 = gb._evaluateConditions({ country: { "$in": ["FR", "DE", "IT"] } })  ' FALSE
    result3 = gb._evaluateConditions({ country: { "$nin": ["FR", "DE"] } })       ' TRUE
    result4 = gb._evaluateConditions({ country: { "$nin": ["US", "CA"] } })       ' FALSE
    
    ' Expected: TRUE, FALSE, TRUE, FALSE
    return "in list: " + Str(result1) + ", not in list: " + Str(result2) + ", nin valid: " + Str(result3) + ", nin invalid: " + Str(result4)
end function

' ================================================================
' Scenario 6: Logical Operators - $and/$or
' ================================================================
function ScenarioTest_LogicalOperators() as string
    ' Setup: User with multiple attributes
    gb = GrowthBook({
        attributes: {
            country: "US",
            age: 25,
            isPremium: true
        }
    })
    gb.init()
    
    ' Test: $and operator
    condition1 = {
        "$and": [
            { country: "US" },
            { age: { "$gte": 18 } }
        ]
    }
    result1 = gb._evaluateConditions(condition1)  ' TRUE (both true)
    
    ' Test: $or operator
    condition2 = {
        "$or": [
            { country: "CA" },
            { isPremium: true }
        ]
    }
    result2 = gb._evaluateConditions(condition2)  ' TRUE (second is true)
    
    ' Test: $not operator
    condition3 = {
        "$not": { country: "CA" }
    }
    result3 = gb._evaluateConditions(condition3)  ' TRUE (not CA)
    
    ' Expected: TRUE, TRUE, TRUE
    return "and: " + Str(result1) + ", or: " + Str(result2) + ", not: " + Str(result3)
end function

' ================================================================
' Scenario 7: Nested Attributes
' ================================================================
function ScenarioTest_NestedAttributes() as string
    ' Setup: User with nested object
    gb = GrowthBook({
        attributes: {
            user: {
                profile: {
                    age: 30,
                    location: "NYC"
                }
            }
        }
    })
    gb.init()
    
    ' Test: Nested attribute access
    condition1 = { "user.profile.age": { "$gt": 25 } }
    condition2 = { "user.profile.location": "NYC" }
    condition3 = { "user.profile.age": { "$lt": 25 } }
    
    result1 = gb._evaluateConditions(condition1)  ' TRUE
    result2 = gb._evaluateConditions(condition2)  ' TRUE
    result3 = gb._evaluateConditions(condition3)  ' FALSE
    
    ' Expected: TRUE, TRUE, FALSE
    return "age>25: " + Str(result1) + ", location: " + Str(result2) + ", age<25: " + Str(result3)
end function

' ================================================================
' Scenario 8: Hash Consistency
' ================================================================
function ScenarioTest_HashConsistency() as string
    ' Setup: SDK instance
    gb = GrowthBook({})
    
    ' Test: Hash same value multiple times
    hash1 = gb._hashAttribute("user-123")
    hash2 = gb._hashAttribute("user-123")
    hash3 = gb._hashAttribute("user-456")
    
    ' Verify: Same input = same output, different input = different output
    sameHash = (hash1 = hash2)           ' Should be TRUE
    diffHash = (hash1 <> hash3)          ' Should be TRUE
    inRange = (hash1 >= 0 and hash1 < 100)  ' Should be TRUE
    
    ' Expected: TRUE, TRUE, TRUE
    return "consistent: " + Str(sameHash) + ", different: " + Str(diffHash) + ", inRange: " + Str(inRange)
end function

' ================================================================
' Scenario 9: Feature Evaluation Result
' ================================================================
function ScenarioTest_EvalFeatureResult() as string
    ' Setup: SDK with features
    gb = GrowthBook({
        features: {
            "test-feature": { defaultValue: "blue" },
            "missing-feature": invalid
        }
    })
    gb.init()
    
    ' Test: Evaluate features
    result1 = gb.evalFeature("test-feature")
    result2 = gb.evalFeature("missing-feature")
    
    ' Verify: Result structure
    hasKey1 = (result1.key = "test-feature")
    hasValue1 = (result1.value = "blue")
    hasSource1 = (result1.source = "defaultValue")
    
    hasKey2 = (result2.key = "missing-feature")
    hasSource2 = (result2.source = "unknownFeature")
    
    ' Expected: All TRUE
    return "key1: " + Str(hasKey1) + ", val1: " + Str(hasValue1) + ", src1: " + Str(hasSource1) + ", key2: " + Str(hasKey2) + ", src2: " + Str(hasSource2)
end function

' ================================================================
' Scenario 10: Complete User Journey
' ================================================================
function ScenarioTest_CompleteUserJourney() as string
    ' Simulate a complete user session
    
    ' 1. Initialize SDK
    gb = GrowthBook({
        features: {
            "new-checkout": { defaultValue: true },
            "premium-badge": { defaultValue: false }
        },
        attributes: {
            userId: "user-789",
            country: "US"
        }
    })
    gb.init()
    
    ' 2. Check if new checkout is enabled
    hasNewCheckout = gb.isOn("new-checkout")
    
    ' 3. Get configuration values
    buttonColor = gb.getFeatureValue("button-color", "#0066CC")
    
    ' 4. Update user attributes (user upgrades to premium)
    gb.setAttributes({
        userId: "user-789",
        country: "US",
        isPremium: true
    })
    
    ' 5. Check premium features
    condition = { isPremium: true }
    canSeePremium = gb._evaluateConditions(condition)
    
    ' Expected: All should work correctly
    return "checkout: " + Str(hasNewCheckout) + ", color: " + buttonColor + ", premium: " + Str(canSeePremium)
end function

' ================================================================
' Run All Scenarios (for manual inspection)
' ================================================================
function RunAllScenarios() as object
    results = {}
    
    results["1_BasicFeatureFlag"] = ScenarioTest_BasicFeatureFlag()
    results["2_FeatureValues"] = ScenarioTest_FeatureValues()
    results["3_SimpleTargeting"] = ScenarioTest_SimpleTargeting()
    results["4_NumericComparison"] = ScenarioTest_NumericComparison()
    results["5_InOperator"] = ScenarioTest_InOperator()
    results["6_LogicalOperators"] = ScenarioTest_LogicalOperators()
    results["7_NestedAttributes"] = ScenarioTest_NestedAttributes()
    results["8_HashConsistency"] = ScenarioTest_HashConsistency()
    results["9_EvalFeatureResult"] = ScenarioTest_EvalFeatureResult()
    results["10_CompleteUserJourney"] = ScenarioTest_CompleteUserJourney()
    
    return results
end function
