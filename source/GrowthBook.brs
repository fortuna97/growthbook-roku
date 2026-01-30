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
        onFeatureUsage: invalid
        enableDevMode: false
        
        ' Internal state
        features: {}
        cachedFeatures: {}
        savedGroups: {}
        _evaluationStack: []
        _trackedExperiments: {}
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
        _fnv1a32: GrowthBook__fnv1a32
        _gbhash: GrowthBook__gbhash
        _paddedVersionString: GrowthBook__paddedVersionString
        _isIncludedInRollout: GrowthBook__isIncludedInRollout
        _getBucketRanges: GrowthBook__getBucketRanges
        _chooseVariation: GrowthBook__chooseVariation
        _inRange: GrowthBook__inRange
        _deepEqual: GrowthBook__deepEqual
        _trackExperiment: GrowthBook__trackExperiment
        _trackFeatureUsage: GrowthBook__trackFeatureUsage
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
        if config.onFeatureUsage <> invalid
            instance.onFeatureUsage = config.onFeatureUsage
        end if
        if config.enableDevMode <> invalid
            instance.enableDevMode = config.enableDevMode
        end if
        if config.features <> invalid
            instance.cachedFeatures = config.features
            instance.isInitialized = true
        end if
        if config.savedGroups <> invalid
            instance.savedGroups = config.savedGroups
        end if
    end if
    
    ' Configure HTTP transfer
    instance.http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    instance.http.AddHeader("Content-Type", "application/json")
    instance.http.AddHeader("User-Agent", "GrowthBook-Roku/1.3.0")
    
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
' Load features from GrowthBook API (async, non-blocking)
' ===================================================================
function GrowthBook__loadFeaturesFromAPI() as boolean
    apiUrl = this.apiHost + "/api/features/" + this.clientKey
    
    this._log("Loading features from: " + apiUrl)
    
    ' Setup async request with message port
    port = CreateObject("roMessagePort")
    this.http.SetMessagePort(port)
    this.http.SetUrl(apiUrl)
    
    ' Start async request
    if not this.http.AsyncGetToString()
        this._log("ERROR: Failed to start async request")
        return false
    end if
    
    ' Wait for response (10 second timeout)
    msg = Wait(10000, port)
    if msg = invalid
        this._log("ERROR: Request timed out")
        this.http.AsyncCancel()
        return false
    end if
    
    ' Handle response
    if type(msg) = "roUrlEvent"
        responseCode = msg.GetResponseCode()
        if responseCode <> 200
            this._log("ERROR: HTTP " + Str(responseCode).Trim())
            return false
        end if
        response = msg.GetString()
    else
        this._log("ERROR: Unexpected response type")
        return false
    end if
    
    if response = ""
        this._log("ERROR: Empty response")
        return false
    end if
    
    ' Parse response
    features = this._parseFeatures(response)
    
    if features <> invalid
        this.features = features
        this.cachedFeatures = features
        this.lastUpdate = GetTickCount()
        this.isInitialized = true
        this._log("Features loaded successfully: " + Str(features.Count()).Trim() + " features")
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
    
    ' Use Roku's built-in JSON parsing
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
    
    this._log("ERROR: Failed to parse features JSON")
    
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
    
    ' Check for cyclic prerequisites
    for each stackKey in this._evaluationStack
        if stackKey = key
            result.source = "cyclicPrerequisite"
            this._trackFeatureUsage(key, result)
            return result
        end if
    end for
    this._evaluationStack.Push(key)
    
    if this.features = invalid or this.features.Count() = 0
        result.source = "unknownFeature"
        this._evaluationStack.Pop()
        this._trackFeatureUsage(key, result)
        return result
    end if
    
    feature = this.features[key]
    if feature = invalid
        result.source = "unknownFeature"
        this._evaluationStack.Pop()
        this._trackFeatureUsage(key, result)
        return result
    end if
    
    ' Handle feature object
    if type(feature) = "roAssociativeArray"
        ' Check if feature matches targeting rules
        if feature.rules <> invalid
            for each rule in feature.rules
                if type(rule) = "roAssociativeArray"
                    ' Check parent conditions (prerequisites)
                    if rule.parentConditions <> invalid
                        for each parent in rule.parentConditions
                            parentResult = this.evalFeature(parent.id)
                            ' Propagate cyclic prerequisite
                            if parentResult.source = "cyclicPrerequisite"
                                result.source = "cyclicPrerequisite"
                                this._evaluationStack.Pop()
                                this._trackFeatureUsage(key, result)
                                return result
                            end if
                            ' Check gate
                            if parent.gate = true and not parentResult.on
                                result.source = "prerequisite"
                                this._evaluationStack.Pop()
                                this._trackFeatureUsage(key, result)
                                return result
                            end if
                            ' Check condition
                            if parent.condition <> invalid
                                tempGB = GrowthBook({ attributes: { value: parentResult.value }, savedGroups: this.savedGroups })
                                if not tempGB._evaluateConditions(parent.condition)
                                    result.source = "prerequisite"
                                    this._evaluationStack.Pop()
                                    this._trackFeatureUsage(key, result)
                                    return result
                                end if
                            end if
                        end for
                    end if
                    
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
                        
                        this._evaluationStack.Pop()
                        this._trackFeatureUsage(key, result)
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
            this._evaluationStack.Pop()
            this._trackFeatureUsage(key, result)
            return result
        end if
    else
        ' Simple value
        result.value = feature
        result.on = CBool(feature)
        result.off = not result.on
        result.source = "unknownFeature"
    end if
    
    this._evaluationStack.Pop()
    this._trackFeatureUsage(key, result)
    return result
