'
' GrowthBook SDK for Roku
' Official implementation for GrowthBook feature flags and A/B testing
' https://www.growthbook.io
'

' ===================================================================
' GrowthBook - Main class
' ===================================================================
function GrowthBook(config as object) as object
    instance = {
        ' Configuration
        apiHost: "https://cdn.growthbook.io"
        clientKey: ""
        decryptionKey: ""
        attributes: {}
        trackingCallback: invalid
        enableDevMode: false
        
        ' Internal state
        features: {}
        experiments: {}
        cachedFeatures: {}
        lastUpdate: 0
        isInitialized: false
        
        ' Network utilities
        http: CreateObject("roURLTransfer")
        
        ' Methods
        init: GrowthBook_init
        setAttributes: GrowthBook_setAttributes
        isOn: GrowthBook_isOn
        getFeatureValue: GrowthBook_getFeatureValue
        evalFeature: GrowthBook_evalFeature
        _loadFeaturesFromAPI: GrowthBook__loadFeaturesFromAPI
        _parseFeatures: GrowthBook__parseFeatures
        _evaluateConditions: GrowthBook__evaluateConditions
        _getAttributeValue: GrowthBook__getAttributeValue
        _hash: GrowthBook__hash
        _hashAttribute: GrowthBook__hashAttribute
        _trackExperiment: GrowthBook__trackExperiment
        _log: GrowthBook__log
    }
    
    ' Apply config
    if type(config) = "roAssociativeArray"
        if config.apiHost <> invalid
            instance.apiHost = config.apiHost
        end if
        if config.clientKey <> invalid
            instance.clientKey = config.clientKey
        end if
        if config.decryptionKey <> invalid
            instance.decryptionKey = config.decryptionKey
        end if
        if config.attributes <> invalid
            instance.attributes = config.attributes
        end if
        if config.trackingCallback <> invalid
            instance.trackingCallback = config.trackingCallback
        end if
        if config.enableDevMode <> invalid
            instance.enableDevMode = config.enableDevMode
        end if
        if config.features <> invalid
            instance.cachedFeatures = config.features
            instance.isInitialized = true
        end if
    end if
    
    ' Configure HTTP transfer
    instance.http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    instance.http.AddHeader("Content-Type", "application/json")
    instance.http.AddHeader("User-Agent", "GrowthBook-Roku/1.0.0")
    
    return instance
end function

' ===================================================================
' Initialization - Load features from API or use provided features
' ===================================================================
function GrowthBook_init() as boolean
    if this.clientKey = "" and this.cachedFeatures.Count() = 0
        this._log("ERROR: clientKey is required or pass features directly")
        return false
    end if
    
    ' If we already have cached features, we're done
    if this.cachedFeatures.Count() > 0
        this.features = this.cachedFeatures
        this.isInitialized = true
        this._log("Features loaded from cache")
        return true
    end if
    
    ' Try to load from API
    if this.clientKey <> ""
        return this._loadFeaturesFromAPI()
    end if
    
    return false
end function

' ===================================================================
' Load features from GrowthBook API
' ===================================================================
function GrowthBook__loadFeaturesFromAPI() as boolean
    apiUrl = this.apiHost + "/api/features/" + this.clientKey
    
    this._log("Loading features from: " + apiUrl)
    
    this.http.SetUrl(apiUrl)
    this.http.SetTimeout(10)
    
    ' Make the request
    response = this.http.GetToString()
    
    if response = ""
        this._log("ERROR: Network request failed")
        return false
    end if
    
    ' Parse response
    features = this._parseFeatures(response)
    
    if features <> invalid
        this.features = features
        this.cachedFeatures = features
        this.lastUpdate = GetTickCount()
        this.isInitialized = true
        this._log("Features loaded successfully: " + Str(features.Count()) + " features")
        return true
    end if
    
    return false
end function

' ===================================================================
' Parse features from JSON response
' ===================================================================
function GrowthBook__parseFeatures(json as string) as object
    if json = ""
        return invalid
    end if
    
    ' Simple JSON parser for feature response
    ' GrowthBook API returns: { "features": { "key": {...}, ... } }
    
    try
        ' Use Roku's built-in JSON parsing if available
        root = ParseJson(json)
        
        if root <> invalid and root.features <> invalid
            this.features = root.features
            return root.features
        end if
        
        ' Fallback: assume the response is already features object
        features = ParseJson(json)
        if features <> invalid
            this.features = features
            return features
        end if
    catch err
        this._log("ERROR: Failed to parse features JSON - " + err.message)
    end try
    
    return invalid
end function

