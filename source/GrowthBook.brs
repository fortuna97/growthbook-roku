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
        apiHost: "https://cdn.growthbook.io",
        clientKey: "",
        decryptionKey: "",
        attributes: {},
        trackingCallback: invalid,
        onFeatureUsage: invalid,
        enableDevMode: false,
        forcedVariations: {},
        
        ' Internal state
        features: {},
        cachedFeatures: {},
        savedGroups: {},
        _evaluationStack: [],
        _trackedExperiments: {},
        trackingPlugins: [],
        stickyBucketService: invalid,
        _stickyBucketAssignmentDocs: {},
        lastUpdate: 0,
        isInitialized: false,
        
        ' Network utilities
        http: invalid,
        
        ' Methods
        init: GrowthBook_init,
        setAttributes: GrowthBook_setAttributes,
        isOn: GrowthBook_isOn,
        getFeatureValue: GrowthBook_getFeatureValue,
        evalFeature: GrowthBook_evalFeature,
        refreshFeatures: GrowthBook_refreshFeatures,
        _loadFeaturesFromAPI: GrowthBook__loadFeaturesFromAPI,
        _parseFeatures: GrowthBook__parseFeatures,
        _evaluateConditions: GrowthBook__evaluateConditions,
        _getAttributeValue: GrowthBook__getAttributeValue,
        _fnv1a32: GrowthBook__fnv1a32,
        _gbhash: GrowthBook__gbhash,
        _paddedVersionString: GrowthBook__paddedVersionString,
        _isIncludedInRollout: GrowthBook__isIncludedInRollout,
        _getBucketRanges: GrowthBook__getBucketRanges,
        _chooseVariation: GrowthBook__chooseVariation,
        _inRange: GrowthBook__inRange,
        _deepEqual: GrowthBook__deepEqual,
        _compare: GrowthBook__compare,
        _trackExperiment: GrowthBook__trackExperiment,
        _trackFeatureUsage: GrowthBook__trackFeatureUsage,
        _evaluateExperiment: GrowthBook__evaluateExperiment,
        _inNamespace: GrowthBook__inNamespace,
        _getHashContext: GrowthBook__getHashContext,
        _isRuleIncluded: GrowthBook__isRuleIncluded,
        _log: GrowthBook__log,
        _hashAttribute: GrowthBook__hashAttribute,
        _decrypt: GrowthBook__decrypt,
        _notifyPlugins: GrowthBook__notifyPlugins,
        _getStickyBucketExperimentKey: GrowthBook__getStickyBucketExperimentKey,
        _getStickyBucketVariation: GrowthBook__getStickyBucketVariation,
        _saveStickyBucketAssignment: GrowthBook__saveStickyBucketAssignment,
        
        ' Public API
        registerTrackingPlugin: GrowthBook_registerTrackingPlugin,
        
        ' Helpers (exposed for internal use)
        toBoolean: GrowthBook_toBoolean
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
        if config.forcedVariations <> invalid
            instance.forcedVariations = config.forcedVariations
        end if
        if config.trackingPlugins <> invalid
            instance.trackingPlugins = config.trackingPlugins
        end if
        if config.stickyBucketService <> invalid
            instance.stickyBucketService = config.stickyBucketService
        end if
        if config.stickyBucketAssignmentDocs <> invalid
            instance._stickyBucketAssignmentDocs = config.stickyBucketAssignmentDocs
        end if
    end if
    
    ' Configure HTTP transfer
    if config.http <> invalid
        instance.http = config.http
    else
        ' Try to create real roURLTransfer safely
        ' In some headless environments (like brs), this might throw or fail
        try
            instance.http = CreateObject("roURLTransfer")
        catch e
            instance.http = invalid
        end try
    end if
    
    if instance.http <> invalid and type(instance.http) = "roURLTransfer"
        instance.http.SetCertificatesFile("common:/certs/ca-bundle.crt")
        instance.http.AddHeader("Content-Type", "application/json")
        instance.http.AddHeader("User-Agent", "GrowthBook-Roku/2.0.0")
    end if
    
    return instance
end function

' ===================================================================
' Initialization - Load features from API or use provided features
' ===================================================================
function GrowthBook_init() as boolean
    if m.clientKey = "" and m.cachedFeatures.Count() = 0
        m._log("ERROR: clientKey is required or pass features directly")
        return false
    end if
    
    ' If we already have cached features, we're done
    if m.cachedFeatures.Count() > 0
        m.features = m.cachedFeatures
        m.isInitialized = true
        m._log("Features loaded from cache")
        return true
    end if
    
    ' Try to load from API
    if m.clientKey <> ""
        return m._loadFeaturesFromAPI()
    end if
    
    return false
end function

' ===================================================================
' Load features from GrowthBook API (async, non-blocking)
' ===================================================================
function GrowthBook__loadFeaturesFromAPI() as boolean
    apiUrl = m.apiHost + "/api/features/" + m.clientKey
    
    m._log("Loading features from: " + apiUrl)
    
    ' Setup async request with message port
    port = CreateObject("roMessagePort")
    m.http.SetMessagePort(port)
    m.http.SetUrl(apiUrl)
    
    ' Start async request
    if not m.http.AsyncGetToString()
        m._log("ERROR: Failed to start async request")
        return false
    end if
    
    ' Wait for response (10 second timeout)
    msg = Wait(10000, port)
    if msg = invalid
        m._log("ERROR: Request timed out")
        m.http.AsyncCancel()
        return false
    end if
    
    ' Handle response
    if type(msg) = "roUrlEvent"
        responseCode = msg.GetResponseCode()
        if responseCode <> 200
            m._log("ERROR: HTTP " + Str(responseCode).Trim())
            return false
        end if
        response = msg.GetString()
    else
        m._log("ERROR: Unexpected response type")
        return false
    end if
    
    if response = ""
        m._log("ERROR: Empty response")
        return false
    end if
    
    ' Parse response
    features = m._parseFeatures(response)
    
    if features <> invalid
        m.features = features
        m.cachedFeatures = features
        m.lastUpdate = CreateObject("roDateTime").AsSeconds()
        m.isInitialized = true
        m._log("Features loaded successfully: " + Str(features.Count()).Trim() + " features")
        return true
    end if
    
    return false
end function