end function

' ===================================================================
' Evaluate experiment variations
' ===================================================================
function GrowthBook__evaluateExperiment(rule as object, result as object) as object
    if rule.variations = invalid or rule.variations.Count() = 0
        return result
    end if
    
    ' Get hash attribute (default to "id")
    hashAttribute = "id"
    if rule.hashAttribute <> invalid and rule.hashAttribute <> ""
        hashAttribute = rule.hashAttribute
    end if
    
    ' Get the attribute value to hash
    hashValue = this._getAttributeValue(hashAttribute)
    if hashValue = invalid or hashValue = ""
        hashValue = "anonymous"
    end if
    
    ' Convert to string if needed
    if type(hashValue) <> "roString"
        hashValue = Str(hashValue).Trim()
    end if
    
    ' Get seed (defaults to experiment key or empty string)
    seed = ""
    if rule.seed <> invalid and rule.seed <> ""
        seed = rule.seed
    else if rule.key <> invalid
        seed = rule.key
    end if
    
    ' Get hash version (default to 1)
    hashVersion = 1
    if rule.hashVersion <> invalid
        hashVersion = rule.hashVersion
    end if
    
    ' Get coverage (defaults to 1.0 = 100%)
    coverage = 1.0
    if rule.coverage <> invalid
        coverage = rule.coverage
    end if
    
    ' Calculate hash with seed (returns 0-1)
    n = this._gbhash(seed, hashValue, hashVersion)
    if n = invalid
        return result
    end if
    
    ' Get weights from rule level
    weights = rule.weights
    
    ' Get bucket ranges using coverage and weights
    ranges = this._getBucketRanges(rule.variations.Count(), coverage, weights)
    this._log("Bucket ranges calculated (coverage=" + Str(coverage).Trim() + ")")
    
    ' Choose variation based on hash and bucket ranges
    variationIndex = this._chooseVariation(n, ranges)
    this._log("Variation selected: " + Str(variationIndex).Trim() + " (hash=" + Str(n).Trim() + ")")
    
    ' If no variation found (user outside buckets), return default
    if variationIndex < 0
        return result
    end if
    
    ' User is assigned to a variation
    result.value = rule.variations[variationIndex]
    result.on = CBool(rule.variations[variationIndex])
    result.off = not result.on
    result.variationId = variationIndex
    result.source = "experiment"
    
    if rule.key <> invalid
        result.experimentId = rule.key
    end if
    
    ' Track the experiment if callback is set
    this._trackExperiment(rule, result)
    
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
    
    ' Process all conditions - ALL must pass (AND logic at top level)
    for each attr in condition
        ' Handle logical operators
        if attr = "$or"
            if type(condition.$or) <> "roArray"
                continue for
            end if
            if condition.$or.Count() = 0
                continue for
            end if
            orPassed = false
            for each subcond in condition.$or
                if this._evaluateConditions(subcond)
                    orPassed = true
                    exit for
                end if
            end for
            if not orPassed
                return false
            end if
            continue for
        end if
        
        if attr = "$nor"
            if type(condition.$nor) <> "roArray"
                continue for
            end if
            for each subcond in condition.$nor
                if this._evaluateConditions(subcond)
                    return false
                end if
            end for
            continue for
        end if
        
        if attr = "$and"
            if type(condition.$and) <> "roArray"
                continue for
            end if
            if condition.$and.Count() = 0
                continue for
            end if
            for each subcond in condition.$and
                if not this._evaluateConditions(subcond)
                    return false
                end if
            end for
            continue for
        end if
        
        if attr = "$not"
            if this._evaluateConditions(condition.$not)
                return false
            end if
            continue for
        end if
        
        ' Handle attribute conditions
        
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
            if condition_value.$veq <> invalid
                ' Version equals
                v1 = this._paddedVersionString(value)
                v2 = this._paddedVersionString(condition_value.$veq)
                if v1 <> v2
                    return false
                end if
            end if
            if condition_value.$vne <> invalid
                ' Version not equals
                v1 = this._paddedVersionString(value)
                v2 = this._paddedVersionString(condition_value.$vne)
                if v1 = v2
                    return false
                end if
            end if
            if condition_value.$vlt <> invalid
                ' Version less than
                v1 = this._paddedVersionString(value)
                v2 = this._paddedVersionString(condition_value.$vlt)
                if not (v1 < v2)
                    return false
                end if
            end if
            if condition_value.$vlte <> invalid
                ' Version less than or equal
                v1 = this._paddedVersionString(value)
                v2 = this._paddedVersionString(condition_value.$vlte)
                if not (v1 <= v2)
                    return false
                end if
            end if
            if condition_value.$vgt <> invalid
                ' Version greater than
                v1 = this._paddedVersionString(value)
                v2 = this._paddedVersionString(condition_value.$vgt)
                if not (v1 > v2)
                    return false
                end if
            end if
            if condition_value.$vgte <> invalid
                ' Version greater than or equal
                v1 = this._paddedVersionString(value)
                v2 = this._paddedVersionString(condition_value.$vgte)
                if not (v1 >= v2)
                    return false
                end if
            end if
            if condition_value.$in <> invalid
                found = false
                ' Check if value is an array (array intersection)
                if type(value) = "roArray"
                    ' Array intersection: check if any element in value matches any in $in
                    for each userVal in value
                        for each condVal in condition_value.$in
                            if userVal = condVal
                                found = true
                                exit for
                            end if
                        end for
                        if found then exit for
                    end for
                else
                    ' Single value: check if it exists in $in array
                    for each v in condition_value.$in
                        if value = v
                            found = true
                            exit for
                        end if
                    end for
                end if
                if not found
                    return false
                end if
            end if
            if condition_value.$nin <> invalid
                found = false
                ' Check if value is an array (array intersection)
                if type(value) = "roArray"
                    ' Array intersection: check if any element in value matches any in $nin
                    for each userVal in value
                        for each condVal in condition_value.$nin
                            if userVal = condVal
                                found = true
                                exit for
                            end if
                        end for
                        if found then exit for
                    end for
                else
                    ' Single value: check if it exists in $nin array
                    for each v in condition_value.$nin
                        if value = v
                            found = true
                            exit for
                        end if
                    end for
                end if
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
                ' Create temp instance once outside loop for performance
                tempGB = GrowthBook({ attributes: {}, savedGroups: this.savedGroups })
                for each item in value
                    if type(condition_value.$elemMatch) = "roAssociativeArray"
                        ' Update attributes (reuse instance) and prepare condition
                        if type(item) = "roAssociativeArray"
                            tempGB.attributes = item
                            tempCond = condition_value.$elemMatch
                        else
                            tempGB.attributes = { "_": item }
                            tempCond = { "_": condition_value.$elemMatch }
                        end if
                        if tempGB._evaluateConditions(tempCond)
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
            if condition_value.$inGroup <> invalid
                ' Check if value is in a saved group
                groupId = condition_value.$inGroup
                if type(groupId) <> "roString"
                    return false
                end if
                ' Get the saved group
                if this.savedGroups.DoesExist(groupId)
                    savedGroup = this.savedGroups[groupId]
                    if type(savedGroup) = "roArray"
                        ' Check if value is in the group
                        found = false
                        for each groupMember in savedGroup
                            if value = groupMember
                                found = true
                                exit for
                            end if
                        end for
                        if not found
                            return false
                        end if
                    else
                        return false
                    end if
                else
                    ' Group not found
                    return false
                end if
            end if
            if condition_value.$notInGroup <> invalid
                ' Check if value is NOT in a saved group
                groupId = condition_value.$notInGroup
                if type(groupId) <> "roString"
                    return false
                end if
                ' Get the saved group
                if this.savedGroups.DoesExist(groupId)
                    savedGroup = this.savedGroups[groupId]
                    if type(savedGroup) = "roArray"
                        ' Check if value is in the group
                        found = false
                        for each groupMember in savedGroup
                            if value = groupMember
                                found = true
                                exit for
                            end if
                        end for
                        if found
                            return false
                        end if
                    else
                        return false
                    end if
                else
                    ' Group not found - value is not in group, so passes $notInGroup
                    return true
                end if
            end if
            if condition_value.$not <> invalid
                ' Negation operator on attribute value
                tempGB = GrowthBook({ attributes: this.attributes, savedGroups: this.savedGroups })
                tempCondition = {}
                tempCondition[attr] = condition_value.$not
                if tempGB._evaluateConditions(tempCondition)
                    return false
                end if
            end if
            
            ' Check for unknown operators (operators starting with $)
            hasOperator = false
            for each key in condition_value
                if Left(key, 1) = "$"
                    ' Check if it's a known operator
                    knownOps = ["$eq", "$ne", "$lt", "$lte", "$gt", "$gte", "$veq", "$vne", "$vlt", "$vlte", "$vgt", "$vgte", "$in", "$nin", "$exists", "$type", "$regex", "$elemMatch", "$size", "$all", "$inGroup", "$notInGroup", "$not"]
                    isKnown = false
                    for each op in knownOps
                        if key = op
                            isKnown = true
                            exit for
                        end if
                    end for
                    if not isKnown
                        ' Unknown operator - fail the condition
                        return false
                    end if
                    hasOperator = true
                end if
            end for
            
            ' If no operators found, treat as direct equality
            if not hasOperator
                if not this._deepEqual(value, condition_value)
                    return false
                end if
            end if
        else
            ' Direct equality
            if not this._deepEqual(value, condition_value)
                return false
            end if
        end if
    end for
    
    return true