' ===================================================================
' Check if a feature is enabled (boolean flag)
' ===================================================================
function GrowthBook_isOn(key as string) as boolean
    if this.features = invalid or this.features.Count() = 0
        return false
    end if
    
    feature = this.features[key]
    if feature = invalid
        return false
    end if
    
    ' If feature has defaultValue, it's a boolean feature
    if type(feature) = "roAssociativeArray"
        if feature.defaultValue <> invalid
            return CBool(feature.defaultValue)
        end if
        ' If no defaultValue, check if it's enabled through experiment
        if feature.enabled = invalid
            return false
        end if
        return CBool(feature.enabled)
    end if
    
    ' Direct value - coerce to boolean
    return CBool(feature)
end function

' ===================================================================
' Get feature value with fallback
' ===================================================================
function GrowthBook_getFeatureValue(key as string, fallback as dynamic) as dynamic
    if this.features = invalid or this.features.Count() = 0
        return fallback
    end if
    
    feature = this.features[key]
    if feature = invalid
        return fallback
    end if
    
    ' If feature is an object with defaultValue
    if type(feature) = "roAssociativeArray"
        if feature.defaultValue <> invalid
            return feature.defaultValue
        end if
    end if
    
    ' Return feature value directly if it's not an object
    if type(feature) <> "roAssociativeArray"
        return feature
    end if
    
    return fallback
end function

' ===================================================================
' Evaluate a feature - returns full evaluation result
' ===================================================================
function GrowthBook_evalFeature(key as string) as object
    result = {
        key: key
        value: invalid
        on: false
        off: true
        source: "unknownFeature"
        ruleId: ""
        experimentId: ""
        variationId: invalid
    }
    
    if this.features = invalid or this.features.Count() = 0
        result.source = "unknownFeature"
        return result
    end if
    
    feature = this.features[key]
    if feature = invalid
        result.source = "unknownFeature"
        return result
    end if
    
    ' Handle feature object
    if type(feature) = "roAssociativeArray"
        ' Check if feature matches targeting rules
        if feature.rules <> invalid
            for each rule in feature.rules
                if type(rule) = "roAssociativeArray"
                    if this._evaluateConditions(rule.condition)
                        result.value = rule.value
                        result.on = CBool(rule.value)
                        result.off = not result.on
                        result.ruleId = rule.ruleId
                        result.source = "force"
                        
                        ' Handle experiment
                        if rule.variations <> invalid
                            result = this._evaluateExperiment(rule, result)
                        end if
                        
                        return result
                    end if
                end if
            end for
        end if
        
        ' Use default value
        if feature.defaultValue <> invalid
            result.value = feature.defaultValue
            result.on = CBool(feature.defaultValue)
            result.off = not result.on
            result.source = "defaultValue"
            return result
        end if
    else
        ' Simple value
        result.value = feature
        result.on = CBool(feature)
        result.off = not result.on
        result.source = "unknownFeature"
    end if
    
    return result
end function

' ===================================================================
' Evaluate experiment variations
' ===================================================================
function GrowthBook__evaluateExperiment(rule as object, result as object) as object
    if rule.variations = invalid or rule.variations.Count() = 0
        return result
    end if
    
    ' Get namespace for experiment isolation
    namespace = invalid
    if rule.namespace <> invalid
        namespace = rule.namespace
    end if
    
    ' Hash the user for consistent variation assignment
    userId = this.attributes.id
    if userId = invalid
        userId = "anonymous"
    end if
    
    ' Calculate bucket
    bucketKey = userId
    if namespace <> invalid and type(namespace) = "roAssociativeArray"
        if namespace.name <> invalid and namespace.value <> invalid
            bucketKey = userId + "__" + namespace.name + "__" + namespace.value
        end if
    end if
    
    hash = this._hashAttribute(bucketKey)
    
    ' Allocate to variation based on hash
    weights = []
    for each variation in rule.variations
        if type(variation) = "roAssociativeArray" and variation.weights <> invalid
            weights.Push(variation.weights)
        else
            weights.Push(1.0 / rule.variations.Count())
        end if
    end for
    
    ' Determine bucket position (0-1)
    bucket = (hash mod 100) / 100.0
    
    ' Find variation
    cumulative = 0
    for i = 0 to rule.variations.Count() - 1
        cumulative = cumulative + weights[i]
        if bucket <= cumulative
            result.value = rule.variations[i]
            result.on = CBool(rule.variations[i])
            result.off = not result.on
            result.variationId = i
            result.source = "experiment"
            
            if rule.key <> invalid
                result.experimentId = rule.key
            end if
            
            ' Track the experiment if callback is set
            this._trackExperiment(rule, result)
            
            return result
        end if
    end for
    
    return result
end function

' ===================================================================
' Set user attributes for targeting and experiments
' ===================================================================
function GrowthBook_setAttributes(attrs as object) as void
    if type(attrs) = "roAssociativeArray"
        this.attributes = attrs
        this._log("Attributes updated")
    end if
end function