' ===================================================================
' Parse features from JSON response (supports encrypted payloads)
' ===================================================================
function GrowthBook__parseFeatures(json as string) as object
    if json = ""
        return invalid
    end if
    
    ' Use Roku's built-in JSON parsing
    root = ParseJson(json)
    
    if root = invalid
        m._log("ERROR: Failed to parse features JSON")
        return invalid
    end if
    
    ' Check for encrypted features
    if root.encryptedFeatures <> invalid and root.encryptedFeatures <> ""
        if m.decryptionKey <> invalid and m.decryptionKey <> ""
            decrypted = m._decrypt(root.encryptedFeatures, m.decryptionKey)
            if decrypted <> ""
                decryptedFeatures = ParseJson(decrypted)
                if decryptedFeatures <> invalid
                    m.features = decryptedFeatures
                else
                    m._log("ERROR: Failed to parse decrypted features")
                    return invalid
                end if
            else
                m._log("ERROR: Failed to decrypt encryptedFeatures")
                return invalid
            end if
        else
            m._log("ERROR: encryptedFeatures present but no decryptionKey provided")
            return invalid
        end if
    end if

    ' Handle encrypted saved groups
    if root.encryptedSavedGroups <> invalid and root.encryptedSavedGroups <> "" and m.decryptionKey <> invalid and m.decryptionKey <> ""
        decrypted = m._decrypt(root.encryptedSavedGroups, m.decryptionKey)
        if decrypted <> ""
            decryptedGroups = ParseJson(decrypted)
            if decryptedGroups <> invalid
                m.savedGroups = decryptedGroups
            end if
        end if
    end if

    ' Handle saved groups from response (only if not encrypted)
    if root.encryptedSavedGroups = invalid and root.savedGroups <> invalid
        m.savedGroups = root.savedGroups
    end if
    
    ' Handle unencrypted features (only if not encrypted)
    if root.encryptedFeatures = invalid and root.features <> invalid
        m.features = root.features
        return m.features
    end if

    ' If we processed encryptedFeatures successfully, return them (even if empty)
    if root.encryptedFeatures <> invalid and root.encryptedFeatures <> ""
        return m.features
    end if
    
    ' Fallback: assume the response is already features object
    m.features = root
    return root
end function

' ===================================================================
' Check if a feature is enabled (boolean flag)
' ===================================================================
function GrowthBook_isOn(key as string) as boolean
    if m.features = invalid or m.features.Count() = 0
        return false
    end if
    
    feature = m.features[key]
    if feature = invalid
        return false
    end if
    
    ' If feature has defaultValue, it's a boolean feature
    if type(feature) = "roAssociativeArray"
        if feature.defaultValue <> invalid
            return GrowthBook_toBoolean(feature.defaultValue)
        end if
        ' If no defaultValue, check if it's enabled through experiment
        if feature.enabled = invalid
            return false
        end if
        return GrowthBook_toBoolean(feature.enabled)
    end if
    
    ' Direct value - coerce to boolean
    return GrowthBook_toBoolean(feature)
end function

' ===================================================================
' Get feature value with fallback
' ===================================================================
function GrowthBook_getFeatureValue(key as string, fallback as dynamic) as dynamic
    if m.features = invalid or m.features.Count() = 0
        return fallback
    end if
    
    feature = m.features[key]
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
        key: key,
        value: invalid,
        on: false,
        off: true,
        source: "unknownFeature",
        ruleId: "",
        experimentId: "",
        variationId: invalid
    }
    
    ' Check for cyclic prerequisites
    for each stackKey in m._evaluationStack
        if stackKey = key
            result.source = "cyclicPrerequisite"
            m._trackFeatureUsage(key, result)
            return result
        end if
    end for
    m._evaluationStack.Push(key)
    
    if m.features = invalid or m.features.Count() = 0
        result.source = "unknownFeature"
        m._evaluationStack.Pop()
        m._trackFeatureUsage(key, result)
        return result
    end if
    
    feature = m.features[key]
    if feature = invalid
        result.source = "unknownFeature"
        m._evaluationStack.Pop()
        m._trackFeatureUsage(key, result)
        return result
    end if
    
    result.source = "defaultValue"
    
    ' Handle feature object
    if type(feature) = "roAssociativeArray"
        if feature.rules <> invalid
            for each rule in feature.rules
                if type(rule) = "roAssociativeArray"
                    while true
                        ' 1. Prerequisites
                        if rule.parentConditions <> invalid
                            for each parent in rule.parentConditions
                                parentResult = m.evalFeature(parent.id)
                                if parentResult.source = "cyclicPrerequisite"
                                    result.source = "cyclicPrerequisite"
                                    m._evaluationStack.Pop()
                                    m._trackFeatureUsage(key, result)
                                    return result
                                end if
                                
                                gateFailed = (GrowthBook_toBoolean(parent.gate) and not parentResult.on)
                                conditionFailed = false
                                if parent.condition <> invalid
                                    tempGB = GrowthBook({ attributes: { value: parentResult.value }, savedGroups: m.savedGroups, http: m.http })
                                    if not tempGB._evaluateConditions(parent.condition) then conditionFailed = true
                                end if
                                
                                if gateFailed or conditionFailed
                                    result.source = "prerequisite"
                                    m._evaluationStack.Pop()
                                    m._trackFeatureUsage(key, result)
                                    return result
                                end if
                            end for
                        end if
                        
                        ' 2. Rule Condition
                        if not m._evaluateConditions(rule.condition) then exit while
                        
                        ' Namespace check
                        if rule.namespace <> invalid
                            hashAttribute = "id"
                            if rule.hashAttribute <> invalid and rule.hashAttribute <> "" then hashAttribute = rule.hashAttribute
                            hashValue = m._getAttributeValue(hashAttribute)
                            if hashValue = invalid then exit while
                            if type(hashValue) <> "roString" and type(hashValue) <> "String"
                                hashValue = Str(hashValue).Trim()
                            end if
                            if hashValue = "" then exit while
                            if not m._inNamespace(hashValue, rule.namespace) then exit while
                        end if
                        
                        ' 3. Force Rule
                        if rule.DoesExist("force")
                            ' Handle coverage/range/filters/hashVersion for force rules
                            if not m._isRuleIncluded(rule, key) then exit while
                            
                            result.value = rule.force
                            result.on = GrowthBook_toBoolean(rule.force)
                            result.off = not result.on
                            result.source = "force"
                            if rule.ruleId <> invalid 
                                result.ruleId = rule.ruleId
                            else if rule.id <> invalid
                                result.ruleId = rule.id
                            end if
                            m._evaluationStack.Pop()
                            m._trackFeatureUsage(key, result)
                            return result
                        end if
                        
                        ' 4. Experiment Rule
                        if rule.variations <> invalid
                            ' Forced Variations check
                            if m.forcedVariations <> invalid and m.forcedVariations[key] <> invalid
                                forcedIndex = m.forcedVariations[key]
                                if forcedIndex >= 0 and forcedIndex < rule.variations.Count()
                                    result.value = rule.variations[forcedIndex]
                                    result.on = GrowthBook_toBoolean(result.value)
                                    result.off = not result.on
                                    result.source = "experiment"
                                    if rule.ruleId <> invalid 
                                        result.ruleId = rule.ruleId
                                    else if rule.id <> invalid
                                        result.ruleId = rule.id
                                    end if
                                    m._evaluationStack.Pop()
                                    m._trackFeatureUsage(key, result)
                                    return result
                                end if
                            end if
                            
                            expResult = m._evaluateExperiment(rule, result)
                            if expResult.source = "experiment"
                                ' Check for passthrough meta
                                if rule.meta <> invalid and expResult.variationId <> invalid
                                    variationMeta = rule.meta[expResult.variationId]
                                    if variationMeta <> invalid and variationMeta.passthrough = true
                                        exit while
                                    end if
                                end if
                                m._evaluationStack.Pop()
                                m._trackFeatureUsage(key, expResult)
                                return expResult
                            end if
                        end if
                        
                        exit while
                    end while
                end if
            end for
        end if
        
        ' Use default value
        result.source = "defaultValue"
        if feature.defaultValue <> invalid
            result.value = feature.defaultValue
            result.on = GrowthBook_toBoolean(feature.defaultValue)
            result.off = not result.on
        end if
    else
        ' Simple value
        result.value = feature
        result.on = GrowthBook_toBoolean(feature)
        result.off = not result.on
        result.source = "unknownFeature"
    end if
    
    m._evaluationStack.Pop()
    m._trackFeatureUsage(key, result)
    return result