end function

' ===================================================================
' FNV-1a 32-bit hash algorithm
' Returns integer hash value
' ===================================================================
function GrowthBook__fnv1a32(str as string) as longinteger
    ' FNV-1a constants
    hval& = &h811C9DC5&  ' 2166136261 - offset basis
    prime& = &h01000193&  ' 16777619 - FNV prime
    
    ' Process each character
    for i = 0 to str.Len() - 1
        charCode = Asc(Mid(str, i + 1, 1))
        hval& = hval& xor charCode
        hval& = (hval& * prime&) and &hFFFFFFFF&  ' Keep 32-bit
    end for
    
    return hval&
end function

' ===================================================================
' GrowthBook hash function with seed and version support
' Supports v1 and v2 hash algorithms for consistent bucketing
' Returns value between 0 and 1
' ===================================================================
function GrowthBook__gbhash(seed as string, value as string, version as integer) as dynamic
    ' Convert to string if needed
    if type(value) <> "roString"
        value = Str(value).Trim()
    end if
    if type(seed) <> "roString"
        seed = ""
    end if
    
    if version = 2
        ' Version 2: fnv1a32(str(fnv1a32(seed + value)))
        combined = seed + value
        hash1& = this._fnv1a32(combined)
        hash2& = this._fnv1a32(Str(hash1&).Trim())
        return (hash2& mod 10000) / 10000.0
    else if version = 1
        ' Version 1: fnv1a32(value + seed)
        combined = value + seed
        hash1& = this._fnv1a32(combined)
        return (hash1& mod 1000) / 1000.0
    end if
    
    return invalid
