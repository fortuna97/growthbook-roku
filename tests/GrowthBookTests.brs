'
' GrowthBook Roku SDK - Rooibos Test Suite
' Tests the actual BrightScript implementation using Rooibos framework
'
' Reference: https://github.com/georgejecook/rooibos
'

' @suite GrowthBook SDK Tests
' @SGNode GrowthBookTestSuite

function TestSuite__GrowthBook() as object
    m = BaseTestSuite()
    m.Name = "GrowthBookTestSuite"
    
    ' Add test cases
    m.addTest("testInitWithClientKey", testInitWithClientKey)
    m.addTest("testInitWithFeatures", testInitWithFeatures)
    m.addTest("testInitWithoutConfig", testInitWithoutConfig)
    m.addTest("testIsOnEnabled", testIsOnEnabled)
    m.addTest("testIsOnDisabled", testIsOnDisabled)
    m.addTest("testIsOnMissing", testIsOnMissing)
    m.addTest("testGetFeatureValue", testGetFeatureValue)
    m.addTest("testGetFeatureValueFallback", testGetFeatureValueFallback)
    m.addTest("testGetFeatureValueNumeric", testGetFeatureValueNumeric)
    m.addTest("testEvalFeatureStructure", testEvalFeatureStructure)
    m.addTest("testEvalFeatureDefaultValue", testEvalFeatureDefaultValue)
    m.addTest("testEvalFeatureUnknown", testEvalFeatureUnknown)
    m.addTest("testSetAttributes", testSetAttributes)
    m.addTest("testConditionEquality", testConditionEquality)
    m.addTest("testConditionGreaterThan", testConditionGreaterThan)
    m.addTest("testConditionIn", testConditionIn)
    m.addTest("testConditionOr", testConditionOr)
    m.addTest("testConditionAnd", testConditionAnd)
    m.addTest("testConditionNot", testConditionNot)
    m.addTest("testHashConsistency", testHashConsistency)
    m.addTest("testHashDifferent", testHashDifferent)
    m.addTest("testHashRange", testHashRange)
    
    return m
end function

' ================================================================
' Initialization Tests
' ================================================================

' @test Initialize with client key
' @params clientKey="sdk_test123"
function testInitWithClientKey() as string
    gb = GrowthBook({
        clientKey: "sdk_test123"
    })
    
    return m.assertEqual(gb.clientKey, "sdk_test123")
end function

' @test Initialize with features directly
function testInitWithFeatures() as string
    features = {
        "feature1": { defaultValue: true },
        "feature2": { defaultValue: "value2" }
    }
    
    gb = GrowthBook({ features: features })
    result = gb.init()
    
    m.assertTrue(result)
    return m.assertTrue(gb.isInitialized)
end function

' @test Initialize without configuration fails
function testInitWithoutConfig() as string
    gb = GrowthBook({})
    result = gb.init()
    
    return m.assertFalse(result)
end function

' ================================================================
' Feature Flag Tests
' ================================================================

' @test isOn returns true for enabled feature
function testIsOnEnabled() as string
    features = {
        "feature-enabled": { defaultValue: true }
    }
    
    gb = GrowthBook({ features: features })
    gb.init()
    result = gb.isOn("feature-enabled")
    
    return m.assertTrue(result)
end function

' @test isOn returns false for disabled feature
function testIsOnDisabled() as string
    features = {
        "feature-disabled": { defaultValue: false }
    }
    
    gb = GrowthBook({ features: features })
    gb.init()
    result = gb.isOn("feature-disabled")
    
    return m.assertFalse(result)
end function

' @test isOn returns false for missing feature
function testIsOnMissing() as string
    gb = GrowthBook({ features: {} })
    gb.init()
    result = gb.isOn("missing-feature")
    
    return m.assertFalse(result)
end function

' ================================================================
' Feature Value Tests
' ================================================================

' @test getFeatureValue returns feature value
function testGetFeatureValue() as string
    features = {
        "color": { defaultValue: "#FF0000" }
    }
    
    gb = GrowthBook({ features: features })
    gb.init()
    result = gb.getFeatureValue("color", "#000000")
    
    return m.assertEqual(result, "#FF0000")
end function

' @test getFeatureValue returns fallback for missing feature
function testGetFeatureValueFallback() as string
    gb = GrowthBook({ features: {} })
    gb.init()
    result = gb.getFeatureValue("missing", "fallback")
    
    return m.assertEqual(result, "fallback")
end function

' @test getFeatureValue handles numeric values
function testGetFeatureValueNumeric() as string
    features = {
        "max-items": { defaultValue: 42 }
    }
    
    gb = GrowthBook({ features: features })
    gb.init()
    result = gb.getFeatureValue("max-items", 10)
    
    return m.assertEqual(result, 42)
end function

' ================================================================
' Evaluation Tests
' ================================================================

' @test evalFeature returns correct structure
function testEvalFeatureStructure() as string
    features = {
        "test-feature": { defaultValue: true }
    }
    
    gb = GrowthBook({ features: features })
    gb.init()
    result = gb.evalFeature("test-feature")
    
    m.assertNotInvalid(result.key)
    m.assertNotInvalid(result.on)
    m.assertNotInvalid(result.off)
    m.assertNotInvalid(result.source)
    return m.assertNotInvalid(result.value)