end function

' ===================================================================
' Evaluate experiment variations
' ===================================================================
function GrowthBook__evaluateExperiment(rule as object, result as object) as object
    if rule.variations = invalid or rule.variations.Count() = 0
        return result
    end if
    
    ' Get hashing context
    context = m._getHashContext(rule, result.key)
    if not context.success then return result
    
    ' Check for sticky bucket FIRST (before hash-based assignment)
    stickyResult = m._getStickyBucketVariation(rule, context, result.key)
    if stickyResult.versionIsBlocked
        m._log("Sticky bucket version blocked for experiment")
        return result
    end if
    
    variationIndex = -1
    stickyBucketUsed = false
    
    if stickyResult.variation >= 0
        ' Use sticky bucket assignment
        variationIndex = stickyResult.variation
        stickyBucketUsed = true
        m._log("Using sticky bucket: variation " + Str(variationIndex).Trim())
    else
        ' Normal hash-based assignment
        ' Get coverage (defaults to 1.0 = 100%)
        coverage = 1.0
        if rule.coverage <> invalid then coverage = rule.coverage
        
        ' Calculate hash with seed (returns 0-1)
        n = m._gbhash(context.seed, context.hashValue, context.hashVersion)
        if n = invalid then return result
        
        ' Use provided ranges if available, otherwise calculate from coverage/weights
        ranges = rule.ranges
        if ranges = invalid
            weights = rule.weights
            ranges = m._getBucketRanges(rule.variations.Count(), coverage, weights)
        end if
        
        ' Choose variation based on hash and bucket ranges
        variationIndex = m._chooseVariation(n, ranges)
        m._log("Variation selected: " + Str(variationIndex).Trim() + " (hash=" + Str(n).Trim() + ")")
    end if
    
    ' If no variation found (user outside buckets), return default
    if variationIndex < 0
        return result
    end if
    
    ' Save to sticky bucket (even if we used it, to ensure doc exists)
    m._saveStickyBucketAssignment(rule, context, variationIndex, result.key)
    
    ' User is assigned to a variation
    result.value = rule.variations[variationIndex]
    result.on = GrowthBook_toBoolean(rule.variations[variationIndex])
    result.off = not result.on
    result.variationId = variationIndex
    result.source = "experiment"
    result.stickyBucketUsed = stickyBucketUsed
    
    if rule.ruleId <> invalid 
        result.ruleId = rule.ruleId
    else if rule.id <> invalid
        result.ruleId = rule.id
    end if
    
    if rule.key <> invalid
        result.experimentId = rule.key
    end if
    
    ' Track the experiment if callback is set
    m._trackExperiment(rule, result)
    
    return result
end function

' ===================================================================
' Set user attributes for targeting and experiments
' ===================================================================
sub GrowthBook_setAttributes(attrs as object)
    if type(attrs) = "roAssociativeArray"
        m.attributes = attrs
        m._log("Attributes updated")
    end if
end sub

' ===================================================================
' Refresh features from the GrowthBook API
' Call this when you want to fetch updated features on-demand
' Note: BrightScript is single-threaded, so automatic polling is not possible
' ===================================================================
function GrowthBook_refreshFeatures() as boolean
    if m.clientKey = "" or m.clientKey = invalid
        m._log("ERROR: clientKey required for refresh")
        return false
    end if
    
    if m.http = invalid
        m._log("ERROR: HTTP not available")
        return false
    end if
    
    return m._loadFeaturesFromAPI()
end function