end function


' ===================================================================
' Version string padding for semantic version comparison
' Enables comparisons like "2.0.0" > "1.9.9" and "1.0.0" > "1.0.0-beta"
' ===================================================================
function GrowthBook__paddedVersionString(input as dynamic) as string
    ' Convert to string if number
    if type(input) = "roInteger" or type(input) = "roFloat"
        input = Str(input).Trim()
    end if
    
    if type(input) <> "roString" or input = ""
        return "0"
    end if
    
    version = input
    
    ' Remove leading "v" if present
    if Left(version, 1) = "v" or Left(version, 1) = "V"
        version = Mid(version, 2)
    end if
    
    ' Remove build info after "+" (e.g., "1.2.3+build123" -> "1.2.3")
    plusPos = Instr(1, version, "+")
    if plusPos > 0
        version = Left(version, plusPos - 1)
    end if
    
    ' Split on "." and "-"
    parts = []
    current = ""
    
    for i = 0 to version.Len() - 1
        char = Mid(version, i + 1, 1)
        if char = "." or char = "-"
            if current <> ""
                parts.Push(current)
                current = ""
            end if
        else
            current = current + char
        end if
    end for
    
    if current <> "" then parts.Push(current)
    
    ' If exactly 3 parts (SemVer without pre-release), add "~"
    ' This makes "1.0.0" > "1.0.0-beta" since "~" is largest ASCII char
    if parts.Count() = 3
        parts.Push("~")
    end if
    
    ' Pad numeric parts with spaces (right-justify to 5 chars)
    result = ""
    for i = 0 to parts.Count() - 1
        part = parts[i]
        
        ' Check if part is numeric
        isNumeric = true
        if part.Len() = 0
            isNumeric = false
        else
            for j = 0 to part.Len() - 1
                charCode = Asc(Mid(part, j + 1, 1))
                if charCode < 48 or charCode > 57  ' Not 0-9
                    isNumeric = false
                    exit for
                end if
            end for
        end if
        
        ' Pad numeric parts with spaces
        if isNumeric
            while part.Len() < 5
                part = " " + part
            end while
        end if
        
        if i > 0 then result = result + "-"
        result = result + part
    end for
    
    return result