end function

' @test evalFeature returns defaultValue source
function testEvalFeatureDefaultValue() as string
    features = {
        "test": { defaultValue: "value" }
    }
    
    gb = GrowthBook({ features: features })
    gb.init()
    result = gb.evalFeature("test")
    
    m.assertEqual(result.source, "defaultValue")
    return m.assertEqual(result.value, "value")
end function

' @test evalFeature returns unknownFeature for missing
function testEvalFeatureUnknown() as string
    gb = GrowthBook({ features: {} })
    gb.init()
    result = gb.evalFeature("missing")
    
    return m.assertEqual(result.source, "unknownFeature")
end function

' ================================================================
' Attribute Tests
' ================================================================

' @test setAttributes updates user attributes
function testSetAttributes() as string
    gb = GrowthBook({})
    gb.setAttributes({
        id: "user123",
        country: "US",
        premium: true
    })
    
    m.assertEqual(gb.attributes.id, "user123")
    m.assertEqual(gb.attributes.country, "US")
    return m.assertTrue(gb.attributes.premium)
end function

' ================================================================
' Condition Evaluation Tests
' ================================================================

' @test evaluateConditions handles equality
function testConditionEquality() as string
    gb = GrowthBook({
        attributes: { country: "US", tier: "premium" }
    })
    gb.init()
    
    condition1 = { country: "US" }
    result1 = gb._evaluateConditions(condition1)
    m.assertTrue(result1)
    
    condition2 = { country: "CA" }
    result2 = gb._evaluateConditions(condition2)
    return m.assertFalse(result2)
end function

' @test evaluateConditions handles $gt operator
function testConditionGreaterThan() as string
    gb = GrowthBook({
        attributes: { score: 100 }
    })
    gb.init()
    
    condition1 = { score: { "$gt": 50 } }
    result1 = gb._evaluateConditions(condition1)
    m.assertTrue(result1)
    
    condition2 = { score: { "$gt": 150 } }
    result2 = gb._evaluateConditions(condition2)
    return m.assertFalse(result2)
end function

' @test evaluateConditions handles $in operator
function testConditionIn() as string
    gb = GrowthBook({
        attributes: { country: "US" }
    })
    gb.init()
    
    condition1 = { country: { "$in": ["US", "CA", "MX"] } }
    result1 = gb._evaluateConditions(condition1)
    m.assertTrue(result1)
    
    condition2 = { country: { "$in": ["FR", "DE"] } }
    result2 = gb._evaluateConditions(condition2)
    return m.assertFalse(result2)
end function

' @test evaluateConditions handles $or operator
function testConditionOr() as string
    gb = GrowthBook({
        attributes: { country: "US", tier: "basic" }
    })
    gb.init()
    
    condition = {
        "$or": [
            { tier: "premium" },
            { country: "US" }
        ]
    }
    result = gb._evaluateConditions(condition)
    
    return m.assertTrue(result)
end function

' @test evaluateConditions handles $and operator
function testConditionAnd() as string
    gb = GrowthBook({
        attributes: { country: "US", tier: "premium" }
    })
    gb.init()
    
    condition1 = {
        "$and": [
            { country: "US" },
            { tier: "premium" }
        ]
    }
    result1 = gb._evaluateConditions(condition1)
    m.assertTrue(result1)
    
    condition2 = {
        "$and": [
            { country: "US" },
            { tier: "basic" }
        ]
    }
    result2 = gb._evaluateConditions(condition2)
    return m.assertFalse(result2)
end function

' @test evaluateConditions handles $not operator
function testConditionNot() as string
    gb = GrowthBook({
        attributes: { country: "US" }
    })
    gb.init()
    
    condition1 = { "$not": { country: "CA" } }
    result1 = gb._evaluateConditions(condition1)
    m.assertTrue(result1)
    
    condition2 = { "$not": { country: "US" } }
    result2 = gb._evaluateConditions(condition2)
    return m.assertFalse(result2)
end function

' ================================================================
' Hashing Tests
' ================================================================

' @test hashAttribute returns consistent hash
function testHashConsistency() as string
    gb = GrowthBook({})
    
    hash1 = gb._hashAttribute("user123")
    hash2 = gb._hashAttribute("user123")
    
    return m.assertEqual(hash1, hash2)
end function

' @test hashAttribute returns different values for different inputs
function testHashDifferent() as string
    gb = GrowthBook({})
    
    hash1 = gb._hashAttribute("user123")
    hash2 = gb._hashAttribute("user456")
    
    return m.assertNotEqual(hash1, hash2)
end function

' @test hashAttribute returns value in 0-99 range
function testHashRange() as string
    gb = GrowthBook({})
    
    for i = 0 to 9
        hash = gb._hashAttribute("user" + Str(i))
        m.assertTrue(hash >= 0)
        m.assertTrue(hash < 100)
    end for
    
    return "pass"
end function