' ===================================================================
' Get attribute value (supports nested paths like "user.age")
' ===================================================================
function GrowthBook__getAttributeValue(attr as string) as dynamic
    ' Check for nested path (e.g., "father.age")
    if Instr(1, attr, ".") > 0
        parts = attr.Split(".")
        value = m.attributes
        
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
    if m.attributes.DoesExist(attr)
        return m.attributes[attr]
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
            if type(condition["$or"]) <> "roArray"
                continue for
            end if
            if condition["$or"].Count() = 0
                continue for
            end if
            orPassed = false
            for each subcond in condition["$or"]
                if m._evaluateConditions(subcond)
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
            if type(condition["$nor"]) <> "roArray"
                continue for
            end if
            for each subcond in condition["$nor"]
                if m._evaluateConditions(subcond)
                    return false
                end if
            end for
            continue for
        end if
        
        if attr = "$and"
            if type(condition["$and"]) <> "roArray"
                continue for
            end if
            if condition["$and"].Count() = 0
                continue for
            end if
            for each subcond in condition["$and"]
                if not m._evaluateConditions(subcond)
                    return false
                end if
            end for
            continue for
        end if
        
        if attr = "$not"
            if m._evaluateConditions(condition["$not"])
                return false
            end if
            continue for
        end if
        
        ' Handle attribute conditions
        
        value = m._getAttributeValue(attr)
        condition_value = condition[attr]
        
        if type(condition_value) = "roAssociativeArray"
            ' Operator conditions
            if condition_value["$eq"] <> invalid
                if value <> condition_value["$eq"]
                    return false
                end if
            end if
            if condition_value["$ne"] <> invalid
                if value = condition_value["$ne"]
                    return false
                end if
            end if
            if condition_value["$lt"] <> invalid
                if not m._compare(value, condition_value["$lt"], "$lt") then return false
            end if
            if condition_value["$lte"] <> invalid
                if not m._compare(value, condition_value["$lte"], "$lte") then return false
            end if
            if condition_value["$gt"] <> invalid
                if not m._compare(value, condition_value["$gt"], "$gt") then return false
            end if
            if condition_value["$gte"] <> invalid
                if not m._compare(value, condition_value["$gte"], "$gte") then return false
            end if
            if condition_value["$veq"] <> invalid
                ' Version equals
                v1 = m._paddedVersionString(value)
                v2 = m._paddedVersionString(condition_value["$veq"])
                if v1 <> v2
                    return false
                end if
            end if
            if condition_value["$vne"] <> invalid
                ' Version not equals
                v1 = m._paddedVersionString(value)
                v2 = m._paddedVersionString(condition_value["$vne"])
                if v1 = v2
                    return false
                end if
            end if
            if condition_value["$vlt"] <> invalid
                ' Version less than
                v1 = m._paddedVersionString(value)
                v2 = m._paddedVersionString(condition_value["$vlt"])
                if not (v1 < v2)
                    return false
                end if
            end if
            if condition_value["$vlte"] <> invalid
                ' Version less than or equal
                v1 = m._paddedVersionString(value)
                v2 = m._paddedVersionString(condition_value["$vlte"])
                if not (v1 <= v2)
                    return false
                end if
            end if
            if condition_value["$vgt"] <> invalid
                ' Version greater than
                v1 = m._paddedVersionString(value)
                v2 = m._paddedVersionString(condition_value["$vgt"])
                if not (v1 > v2)
                    return false
                end if
            end if
            if condition_value["$vgte"] <> invalid
                ' Version greater than or equal
                v1 = m._paddedVersionString(value)
                v2 = m._paddedVersionString(condition_value["$vgte"])
                if not (v1 >= v2)
                    return false
                end if
            end if
            if condition_value["$in"] <> invalid
                if type(condition_value["$in"]) <> "roArray" then return false
                found = false
                ' Check if value is an array (array intersection)
                if type(value) = "roArray"
                    ' Array intersection: check if any element in value matches any in _in
                    for each userVal in value
                        for each condVal in condition_value["$in"]
                            if userVal = condVal
                                found = true
                                exit for
                            end if
                        end for
                        if found then exit for
                    end for
                else
                    ' Single value: check if it exists in _in array
                    for each v in condition_value["$in"]
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
            if condition_value["$nin"] <> invalid
                if type(condition_value["$nin"]) <> "roArray" then return false
                found = false
                ' Check if value is an array (array intersection)
                if type(value) = "roArray"
                    ' Array intersection: check if any element in value matches any in _nin
                    for each userVal in value
                        for each condVal in condition_value["$nin"]
                            if userVal = condVal
                                found = true
                                exit for
                            end if
                        end for
                        if found then exit for
                    end for
                else
                    ' Single value: check if it exists in _nin array
                    for each v in condition_value["$nin"]
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
            if condition_value["$type"] <> invalid
                ' Check if actual type matches expected type
                expectedType = condition_value["$type"]
                actualType = type(value)
                
                ' Map BrightScript types to JSON types
                jsonType = ""
                if actualType = "roString" or actualType = "String" then jsonType = "string"
                if actualType = "roInteger" or actualType = "roFloat" or actualType = "Integer" or actualType = "Float" then jsonType = "number"
                if actualType = "roBoolean" or actualType = "Boolean" then jsonType = "boolean"
                if actualType = "roArray" then jsonType = "array"
                if actualType = "roAssociativeArray" then jsonType = "object"
                if actualType = "Invalid" or value = invalid then jsonType = "null"
                
                if jsonType <> expectedType
                    return false
                end if
            end if
            if condition_value["$exists"] <> invalid
                ' Check if attribute exists
                shouldExist = GrowthBook_toBoolean(condition_value["$exists"])
                exists = (value <> invalid)
                if exists <> shouldExist
                    return false
                end if
            end if
            if condition_value["$regex"] <> invalid
                ' Regex matching
                if value = invalid or (type(value) <> "roString" and type(value) <> "String")
                    return false
                end if
                pattern = condition_value["$regex"]
                if type(pattern) <> "roString" and type(pattern) <> "String"
                    return false
                end if
                ' Reject patterns with invalid quantifier sequences (crashes roRegex)
                firstChar = Left(pattern, 1)
                if firstChar = "?" or firstChar = "*" or firstChar = "+"
                    return false
                end if
                if Instr(1, pattern, "**") > 0 or Instr(1, pattern, "++") > 0 or Instr(1, pattern, "???") > 0
                    return false
                end if
                ' Use CreateObject("roRegex") for pattern matching
                try
                    regex = CreateObject("roRegex", pattern, "i")
                    if regex = invalid or not regex.IsMatch(value)
                        return false
                    end if
                catch e
                    ' Invalid regex pattern - fail the condition
                    return false
                end try
            end if
            if condition_value["$elemMatch"] <> invalid
                ' Array element matching
                if value = invalid or type(value) <> "roArray"
                    return false
                end if
                found = false
                ' Create temp instance once outside loop for performance
                tempGB = GrowthBook({ attributes: {}, savedGroups: m.savedGroups, http: {} })
                for each item in value
                    if type(condition_value["$elemMatch"]) = "roAssociativeArray"
                        ' Update attributes (reuse instance) and prepare condition
                        if type(item) = "roAssociativeArray"
                            tempGB.attributes = item
                            tempCond = condition_value["$elemMatch"]
                        else
                            tempGB.attributes = { "_": item }
                            tempCond = { "_": condition_value["$elemMatch"] }
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
            if condition_value["$size"] <> invalid
                if type(value) <> "roArray"
                    return false
                end if
                expectedSize = condition_value["$size"]
                actualSize = value.Count()
                if type(expectedSize) = "roAssociativeArray"
                    ' Nested size condition - create temp GB with size as attribute
                    tempGB = GrowthBook({ attributes: { "_size": actualSize }, http: {} })
                    if not tempGB._evaluateConditions({ "_size": expectedSize })
                        return false
                    end if
                else
                    ' Direct size comparison
                    if actualSize <> expectedSize
                        return false
                    end if
                end if
            end if
            if condition_value["$all"] <> invalid
                ' All elements must be present
                if value = invalid or type(value) <> "roArray"
                    return false
                end if
                if type(condition_value["$all"]) <> "roArray"
                    return false
                end if
                for each required in condition_value["$all"]
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
            if condition_value["$inGroup"] <> invalid
                ' Check if value is in a saved group
                groupId = condition_value["$inGroup"]
                if type(groupId) <> "roString" and type(groupId) <> "String"
                    return false
                end if
                ' Get the saved group
                if m.savedGroups.DoesExist(groupId)
                    savedGroup = m.savedGroups[groupId]
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
            if condition_value["$notInGroup"] <> invalid
                ' Check if value is NOT in a saved group
                groupId = condition_value["$notInGroup"]
                if type(groupId) <> "roString" and type(groupId) <> "String"
                    return false
                end if
                ' Get the saved group
                if m.savedGroups.DoesExist(groupId)
                    savedGroup = m.savedGroups[groupId]
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
                    ' Group not found - value is not in group, so passes _notInGroup
                    return true
                end if
            end if
            if condition_value["$not"] <> invalid
                ' Negation operator on attribute value
                tempGB = GrowthBook({ attributes: m.attributes, savedGroups: m.savedGroups, http: {} })
                tempCondition = {}
                tempCondition[attr] = condition_value["$not"]
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
                if not m._deepEqual(value, condition_value)
                    return false
                end if
            end if
        else
            ' Direct equality
            if not m._deepEqual(value, condition_value)
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
        ' Bitwise XOR implementation: (a AND NOT b) OR (NOT a AND b)
        temp1& = hval& AND (NOT charCode)
        temp2& = (NOT hval&) AND charCode
        hval& = temp1& OR temp2&
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
    if type(value) <> "roString" and type(value) <> "String"
        value = Str(value).Trim()
    end if
    if type(seed) <> "roString" and type(seed) <> "String"
        seed = ""
    end if
    
    if version = 2
        ' Version 2: fnv1a32(str(fnv1a32(seed + value)))
        combined = seed + value
        hash1& = m._fnv1a32(combined)
        hash2& = m._fnv1a32(Str(hash1&).Trim())
        return (hash2& mod 10000) / 10000.0
    else if version = 1
        ' Version 1: fnv1a32(value + seed)
        combined = value + seed
        hash1& = m._fnv1a32(combined)
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
    
    if (type(input) <> "roString" and type(input) <> "String") or input = ""
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
    n = m._gbhash(seed, hashValue, hashVersion)
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
        if m._inRange(n, ranges[i])
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
' Comparison helper with type coercion
' ===================================================================
function GrowthBook__compare(v1 as dynamic, v2 as dynamic, op as string) as boolean
    ' Handle invalid
    if v1 = invalid then v1 = 0
    
    t1 = type(v1)
    t2 = type(v2)
    
    ' Coerce strings to numbers if types differ and one is already a number
    isNumeric1 = (t1 = "roInteger" or t1 = "Integer" or t1 = "roFloat" or t1 = "Float" or t1 = "Double" or t1 = "LongInteger")
    isNumeric2 = (t2 = "roInteger" or t2 = "Integer" or t2 = "roFloat" or t2 = "Float" or t2 = "Double" or t2 = "LongInteger")
    
    if t1 <> t2
        if isNumeric1 and (t2 = "roString" or t2 = "String")
            v2 = Val(v2)
        else if isNumeric2 and (t1 = "roString" or t1 = "String")
            v1 = Val(v1)
        end if
    end if
    
    if op = "$lt" then return v1 < v2
    if op = "$lte" then return v1 <= v2
    if op = "$gt" then return v1 > v2
    if op = "$gte" then return v1 >= v2
    
    return false
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
            if not m._deepEqual(val1[i], val2[i])
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
            if not m._deepEqual(val1[key], val2[key])
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
sub GrowthBook__trackExperiment(experiment as object, result as object)
    ' Build unique tracking key to prevent duplicate tracking
    hashAttribute = "id"
    if experiment.hashAttribute <> invalid then hashAttribute = experiment.hashAttribute
    hashValue = ""
    if m.attributes[hashAttribute] <> invalid
        attrValue = m.attributes[hashAttribute]
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
    
    ' Skip if already tracked (applies to both callback and plugins)
    if m._trackedExperiments.DoesExist(trackingKey)
        return
    end if
    
    ' Mark as tracked
    m._trackedExperiments[trackingKey] = true
    
    ' Call the tracking callback if set
    if m.trackingCallback <> invalid
        m.trackingCallback(experiment, result)
    end if
    
    ' Notify tracking plugins
    m._notifyPlugins("experimentViewed", { experiment: experiment, result: result })