end function

' ===================================================================
' Check if user is included in rollout based on coverage
' Used for feature percentage rollouts (force rules with coverage)
' Note: Experiments use _getBucketRanges instead
' ===================================================================
function GrowthBook__isIncludedInRollout(seed as string, hashValue as string, hashVersion as integer, coverage as float) as boolean
    ' Coverage of 1 or more includes everyone
    if coverage >= 1.0 then return true
    
    ' Coverage of 0 or less excludes everyone
    if coverage <= 0.0 then return false
    
    ' Calculate hash for this user
    n = this._gbhash(seed, hashValue, hashVersion)
    if n = invalid then return false
    
    ' User is included if their hash is less than coverage
    return n <= coverage
end function

' ===================================================================
' Get bucket ranges for variation assignment
' Converts weights and coverage into [start, end) ranges
' ===================================================================
function GrowthBook__getBucketRanges(numVariations as integer, coverage as float, weights as object) as object
    ' Return empty ranges if no variations
    if numVariations < 1 then return []
    
    ' Clamp coverage to valid range [0, 1]
    if coverage < 0 then coverage = 0
    if coverage > 1 then coverage = 1
    
    ' Generate equal weights if not provided or invalid
    ' Equal weights = each variation gets 1/n of traffic
    if weights = invalid or weights.Count() = 0 or weights.Count() <> numVariations
        equalWeight = 1.0 / numVariations
        weights = []
        for i = 0 to numVariations - 1
            weights.Push(equalWeight)
        end for
    end if
    
    ' Validate weights sum (should be ~1.0)
    weightSum = 0
    for each w in weights
        weightSum = weightSum + w
    end for
    if weightSum < 0.99 or weightSum > 1.01
        equalWeight = 1.0 / numVariations
        weights = []
        for i = 0 to numVariations - 1
            weights.Push(equalWeight)
        end for
    end if
    
    ' Build bucket ranges as [start, end] arrays
    ranges = []
    cumulative = 0.0
    for each w in weights
        rangeStart = cumulative
        cumulative = cumulative + w
        ' Apply coverage: reduces each bucket by coverage percentage
        rangeEnd = rangeStart + coverage * w
        ranges.Push([rangeStart, rangeEnd])
    end for
    
    return ranges
