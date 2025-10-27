'
' Test Utilities for GrowthBook Test Suite
' Helper functions for BDD-style testing
'

' Deep equality comparison for objects
function deepEqual(a as dynamic, b as dynamic) as boolean
    aType = type(a)
    bType = type(b)
    
    ' Type mismatch
    if aType <> bType then return false
    
    ' Null/invalid
    if a = invalid and b = invalid then return true
    if a = invalid or b = invalid then return false
    
    ' Primitives
    if aType = "roString" or aType = "roInteger" or aType = "roFloat" or aType = "roBoolean"
        return a = b
    end if
    
    ' Arrays
    if aType = "roArray"
        if a.Count() <> b.Count() then return false
        for i = 0 to a.Count() - 1
            if not deepEqual(a[i], b[i]) then return false
        end for
        return true
    end if
    
    ' Objects
    if aType = "roAssociativeArray"
        ' Check all keys in a exist in b
        for each key in a
            if not b.DoesExist(key) then return false
            if not deepEqual(a[key], b[key]) then return false
        end for
        ' Check all keys in b exist in a
        for each key in b
            if not a.DoesExist(key) then return false
        end for
        return true
    end if
    
    ' Default: use built-in equality
    return a = b
end function

' Create GrowthBook instance from SDK config (used in feature tests)
function createGBFromSDKConfig(sdkConfig as object) as object
    config = {}
    
    if sdkConfig.DoesExist("attributes")
        config.attributes = sdkConfig.attributes
    end if
    
    if sdkConfig.DoesExist("features")
        config.features = sdkConfig.features
    end if
    
    if sdkConfig.DoesExist("forcedVariations")
        config.forcedVariations = sdkConfig.forcedVariations
    end if
    
    if sdkConfig.DoesExist("qaMode")
        config.qaMode = sdkConfig.qaMode
    end if
    
    if sdkConfig.DoesExist("url")
        config.url = sdkConfig.url
    end if
    
    if sdkConfig.DoesExist("enabled")
        config.enabled = sdkConfig.enabled
    end if
    
    if sdkConfig.DoesExist("savedGroups")
        config.savedGroups = sdkConfig.savedGroups
    end if
    
    gb = GrowthBook(config)
    gb.init()
    
    return gb
end function

' Format test name for display
function formatTestName(category as string, name as string) as string
    return category + " - " + name
end function

' Assert that experimentResult matches expected values
function assertExperimentResult(actual as object, expected as object, testName as string) as string
    if expected = invalid
        if actual <> invalid
            return "FAIL: " + testName + " - Expected invalid experimentResult, got: " + formatJson(actual)
        end if
        return "PASS"
    end if
    
    ' Check each expected field
    for each key in expected
        if not actual.DoesExist(key)
            return "FAIL: " + testName + " - Missing field: " + key
        end if
        
        if not deepEqual(actual[key], expected[key])
            return "FAIL: " + testName + " - Field '" + key + "' mismatch. Expected: " + formatValue(expected[key]) + ", Got: " + formatValue(actual[key])
        end if
    end for
    
    return "PASS"
end function

' Format value for display
function formatValue(value as dynamic) as string
    valueType = type(value)
    
    if value = invalid
        return "invalid"
    end if
    
    if valueType = "roString"
        return """" + value + """"
    end if
    
    if valueType = "roInteger" or valueType = "roFloat"
        return Str(value)
    end if
    
    if valueType = "roBoolean"
        if value then return "true" else return "false"
    end if
    
    if valueType = "roArray"
        return "[Array:" + Str(value.Count()) + "]"
    end if
    
    if valueType = "roAssociativeArray"
        return "{Object}"
    end if
    
    return valueType
end function

' Simple JSON formatter for debugging
function formatJson(obj as dynamic) as string
    return formatValue(obj)
end function