end sub

' ===================================================================
' Check if user is in a namespace
' ===================================================================
function GrowthBook__inNamespace(userId as string, namespace as object) as boolean
    if namespace = invalid or type(namespace) <> "roArray" or namespace.Count() <> 3
        return true
    end if
    
    n = m._gbhash(namespace[0], userId, 1)
    if n = invalid then return false
    
    return n >= namespace[1] and n < namespace[2]
end function

' ===================================================================
' Track feature usage (called on every feature evaluation)
' ===================================================================
sub GrowthBook__trackFeatureUsage(featureKey as string, result as object)
    ' Call the feature usage callback if set
    if m.onFeatureUsage <> invalid
        m.onFeatureUsage(featureKey, result)
    end if
    
    ' Notify tracking plugins
    m._notifyPlugins("featureUsage", { featureKey: featureKey, result: result })
end sub

' ===================================================================
' Notify tracking plugins of events
' ===================================================================
sub GrowthBook__notifyPlugins(eventType as string, data as object)
    for each plugin in m.trackingPlugins
        if eventType = "experimentViewed" and plugin.onExperimentViewed <> invalid
            plugin.onExperimentViewed(data.experiment, data.result)
        else if eventType = "featureUsage" and plugin.onFeatureUsage <> invalid
            plugin.onFeatureUsage(data.featureKey, data.result)
        end if
    end for