' ===================================================================
' Get attribute value (supports nested paths like "user.age")
' ===================================================================
function GrowthBook__getAttributeValue(attr as string) as dynamic
    ' Check for nested path (e.g., "father.age")
    if Instr(1, attr, ".") > 0
        parts = attr.Split(".")
        value = this.attributes
        
        for each part in parts
            if type(value) = "roAssociativeArray" and value.DoesExist(part)
                value = value[part]
            else
                return invalid
            end if
        end for
        
        return value
    end if
    
    ' Simple attribute
    if this.attributes.DoesExist(attr)
        return this.attributes[attr]
    end if
    
    return invalid
end function

' ===================================================================
' Evaluate conditions (rules) against user attributes
' ===================================================================
function GrowthBook__evaluateConditions(condition as object) as boolean
    if condition = invalid
        return true
    end if
    
    if type(condition) <> "roAssociativeArray"
        return false
    end if
    
    ' Empty condition always passes
    if condition.Count() = 0
        return true
    end if
    
    ' Logical operators
    if condition.DoesExist("$or")
        if type(condition.$or) <> "roArray"
            return true
        end if
        if condition.$or.Count() = 0
            return true
        end if
        for each subcond in condition.$or
            if this._evaluateConditions(subcond)
                return true
            end if
        end for
        return false
    end if
    
    if condition.DoesExist("$nor")
        if type(condition.$nor) <> "roArray"
            return true
        end if
        for each subcond in condition.$nor
            if this._evaluateConditions(subcond)
                return false
            end if
        end for
        return true
    end if
    
    if condition.DoesExist("$and")
        if type(condition.$and) <> "roArray"
            return true
        end if
        if condition.$and.Count() = 0
            return true
        end if
        for each subcond in condition.$and
            if not this._evaluateConditions(subcond)
                return false
            end if
        end for
        return true
    end if
    
    if condition.DoesExist("$not")
        return not this._evaluateConditions(condition.$not)
    end if
    
    ' Attribute conditions
    for each attr in condition
        ' Skip logical operators at this level
        if attr = "$or" or attr = "$and" or attr = "$not" or attr = "$nor"
            continue for
        end if
        
        value = this._getAttributeValue(attr)
        condition_value = condition[attr]
        
        if type(condition_value) = "roAssociativeArray"
            ' Operator conditions
            if condition_value.$eq <> invalid
                if value <> condition_value.$eq
                    return false
                end if
            end if
            if condition_value.$ne <> invalid
                if value = condition_value.$ne
                    return false
                end if
            end if
            if condition_value.$lt <> invalid
                ' Only compare if value exists
                if value = invalid or not (value < condition_value.$lt)
                    return false
                end if
            end if
            if condition_value.$lte <> invalid
                if value = invalid or not (value <= condition_value.$lte)
                    return false
                end if
            end if
            if condition_value.$gt <> invalid
                if value = invalid or not (value > condition_value.$gt)
                    return false
                end if
            end if
            if condition_value.$gte <> invalid
                if value = invalid or not (value >= condition_value.$gte)
                    return false
                end if
            end if
            if condition_value.$in <> invalid
                found = false
                for each v in condition_value.$in
                    if value = v
                        found = true
                        exit for
                    end if
                end for
                if not found
                    return false
                end if
            end if
            if condition_value.$nin <> invalid
                found = false
                for each v in condition_value.$nin
                    if value = v
                        found = true
                        exit for
                    end if
                end for
                if found
                    return false
                end if
            end if
            if condition_value.$type <> invalid
                ' Check if actual type matches expected type
                expectedType = condition_value.$type
                actualType = type(value)
                
                ' Map BrightScript types to JSON types
                jsonType = ""
                if actualType = "roString" then jsonType = "string"
                if actualType = "roInteger" or actualType = "roFloat" then jsonType = "number"
                if actualType = "roBoolean" then jsonType = "boolean"
                if actualType = "roArray" then jsonType = "array"
                if actualType = "roAssociativeArray" then jsonType = "object"
                if actualType = "Invalid" or value = invalid then jsonType = "null"
                
                if jsonType <> expectedType
                    return false
                end if
            end if
            if condition_value.$exists <> invalid
                ' Check if attribute exists
                shouldExist = CBool(condition_value.$exists)
                exists = (value <> invalid)
                if exists <> shouldExist
                    return false
                end if
            end if
            if condition_value.$regex <> invalid
                ' Regex matching
                if value = invalid or type(value) <> "roString"
                    return false
                end if
                ' Use CreateObject("roRegex") for pattern matching
                regex = CreateObject("roRegex", condition_value.$regex, "i")
                if regex = invalid or not regex.IsMatch(value)
                    return false
                end if
            end if
            if condition_value.$elemMatch <> invalid
                ' Array element matching
                if value = invalid or type(value) <> "roArray"
                    return false
                end if
                found = false
                for each item in value
                    ' Check if this item matches the condition
                    if type(condition_value.$elemMatch) = "roAssociativeArray"
                        ' Create temporary GB instance to evaluate nested condition
                        tempAttrs = { "_item": item }
                        tempCondition = {}
                        for each key in condition_value.$elemMatch
                            tempCondition["_item"] = {}
                            tempCondition["_item"][key] = condition_value.$elemMatch[key]
                        end for
                        ' Simplified check for single value
                        if this._evaluateConditions(tempCondition)
                            found = true
                            exit for
                        end if
                    end if
                end for
                if not found
                    return false
                end if
            end if
            if condition_value.$size <> invalid
                ' Array size check
                if value = invalid or type(value) <> "roArray"
                    return false
                end if
                expectedSize = condition_value.$size
                if type(expectedSize) = "roInteger"
                    if value.Count() <> expectedSize
                        return false
                    end if
                else if type(expectedSize) = "roAssociativeArray"
                    ' Nested size condition
                    actualSize = value.Count()
                    sizeCondition = { "_size": actualSize }
                    ' Recurse with size as attribute
                    if not this._evaluateConditions(expectedSize)
                        return false
                    end if
                end if
            end if
            if condition_value.$all <> invalid
                ' All elements must be present
                if value = invalid or type(value) <> "roArray"
                    return false
                end if
                if type(condition_value.$all) <> "roArray"
                    return false
                end if
                for each required in condition_value.$all
                    found = false
                    for each item in value
                        if item = required
                            found = true
                            exit for
                        end if
                    end for
                    if not found
                        return false
                    end if
                end for
            end if
        else
            ' Direct equality
            if value <> condition_value
                return false
            end if
        end if
    end for
    
    return true