end function

' ===================================================================
' Choose variation based on hash value and bucket ranges
' Returns variation index, or -1 if not in any bucket
' ===================================================================
function GrowthBook__chooseVariation(n as float, ranges as object) as integer
    for i = 0 to ranges.Count() - 1
        if this._inRange(n, ranges[i])
            return i
        end if
    end for
    return -1
end function

' ===================================================================
' Check if value is within a bucket range [start, end)
' Range is array: [0] = start, [1] = end
' ===================================================================
function GrowthBook__inRange(n as float, range as object) as boolean
    return n >= range[0] and n < range[1]
end function

' ===================================================================
' Deep equality check for values
' Handles null, primitives, arrays, and objects
' ===================================================================
function GrowthBook__deepEqual(val1 as dynamic, val2 as dynamic) as boolean
    ' Handle null/invalid
    if val1 = invalid and val2 = invalid
        return true
    end if
    if val1 = invalid or val2 = invalid
        return false
    end if
    
    ' Type must match
    type1 = type(val1)
    type2 = type(val2)
    if type1 <> type2
        return false
    end if
    
    ' Primitives
    if type1 = "roString" or type1 = "roInteger" or type1 = "roFloat" or type1 = "roBoolean" or type1 = "String" or type1 = "Integer" or type1 = "Boolean"
        return val1 = val2
    end if
    
    ' Arrays
    if type1 = "roArray"
        if val1.Count() <> val2.Count()
            return false
        end if
        for i = 0 to val1.Count() - 1
            if not this._deepEqual(val1[i], val2[i])
                return false
            end if
        end for
        return true
    end if
    
    ' Objects
    if type1 = "roAssociativeArray"
        ' Check if all keys in val1 exist in val2 with same values
        for each key in val1
            if not val2.DoesExist(key)
                return false
            end if
            if not this._deepEqual(val1[key], val2[key])
                return false
            end if
        end for
        ' Check if val2 has any extra keys
        for each key in val2
            if not val1.DoesExist(key)
                return false
            end if
        end for
        return true
    end if
    
    ' Default: use equality
    return val1 = val2
end function

' ===================================================================
' Track experiment exposure (with de-duplication)
' ===================================================================
function GrowthBook__trackExperiment(experiment as object, result as object) as void
    if this.trackingCallback = invalid
        return
    end if
    
    ' Build unique tracking key to prevent duplicate tracking
    hashAttribute = "id"
    if experiment.hashAttribute <> invalid then hashAttribute = experiment.hashAttribute
    hashValue = ""
    if this.attributes[hashAttribute] <> invalid
        attrValue = this.attributes[hashAttribute]
        if type(attrValue) = "roString" or type(attrValue) = "String"
            hashValue = attrValue
        else
            hashValue = Str(attrValue).Trim()
        end if
    end if
    experimentKey = ""
    if experiment.key <> invalid then experimentKey = experiment.key
    variationId = ""
    if result.variationId <> invalid
        if type(result.variationId) = "roString" or type(result.variationId) = "String"
            variationId = result.variationId
        else
            variationId = Str(result.variationId).Trim()
        end if
    end if
    
    trackingKey = hashAttribute + "|" + hashValue + "|" + experimentKey + "|" + variationId
    
    ' Skip if already tracked
    if this._trackedExperiments.DoesExist(trackingKey)
        return
    end if
    
    ' Mark as tracked
    this._trackedExperiments[trackingKey] = true
    
    ' Call the tracking callback
    this.trackingCallback(experiment, result)
end function

' ===================================================================
' Track feature usage (called on every feature evaluation)
' ===================================================================
function GrowthBook__trackFeatureUsage(featureKey as string, result as object) as void
    if this.onFeatureUsage = invalid
        return
    end if
    
    ' Call the feature usage callback
    this.onFeatureUsage(featureKey, result)
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