end sub

' ===================================================================
' Register a tracking plugin for event notifications
' ===================================================================
sub GrowthBook_registerTrackingPlugin(plugin as object)
    if type(plugin) = "roAssociativeArray"
        m.trackingPlugins.Push(plugin)
        ' Initialize plugin if it has an init method
        if plugin.init <> invalid
            plugin.init(m)
        end if
    end if
end sub

' ===================================================================
' Logging utility
' ===================================================================
sub GrowthBook__log(message as string)
    if m.enableDevMode
        print "[GrowthBook] " + message
    end if
end sub

' ===================================================================
' Hash attribute for testing (simplified version)
' ===================================================================
function GrowthBook__hashAttribute(value as string) as integer
    ' Simple hash for testing - returns 0-99
    hash = m._gbhash("", value, 1)
    if hash = invalid then return 0
    return Int(hash * 100)
end function

' ===================================================================
' Get Hash Context (helper for filters and experiments)
' Supports fallbackAttribute for sticky bucketing prerequisites
' ===================================================================
function GrowthBook__getHashContext(rule as object, featureKey as string) as object
    ' Get hash attribute (default to "id")
    ' Get hash value from attributes
    ' Get hash version (default to 1)
    ' Get seed (default to feature key)
    context = {
        hashAttribute: "id",
        hashValue: "",
        hashVersion: 1,
        seed: featureKey,
        success: false
    }
    
    if rule = invalid return context
    
    ' 1. Hash Attribute
    if rule.hashAttribute <> invalid and rule.hashAttribute <> ""
        context.hashAttribute = rule.hashAttribute
    end if
    
    ' 2. Hash Value - try primary attribute first
    val = m._getAttributeValue(context.hashAttribute)
    if val <> invalid
        if type(val) = "roString" or type(val) = "String"
            context.hashValue = val
        else
            context.hashValue = Str(val).Trim()
        end if
    end if
    
    ' 2b. FALLBACK - if primary value empty, try fallbackAttribute
    ' This is used for sticky bucketing when the primary hash attribute is not available
    if context.hashValue = "" and rule.fallbackAttribute <> invalid and rule.fallbackAttribute <> ""
        val = m._getAttributeValue(rule.fallbackAttribute)
        if val <> invalid
            if type(val) = "roString" or type(val) = "String"
                context.hashValue = val
            else
                context.hashValue = Str(val).Trim()
            end if
            ' Only update hashAttribute if we successfully got a fallback value
            if context.hashValue <> ""
                context.hashAttribute = rule.fallbackAttribute
            end if
        end if
    end if
    
    if context.hashValue = "" return context
    
    ' 3. Hash Version
    if rule.hashVersion <> invalid
        context.hashVersion = rule.hashVersion
    end if
    
    ' 4. Seed
    if rule.seed <> invalid and rule.seed <> ""
        context.seed = rule.seed
    else if rule.key <> invalid
        context.seed = rule.key
    end if
    
    context.success = true
    return context
end function

' ===================================================================
' Check if a rule is included based on filters/rollout
' ===================================================================
function GrowthBook__isRuleIncluded(rule as object, featureKey as string) as boolean
    ' If no hashing logic needed, it's included
    if rule.coverage = invalid and rule.range = invalid and rule.filters = invalid and (rule.hashVersion = invalid or rule.hashVersion = 1)
        return true
    end if
    
    context = m._getHashContext(rule, featureKey)
    if not context.success return false
    
    ' 1. Filters
    if rule.filters <> invalid
        for each filter in rule.filters
            filterSeed = featureKey
            if filter.seed <> invalid then filterSeed = filter.seed
            n = m._gbhash(filterSeed, context.hashValue, context.hashVersion)
            if n = invalid return false
            
            inAnyRange = false
            for each rng in filter.ranges
                if m._inRange(n, rng)
                    inAnyRange = true
                    exit for
                end if
            end for
            if not inAnyRange return false
        end for
    else
        ' 2. Standard Rollout/Range
        n = m._gbhash(context.seed, context.hashValue, context.hashVersion)
        if n = invalid return false
        
        if rule.coverage <> invalid and rule.coverage = 0 return false
        
        if rule.range <> invalid
            if not m._inRange(n, rule.range) return false
        else if rule.coverage <> invalid
            if n > rule.coverage return false
        end if
    end if
    
    return true
end function

' ===================================================================
' Utility Functions
' ===================================================================

function GrowthBook_toBoolean(value as dynamic) as boolean
    if value = invalid
        return false
    end if
    
    if type(value) = "roBoolean" or type(value) = "Boolean"
        return value
    end if
    
    if type(value) = "roString" or type(value) = "String"
        return value <> ""
    end if
    
    if type(value) = "roInteger" or type(value) = "Integer" or type(value) = "LongInteger"
        return value <> 0
    end if
    
    if type(value) = "roFloat" or type(value) = "Float" or type(value) = "Double"
        return value <> 0.0
    end if
    
    ' Other objects (AA, Array) are truthy
    return true
end function