end function

' ===================================================================
' Hash function with seed and version support (for experiments)
' Returns value between 0 and 1
' ===================================================================
function GrowthBook__hash(value as string, version as integer) as float
    ' Convert value to string if needed
    if type(value) <> "roString"
        value = Str(value)
    end if
    
    ' FNV-1a 32-bit hash algorithm
    prime = 16777619&
    offsetBasis = 2166136261&
    
    ' Initialize hash
    hash& = offsetBasis
    
    ' Process each character
    for i = 0 to value.Len() - 1
        charCode = Asc(Mid(value, i + 1, 1))
        hash& = hash& xor charCode
        hash& = (hash& * prime) and &hFFFFFFFF& ' 32-bit mask
    end for
    
    ' Convert to float between 0 and 1
    ' Use modulo to get consistent distribution
    if version = 2
        ' Version 2: Different distribution
        result = (hash& mod 10000) / 10000.0
    else
        ' Version 1: Original distribution
        result = (hash& mod 1000) / 1000.0
    end if
    
    return result
end function

' ===================================================================
' Hash attribute for consistent variation assignment - FNV32a v2
' ===================================================================
function GrowthBook__hashAttribute(value as string) as integer
    ' FNV-1a 32-bit hash algorithm (v2)
    ' Matches JS SDK implementation for consistent user bucketing
    ' Used by: https://github.com/growthbook/growthbook/tree/main/packages/sdk-js
    
    ' Convert to string if needed
    if type(value) <> "roString"
        value = Str(value)
    end if
    
    ' FNV-1a constants
    prime = 16777619&
    offsetBasis = 2166136261&
    
    ' Initialize hash
    hash& = offsetBasis
    
    ' Process each character
    for i = 0 to value.Len() - 1
        charCode = Asc(Mid(value, i + 1, 1))
        hash& = hash& xor charCode
        
        ' Multiply by prime and ensure 32-bit overflow
        hash& = (hash& * prime) and &hFFFFFFFF&
    end for
    
    ' Return 0-99 range for bucket allocation
    return (hash& mod 100)
end function

' ===================================================================
' Track experiment exposure
' ===================================================================
function GrowthBook__trackExperiment(experiment as object, result as object) as void
    if this.trackingCallback = invalid
        return
    end if
    
    ' Call the tracking callback
    this.trackingCallback(experiment, result)
end function

' ===================================================================
' Logging utility
' ===================================================================
function GrowthBook__log(message as string) as void
    if this.enableDevMode
        print "[GrowthBook] " + message
    end if
end function

' ===================================================================
' Utility Functions
' ===================================================================

function CBool(value as dynamic) as boolean
    if type(value) = "roBoolean"
        return value
    end if
    
    if type(value) = "roString"
        return (value.ToLower() = "true" or value = "1")
    end if
    
    if type(value) = "roInteger"
        return value <> 0
    end if
    
    if type(value) = "roFloat"
        return value <> 0.0
    end if
    
    return false
end function