' ===================================================================
' AES-128-CBC Decryption for Encrypted Feature Payloads
' Requires Roku OS 9.2+ for roEVPCipher support
' ===================================================================
function GrowthBook__decrypt(encryptedStr as string, keyStr as string) as string
    ' Validate inputs
    if encryptedStr = "" or keyStr = "" then return ""
    
    ' Format: "base64(iv).base64(ciphertext)"
    dotIndex = Instr(1, encryptedStr, ".")
    if dotIndex = 0 or dotIndex = 1 then return ""
    
    ivStr = Left(encryptedStr, dotIndex - 1)
    ctStr = Mid(encryptedStr, dotIndex + 1)
    if ivStr = "" or ctStr = "" then return ""
    
    ' Base64 decode all components
    keyBytes = CreateObject("roByteArray")
    ivBytes = CreateObject("roByteArray")
    ctBytes = CreateObject("roByteArray")
    
    ' Decode key - FromBase64String may silently fail on invalid input
    keyBytes.FromBase64String(keyStr)
    if keyBytes.Count() = 0
        m._log("ERROR: Invalid or empty base64 key")
        return ""
    end if
    
    ' Decode IV
    ivBytes.FromBase64String(ivStr)
    if ivBytes.Count() = 0
        m._log("ERROR: Invalid or empty base64 IV")
        return ""
    end if
    
    ' Decode ciphertext
    ctBytes.FromBase64String(ctStr)
    if ctBytes.Count() = 0
        m._log("ERROR: Invalid or empty base64 ciphertext")
        return ""
    end if
    
    ' Validate AES-128 requirements
    ' Key must be 16 bytes (128 bits)
    if keyBytes.Count() <> 16
        m._log("ERROR: Key must be 16 bytes for AES-128")
        return ""
    end if
    
    ' IV must be 16 bytes (block size)
    if ivBytes.Count() <> 16
        m._log("ERROR: IV must be 16 bytes")
        return ""
    end if
    
    ' Ciphertext must be non-empty and multiple of block size
    if ctBytes.Count() = 0 or ctBytes.Count() mod 16 <> 0
        m._log("ERROR: Invalid ciphertext length")
        return ""
    end if
    
    ' Create cipher (requires Roku OS 9.2+)
    cipher = CreateObject("roEVPCipher")
    if cipher = invalid
        m._log("ERROR: roEVPCipher not available (requires Roku OS 9.2+)")
        return ""
    end if
    
    ' Cipher operations wrapped in try/catch for platform compatibility
    ' (some environments may not support roByteArray args for roEVPCipher)
    try
        ' Setup: false=decrypt, aes-128-cbc algorithm, key, iv, padding=1 (PKCS7)
        if not cipher.Setup(false, "aes-128-cbc", keyBytes, ivBytes, 1)
            m._log("ERROR: Cipher setup failed")
            return ""
        end if
        
        ' Process the encrypted data
        decrypted = cipher.Process(ctBytes)
        if decrypted = invalid
            m._log("ERROR: Decryption failed")
            return ""
        end if
        
        ' Get final block (handles PKCS7 padding removal)
        finalBlock = cipher.Final()
        if finalBlock <> invalid and finalBlock.Count() > 0
            decrypted.Append(finalBlock)
        end if
        
        if decrypted.Count() = 0 then return ""
        
        return decrypted.ToAsciiString()
    catch e
        m._log("ERROR: Cipher operation failed - " + e.message)
        return ""
    end try
end function

' ===================================================================
' GrowthBook Tracking Plugin - Built-in Data Warehouse Integration
' Batches experiment and feature events, sends via HTTP POST
' ===================================================================
function GrowthBookTrackingPlugin(config as object) as object
    instance = {
        ' Configuration
        ingestorHost: "",
        clientKey: "",
        batchSize: 10,
        
        ' State
        eventQueue: [],
        http: invalid,
        
        ' Methods
        init: GrowthBookTrackingPlugin_init,
        onExperimentViewed: GrowthBookTrackingPlugin_onExperimentViewed,
        onFeatureUsage: GrowthBookTrackingPlugin_onFeatureUsage,
        flush: GrowthBookTrackingPlugin_flush
    }
    
    if config.ingestorHost <> invalid then instance.ingestorHost = config.ingestorHost
    if config.clientKey <> invalid then instance.clientKey = config.clientKey
    if config.batchSize <> invalid then instance.batchSize = config.batchSize
    
    return instance
end function

sub GrowthBookTrackingPlugin_init(gb as object)
    if gb.http <> invalid
        m.http = gb.http
    else
        try
            m.http = CreateObject("roURLTransfer")
            m.http.SetCertificatesFile("common:/certs/ca-bundle.crt")
        catch e
            m.http = invalid
        end try
    end if
end sub

sub GrowthBookTrackingPlugin_onExperimentViewed(experiment as object, result as object)
    event = {
        event_type: "experiment_viewed",
        timestamp: CreateObject("roDateTime").AsSeconds(),
        experiment_id: experiment.key,
        variation_id: result.variationId
    }
    m.eventQueue.Push(event)
    
    if m.eventQueue.Count() >= m.batchSize
        m.flush()
    end if
end sub

sub GrowthBookTrackingPlugin_onFeatureUsage(featureKey as string, result as object)
    event = {
        event_type: "feature_evaluated",
        timestamp: CreateObject("roDateTime").AsSeconds(),
        feature_key: featureKey,
        value: result.value,
        source: result.source
    }
    m.eventQueue.Push(event)
    
    if m.eventQueue.Count() >= m.batchSize
        m.flush()
    end if
end sub

sub GrowthBookTrackingPlugin_flush()
    if m.eventQueue.Count() = 0 then return
    if m.http = invalid then return
    if m.ingestorHost = "" then return
    
    payload = FormatJson({
        events: m.eventQueue,
        clientKey: m.clientKey
    })
    
    m.http.SetUrl(m.ingestorHost + "/events")
    m.http.AsyncPostFromString(payload)
    
    m.eventQueue = []
end sub

' ===================================================================
' Sticky Bucket Logic
' ===================================================================

' Build the sticky bucket experiment key: "expKey__bucketVersion"
function GrowthBook__getStickyBucketExperimentKey(expKey as string, bucketVersion as integer) as string
    return expKey + "__" + Str(bucketVersion).Trim()
end function

' Look up sticky bucket variation from cached assignment docs
' Checks both hashAttribute (higher priority) and fallbackAttribute (lower priority)
' Returns { variation: integer, versionIsBlocked: boolean }
function GrowthBook__getStickyBucketVariation(rule as object, context as object, featureKey as string) as object
    result = { variation: -1, versionIsBlocked: false }
    
    if m.stickyBucketService = invalid then return result
    if rule.disableStickyBucketing = true then return result
    
    ' Determine the experiment key
    expKey = rule.key
    if expKey = invalid or expKey = "" then expKey = featureKey
    
    bucketVersion = 0
    if rule.bucketVersion <> invalid then bucketVersion = rule.bucketVersion
    minBucketVersion = 0
    if rule.minBucketVersion <> invalid then minBucketVersion = rule.minBucketVersion
    
    ' Merge assignments from fallback (lower priority) and hash (higher priority)
    mergedAssignments = {}
    
    ' 1. Check fallbackAttribute first (lower priority)
    if rule.fallbackAttribute <> invalid and rule.fallbackAttribute <> ""
        fallbackVal = m._getAttributeValue(rule.fallbackAttribute)
        if fallbackVal <> invalid
            if type(fallbackVal) <> "roString" and type(fallbackVal) <> "String"
                fallbackVal = Str(fallbackVal).Trim()
            end if
            if fallbackVal <> ""
                fallbackKey = rule.fallbackAttribute + "||" + fallbackVal
                fallbackDoc = m._stickyBucketAssignmentDocs[fallbackKey]
                if fallbackDoc <> invalid and fallbackDoc.assignments <> invalid
                    for each k in fallbackDoc.assignments
                        mergedAssignments[k] = fallbackDoc.assignments[k]
                    end for
                end if
            end if
        end if
    end if
    
    ' 2. Check hashAttribute (higher priority - overwrites fallback)
    hashAttr = "id"
    if rule.hashAttribute <> invalid and rule.hashAttribute <> ""
        hashAttr = rule.hashAttribute
    end if
    hashVal = m._getAttributeValue(hashAttr)
    if hashVal <> invalid
        if type(hashVal) <> "roString" and type(hashVal) <> "String"
            hashVal = Str(hashVal).Trim()
        end if
        if hashVal <> ""
            hashKey = hashAttr + "||" + hashVal
            hashDoc = m._stickyBucketAssignmentDocs[hashKey]
            if hashDoc <> invalid and hashDoc.assignments <> invalid
                for each k in hashDoc.assignments
                    mergedAssignments[k] = hashDoc.assignments[k]
                end for
            end if
        end if
    end if
    
    if mergedAssignments.Count() = 0 then return result
    
    ' Check for blocked versions
    ' If any version < minBucketVersion has an assignment, user is blocked
    for v = 0 to minBucketVersion - 1
        vKey = m._getStickyBucketExperimentKey(expKey, v)
        if mergedAssignments.DoesExist(vKey)
            result.versionIsBlocked = true
            return result
        end if
    end for
    
    ' Look for current version assignment
    currentKey = m._getStickyBucketExperimentKey(expKey, bucketVersion)
    if mergedAssignments.DoesExist(currentKey)
        result.variation = Int(Val(mergedAssignments[currentKey]))
    end if
    
    return result
end function

' Save sticky bucket assignment to both in-memory cache and service
' Saves under context.hashAttribute (the resolved attribute from _getHashContext)
sub GrowthBook__saveStickyBucketAssignment(rule as object, context as object, variationIndex as integer, featureKey as string)
    if m.stickyBucketService = invalid then return
    if rule.disableStickyBucketing = true then return
    
    expKey = rule.key
    if expKey = invalid or expKey = "" then expKey = featureKey
    
    bucketVersion = 0
    if rule.bucketVersion <> invalid then bucketVersion = rule.bucketVersion
    
    assignmentKey = m._getStickyBucketExperimentKey(expKey, bucketVersion)
    docKey = context.hashAttribute + "||" + context.hashValue
    newValue = Str(variationIndex).Trim()
    
    ' Get existing doc from cache or start fresh
    existing = m._stickyBucketAssignmentDocs[docKey]
    assignments = {}
    if existing <> invalid and existing.assignments <> invalid
        for each k in existing.assignments
            assignments[k] = existing.assignments[k]
        end for
    end if
    
    ' Skip save if assignment already matches
    if assignments.DoesExist(assignmentKey) and assignments[assignmentKey] = newValue
        return
    end if
    
    ' Add/update the assignment
    assignments[assignmentKey] = newValue
    
    ' Update in-memory cache
    m._stickyBucketAssignmentDocs[docKey] = {
        attributeName: context.hashAttribute,
        attributeValue: context.hashValue,
        assignments: assignments
    }
    
    ' Persist to service
    m.stickyBucketService.saveAssignments(context.hashAttribute, context.hashValue, assignments)
end sub

' ===================================================================
' Sticky Bucket Services
' ===================================================================

' In-memory sticky bucket service (for testing/simple use)
function GrowthBookInMemoryStickyBucketService() as object
    return {
        docs: {},
        getAssignments: function(attrName as string, attrValue as string) as object
            key = attrName + "||" + attrValue
            return m.docs[key]
        end function,
        saveAssignments: sub(attrName as string, attrValue as string, assignments as object)
            key = attrName + "||" + attrValue
            m.docs[key] = {
                attributeName: attrName,
                attributeValue: attrValue,
                assignments: assignments
            }
        end sub,
        getAllAssignments: function(attributes as object) as object
            return m.docs
        end function
    }
end function

' Registry-based persistent sticky bucket service (Roku OS 7.0+)
function GrowthBookRegistryStickyBucketService() as object
    return {
        section: CreateObject("roRegistrySection", "GrowthBookStickyBuckets"),
        getAssignments: function(attrName as string, attrValue as string) as object
            key = attrName + "||" + attrValue
            value = m.section.Read(key)
            if value <> "" then return ParseJson(value)
            return invalid
        end function,
        saveAssignments: sub(attrName as string, attrValue as string, assignments as object)
            key = attrName + "||" + attrValue
            doc = {
                attributeName: attrName,
                attributeValue: attrValue,
                assignments: assignments
            }
            m.section.Write(key, FormatJson(doc))
            m.section.Flush()
        end sub,
        getAllAssignments: function(attributes as object) as object
            result = {}
            keys = m.section.GetKeyList()
            for each key in keys
                value = m.section.Read(key)
                if value <> "" then result[key] = ParseJson(value)
            end for
            return result
        end function
    }
end function
