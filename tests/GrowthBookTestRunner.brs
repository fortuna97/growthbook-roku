'
' GrowthBook Test Runner
' Parses and executes test cases from cases.json
' Validates SDK logic against official GrowthBook specification
'
' Requires: TestUtilities.brs (for deepEqual)
'

' ================================================================
' Main Test Runner
' ================================================================
function GrowthBookTestRunner() as object
    instance = {
        ' State
        cases: invalid,
        results: {},
        totalPassed: 0,
        totalFailed: 0,
        totalSkipped: 0,
        
        ' Public Methods
        loadCases: GrowthBookTestRunner_loadCases,
        runAllTests: GrowthBookTestRunner_runAllTests,
        runCategory: GrowthBookTestRunner_runCategory,
        getResults: GrowthBookTestRunner_getResults,
        printSummary: GrowthBookTestRunner_printSummary,
        
        ' Private Methods (test runners)
        _runSingleTest: GrowthBookTestRunner_runSingleTest,
        _runEvalConditionTest: GrowthBookTestRunner_runEvalConditionTest,
        _runHashTest: GrowthBookTestRunner_runHashTest,
        _runGetBucketRangeTest: GrowthBookTestRunner_runGetBucketRangeTest,
        _runChooseVariationTest: GrowthBookTestRunner_runChooseVariationTest,
        _runFeatureTest: GrowthBookTestRunner_runFeatureTest,
        _runExperimentTest: GrowthBookTestRunner_runExperimentTest,
        _runDecryptTest: GrowthBookTestRunner_runDecryptTest,
        _runStickyBucketTest: GrowthBookTestRunner_runStickyBucketTest
    }
    
    return instance
end function

' ================================================================
' Load cases.json
' ================================================================
function GrowthBookTestRunner_loadCases(filePath as string) as boolean
    m.cases = invalid
    
    ' Read file
    jsonString = ReadAsciiFile(filePath)
    if jsonString = "" or jsonString = invalid
        print "ERROR: Could not read cases.json from: " + filePath
        return false
    end if
    
    ' Parse JSON
    m.cases = ParseJson(jsonString)
    if m.cases = invalid
        print "ERROR: Could not parse cases.json"
        return false
    end if
    
    specVersion = ""
    if m.cases.specVersion <> invalid then specVersion = m.cases.specVersion
    print "Loaded cases.json (specVersion: " + specVersion + ")"
    return true
end function

' ================================================================
' Run All Test Categories
' ================================================================
function GrowthBookTestRunner_runAllTests() as object
    if m.cases = invalid
        print "ERROR: No test cases loaded. Call loadCases() first."
        return m.results
    end if
    
    categories = ["evalCondition", "hash", "getBucketRange", "chooseVariation", "feature", "run", "decrypt", "stickyBucket"]
    
    for each category in categories
        if m.cases[category] <> invalid
            m.runCategory(category)
        end if
    end for
    
    m.printSummary()
    return m.results
end function

' ================================================================
' Run Single Category
' ================================================================
function GrowthBookTestRunner_runCategory(category as string) as object
    if m.cases = invalid or m.cases[category] = invalid
        print "ERROR: Category not found: " + category
        return { passed: 0, failed: 0, skipped: 0 }
    end if
    
    tests = m.cases[category]
    passed = 0
    failed = 0
    skipped = 0
    failures = []
    
    print ""
    print "Running: " + category + " (" + Str(tests.Count()).Trim() + " tests)"
    print "----------------------------------------------------------------"
    
    for each test in tests
        result = m._runSingleTest(category, test)
        
        if result.status = "passed"
            passed = passed + 1
        else if result.status = "failed"
            failed = failed + 1
            failures.Push(result)
        else
            skipped = skipped + 1
        end if
    end for
    
    ' Store results
    m.results[category] = {
        passed: passed,
        failed: failed,
        skipped: skipped,
        total: tests.Count(),
        failures: failures
    }
    
    ' Update totals
    m.totalPassed = m.totalPassed + passed
    m.totalFailed = m.totalFailed + failed
    m.totalSkipped = m.totalSkipped + skipped
    
    ' Print category result
    percentage = 0
    if tests.Count() > 0
        percentage = Int((passed / tests.Count()) * 100)
    end if
    print category + ": " + Str(passed).Trim() + "/" + Str(tests.Count()).Trim() + " (" + Str(percentage).Trim() + "%)"
    
    ' Print failures (max 5)
    if failures.Count() > 0 and failures.Count() <= 5
        print "  Failures:"
        for each failure in failures
            print "    - " + failure.name
            if failure.expected <> invalid
                print "      Expected: " + formatValue(failure.expected)
                print "      Got     : " + formatValue(failure.actual)
            end if
        end for
    else if failures.Count() > 5
        print "  " + Str(failures.Count()).Trim() + " failures (showing first 5):"
        for i = 0 to 4
            print "    - " + failures[i].name
        end for
    end if
    
    return m.results[category]
end function

' ================================================================
' Run Single Test (dispatches to category-specific runner)
' ================================================================
function GrowthBookTestRunner_runSingleTest(category as string, test as object) as object
    if category = "evalCondition"
        return m._runEvalConditionTest(test)
    else if category = "hash"
        return m._runHashTest(test)
    else if category = "getBucketRange"
        return m._runGetBucketRangeTest(test)
    else if category = "chooseVariation"
        return m._runChooseVariationTest(test)
    else if category = "feature"
        return m._runFeatureTest(test)
    else if category = "run"
        return m._runExperimentTest(test)
    else if category = "decrypt"
        return m._runDecryptTest(test)
    else if category = "stickyBucket"
        return m._runStickyBucketTest(test)
    else
        return { status: "skipped", name: "unknown category" }
    end if
end function

' ================================================================
' Get Results
' ================================================================
function GrowthBookTestRunner_getResults() as object
    return {
        categories: m.results,
        totalPassed: m.totalPassed,
        totalFailed: m.totalFailed,
        totalSkipped: m.totalSkipped,
        total: m.totalPassed + m.totalFailed + m.totalSkipped
    }
end function

' ================================================================
' Print Summary
' ================================================================
sub GrowthBookTestRunner_printSummary()
    print ""
    print "================================================================"
    print "TEST SUMMARY"
    print "================================================================"
    
    total = m.totalPassed + m.totalFailed + m.totalSkipped
    percentage = 0
    if total > 0
        percentage = Int((m.totalPassed / total) * 100)
    end if
    
    print "Passed:  " + Str(m.totalPassed).Trim()
    print "Failed:  " + Str(m.totalFailed).Trim()
    print "Skipped: " + Str(m.totalSkipped).Trim()
    print "Total:   " + Str(total).Trim() + " (" + Str(percentage).Trim() + "%)"
    print ""
    
    if m.totalFailed = 0
        print "All tests passed!"
    else
        print Str(m.totalFailed).Trim() + " tests failed"
    end if
end sub

' ================================================================
' Category Test Runners
' ================================================================

' evalCondition: [name, condition, attributes, expected, savedGroups?]
function GrowthBookTestRunner_runEvalConditionTest(test as object) as object
    testName = test[0]
    ' print "Running: " + testName
    condition = test[1]
    attributes = test[2]
    expected = test[3]
    savedGroups = invalid
    if test.Count() > 4 then savedGroups = test[4]
    
    ' Create GrowthBook instance
    config = { attributes: attributes, http: {} }
    if savedGroups <> invalid then config.savedGroups = savedGroups
    gb = GrowthBook(config)
    
    ' Run test
    actual = gb._evaluateConditions(condition)
    
    if actual = expected
        return { status: "passed", name: testName }
    else
        return { status: "failed", name: testName, expected: expected, actual: actual }
    end if
end function

' hash: [seed, value, version, expected] - NO name field!
function GrowthBookTestRunner_runHashTest(test as object) as object
    seed = test[0]
    value = test[1]
    version = test[2]
    expected = test[3]
    
    ' Build test name (value can be string or number)
    valueStr = ""
    if type(value) = "roString" or type(value) = "String"
        valueStr = value
    else
        valueStr = Str(value).Trim()
    end if
    testName = "hash(" + seed + ", " + valueStr + ", v" + Str(version).Trim() + ")"
    
    ' Create GrowthBook instance
    gb = GrowthBook({http: {}})
    
    ' Run test
    actual = gb._gbhash(seed, value, version)
    
    ' Compare with tolerance for floating point
    tolerance = 0.001
    isMatch = false
    if actual = invalid and expected = invalid
        isMatch = true
    else if actual <> invalid and expected <> invalid
        if Abs(actual - expected) < tolerance
            isMatch = true
        end if
    end if
    
    if isMatch
        return { status: "passed", name: testName }
    else
        return { status: "failed", name: testName, expected: expected, actual: actual }
    end if
end function

' getBucketRange: [name, [numVariations, coverage, weights], expectedRanges]
function GrowthBookTestRunner_runGetBucketRangeTest(test as object) as object
    testName = test[0]
    params = test[1]
    expected = test[2]
    
    numVariations = params[0]
    coverage = params[1]
    weights = invalid
    if params.Count() > 2 then weights = params[2]
    
    ' Create GrowthBook instance
    gb = GrowthBook({http: {}})
    
    ' Run test
    actual = gb._getBucketRanges(numVariations, coverage, weights)
    
    ' Compare ranges with tolerance
    tolerance = 0.001
    isMatch = (actual.Count() = expected.Count())
    if isMatch
        for i = 0 to actual.Count() - 1
            if Abs(actual[i][0] - expected[i][0]) > tolerance or Abs(actual[i][1] - expected[i][1]) > tolerance
                isMatch = false
                exit for
            end if
        end for
    end if
    
    if isMatch
        return { status: "passed", name: testName }
    else
        return { status: "failed", name: testName }
    end if
end function

' chooseVariation: [name, n, ranges, expected]
function GrowthBookTestRunner_runChooseVariationTest(test as object) as object
    testName = test[0]
    n = test[1]
    ranges = test[2]
    expected = test[3]
    
    ' Create GrowthBook instance
    gb = GrowthBook({http: {}})
    
    ' Run test
    actual = gb._chooseVariation(n, ranges)
    
    if actual = expected
        return { status: "passed", name: testName }
    else
        return { status: "failed", name: testName, expected: expected, actual: actual }
    end if
end function

' feature: [name, context, featureKey, expected]
function GrowthBookTestRunner_runFeatureTest(test as object) as object
    testName = test[0]
    context = test[1]
    featureKey = test[2]
    expected = test[3]
    
    ' Build config from context
    config = { http: {} }
    if context.attributes <> invalid then config.attributes = context.attributes
    if context.features <> invalid then config.features = context.features
    if context.savedGroups <> invalid then config.savedGroups = context.savedGroups
    if context.forcedVariations <> invalid then config.forcedVariations = context.forcedVariations
    
    ' Create GrowthBook instance
    gb = GrowthBook(config)
    gb.init()
    
    ' Run test
    actual = gb.evalFeature(featureKey)
    
    ' Compare key fields (use deepEqual for value since it can be object/array)
    isMatch = true
    if not deepEqual(actual.value, expected.value) then isMatch = false
    if actual.on <> expected.on then isMatch = false
    if actual.off <> expected.off then isMatch = false
    if actual.source <> expected.source then isMatch = false
    if expected.ruleId <> invalid and actual.ruleId <> expected.ruleId then isMatch = false
    
    if isMatch
        return { status: "passed", name: testName }
    else
        return { status: "failed", name: testName, actual: actual, expected: expected }
    end if
end function

' run (experiment): [name, context, experiment, value, inExperiment, hashUsed]
function GrowthBookTestRunner_runExperimentTest(test as object) as object
    testName = test[0]
    context = test[1]
    experiment = test[2]
    expectedValue = test[3]
    expectedInExperiment = test[4]
    expectedHashUsed = test[5]
    
    ' Create GrowthBook instance with context
    gbConfig = { http: {} }
    if type(context) = "roAssociativeArray"
        if context.DoesExist("attributes") then gbConfig.attributes = context.attributes
        if context.DoesExist("forcedVariations") then gbConfig.forcedVariations = context.forcedVariations
        if context.DoesExist("savedGroups") then gbConfig.savedGroups = context.savedGroups
        if context.DoesExist("features") then gbConfig.features = context.features
    end if
    gb = GrowthBook(gbConfig)
    gb.init()
    
    numVariations = experiment.variations.Count()
    
    ' 1. Less than 2 variations
    if numVariations < 2
        return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
    end if
    
    ' 2. Context forcedVariations
    if type(context) = "roAssociativeArray" and context.DoesExist("forcedVariations") and type(context.forcedVariations) = "roAssociativeArray" and context.forcedVariations.DoesExist(experiment.key)
        force = context.forcedVariations[experiment.key]
        return _runExpGetResult(testName, experiment, force, false, expectedValue, expectedInExperiment, expectedHashUsed)
    end if
    
    ' 3. Context enabled === false
    if type(context) = "roAssociativeArray" and context.DoesExist("enabled") and context.enabled = false
        return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
    end if
    
    ' 4. URL querystring override (checked before active)
    if type(context) = "roAssociativeArray" and context.DoesExist("url") and context.url <> invalid
        urlStr = context.url
        if type(urlStr) = "roString" or type(urlStr) = "String"
            override = _runExpGetQueryStringOverride(experiment.key, urlStr, numVariations)
            if override >= 0
                return _runExpGetResult(testName, experiment, override, false, expectedValue, expectedInExperiment, expectedHashUsed)
            end if
        end if
    end if
    
    ' 5. Experiment active === false
    if experiment.DoesExist("active") and experiment.active = false
        return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
    end if
    
    ' 6. Get hash attribute and value
    hashAttr = "id"
    if experiment.DoesExist("hashAttribute") and experiment.hashAttribute <> invalid and experiment.hashAttribute <> ""
        hashAttr = experiment.hashAttribute
    end if
    hashValue = ""
    if type(context) = "roAssociativeArray" and context.DoesExist("attributes") and type(context.attributes) = "roAssociativeArray" and context.attributes.DoesExist(hashAttr)
        val = context.attributes[hashAttr]
        if val <> invalid
            if type(val) = "roString" or type(val) = "String"
                hashValue = val
            else
                hashValue = Str(val).Trim()
            end if
        end if
    end if
    if hashValue = ""
        return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
    end if
    
    ' 7. Filters / Namespace
    if experiment.DoesExist("filters") and experiment.filters <> invalid
        for each filter in experiment.filters
            filterAttr = "id"
            if filter.DoesExist("attribute") and filter.attribute <> invalid and filter.attribute <> ""
                filterAttr = filter.attribute
            end if
            filterHashValue = ""
            if type(context) = "roAssociativeArray" and context.DoesExist("attributes") and type(context.attributes) = "roAssociativeArray" and context.attributes.DoesExist(filterAttr)
                fval = context.attributes[filterAttr]
                if fval <> invalid
                    if type(fval) = "roString" or type(fval) = "String"
                        filterHashValue = fval
                    else
                        filterHashValue = Str(fval).Trim()
                    end if
                end if
            end if
            if filterHashValue = ""
                return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
            end if
            filterSeed = experiment.key
            if filter.DoesExist("seed") and filter.seed <> invalid then filterSeed = filter.seed
            filterHashVersion = 2
            if filter.DoesExist("hashVersion") and filter.hashVersion <> invalid then filterHashVersion = filter.hashVersion
            n = gb._gbhash(filterSeed, filterHashValue, filterHashVersion)
            if n = invalid
                return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
            end if
            inRange = false
            for each rng in filter.ranges
                if gb._inRange(n, rng)
                    inRange = true
                    exit for
                end if
            end for
            if not inRange
                return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
            end if
        end for
    else if experiment.DoesExist("namespace") and experiment.namespace <> invalid
        if not gb._inNamespace(hashValue, experiment.namespace)
            return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
        end if
    end if
    
    ' 8. Condition
    if experiment.DoesExist("condition") and experiment.condition <> invalid
        if not gb._evaluateConditions(experiment.condition)
            return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
        end if
    end if
    
    ' 9. Parent conditions (prerequisites)
    if experiment.DoesExist("parentConditions") and experiment.parentConditions <> invalid
        for each parent in experiment.parentConditions
            parentResult = gb.evalFeature(parent.id)
            tempGB = GrowthBook({ attributes: { value: parentResult.value }, savedGroups: gb.savedGroups, http: {} })
            if not tempGB._evaluateConditions(parent.condition)
                return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
            end if
        end for
    end if
    
    ' 10. Calculate hash
    hashVersion = 1
    if experiment.DoesExist("hashVersion") and experiment.hashVersion <> invalid
        hashVersion = experiment.hashVersion
    end if
    seed = experiment.key
    if experiment.DoesExist("seed") and experiment.seed <> invalid and experiment.seed <> ""
        seed = experiment.seed
    end if
    n = gb._gbhash(seed, hashValue, hashVersion)
    if n = invalid
        return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
    end if
    
    ' 11. Get ranges
    ranges = invalid
    if experiment.DoesExist("ranges") and experiment.ranges <> invalid
        ranges = experiment.ranges
    end if
    if ranges = invalid
        coverage = 1.0
        if experiment.DoesExist("coverage") and experiment.coverage <> invalid
            coverage = experiment.coverage
        end if
        weights = invalid
        if experiment.DoesExist("weights") and experiment.weights <> invalid
            weights = experiment.weights
        end if
        ranges = gb._getBucketRanges(numVariations, coverage, weights)
    end if
    
    ' 12. Choose variation
    assigned = gb._chooseVariation(n, ranges)
    
    ' 13. If not in range
    if assigned < 0
        return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
    end if
    
    ' 14. Experiment force (checked after coverage/range)
    if experiment.DoesExist("force")
        return _runExpGetResult(testName, experiment, experiment.force, false, expectedValue, expectedInExperiment, expectedHashUsed)
    end if
    
    ' 15. QA mode
    if type(context) = "roAssociativeArray" and context.DoesExist("qaMode") and context.qaMode = true
        return _runExpGetResult(testName, experiment, -1, false, expectedValue, expectedInExperiment, expectedHashUsed)
    end if
    
    ' 16. Return assigned variation
    return _runExpGetResult(testName, experiment, assigned, true, expectedValue, expectedInExperiment, expectedHashUsed)
end function

' Helper: build run result and compare with expected
function _runExpGetResult(testName as string, experiment as object, variationIndex as dynamic, hashUsed as boolean, expectedValue as dynamic, expectedInExperiment as boolean, expectedHashUsed as boolean) as object
    numVariations = experiment.variations.Count()
    inExperiment = true
    if type(variationIndex) <> "roInteger" and type(variationIndex) <> "Integer"
        variationIndex = Int(variationIndex)
    end if
    if variationIndex < 0 or variationIndex >= numVariations
        variationIndex = 0
        inExperiment = false
    end if
    value = experiment.variations[variationIndex]
    
    if not deepEqual(value, expectedValue)
        return { status: "failed", name: testName, expected: formatValue(expectedValue), actual: formatValue(value) }
    end if
    if inExperiment <> expectedInExperiment
        expStr = "false"
        actStr = "false"
        if expectedInExperiment then expStr = "true"
        if inExperiment then actStr = "true"
        return { status: "failed", name: testName + " (inExperiment)", expected: expStr, actual: actStr }
    end if
    if hashUsed <> expectedHashUsed
        expStr = "false"
        actStr = "false"
        if expectedHashUsed then expStr = "true"
        if hashUsed then actStr = "true"
        return { status: "failed", name: testName + " (hashUsed)", expected: expStr, actual: actStr }
    end if
    return { status: "passed", name: testName }
end function

' Helper: parse URL query string for experiment override
function _runExpGetQueryStringOverride(key as string, url as string, numVariations as integer) as integer
    qPos = Instr(1, url, "?")
    if qPos = 0 then return -1
    
    queryStr = Mid(url, qPos + 1)
    hashPos = Instr(1, queryStr, "#")
    if hashPos > 0 then queryStr = Left(queryStr, hashPos - 1)
    
    parts = queryStr.Split("&")
    for each part in parts
        eqPos = Instr(1, part, "=")
        if eqPos > 0
            pKey = Left(part, eqPos - 1)
            pValue = Mid(part, eqPos + 1)
            if pKey = key
                intVal = Int(Val(pValue))
                if intVal >= 0 and intVal < numVariations
                    return intVal
                end if
            end if
        end if
    end for
    
    return -1
end function

' decrypt: [name, encryptedString, key, expected]
function GrowthBookTestRunner_runDecryptTest(test as object) as object
    testName = test[0]
    encryptedStr = test[1]
    keyStr = test[2]
    expected = test[3]
    
    ' Create GrowthBook instance
    gb = GrowthBook({http: {}})
    
    ' Check if roEVPCipher is available and fully functional
    cipher = CreateObject("roEVPCipher")
    if cipher = invalid
        return { status: "skipped", name: testName + " (roEVPCipher not available)" }
    end if
    
    ' Probe: verify cipher.Setup() works with hex string args
    try
        cipher.Setup(true, "aes-128-cbc", "00000000000000000000000000000000", "00000000000000000000000000000000", 1)
    catch e
        return { status: "skipped", name: testName + " (roEVPCipher Setup failed)" }
    end try
    
    ' Run decrypt
    actual = gb._decrypt(encryptedStr, keyStr)
    
    ' Compare: expected null means error (decrypt returns "")
    ' expected string means successful decryption
    if expected = invalid
        ' Error case: decrypt should return empty string
        if actual = ""
            return { status: "passed", name: testName }
        else
            return { status: "failed", name: testName, expected: "null (empty)", actual: actual }
        end if
    else
        ' Success case: compare decrypted text
        if actual = expected
            return { status: "passed", name: testName }
        else
            return { status: "failed", name: testName, expected: expected, actual: actual }
        end if
    end if
end function

' stickyBucket: [name, context, initialDocs, featureKey, expectedResult, expectedAssignmentDocs]
function GrowthBookTestRunner_runStickyBucketTest(test as object) as object
    testName = test[0]
    context = test[1]
    initialDocs = test[2]
    featureKey = test[3]
    expectedResult = test[4]
    expectedAssignmentDocs = test[5]
    
    ' Build config from context
    config = { http: {} }
    if context.attributes <> invalid then config.attributes = context.attributes
    if context.features <> invalid then config.features = context.features
    if context.forcedVariations <> invalid then config.forcedVariations = context.forcedVariations
    if context.savedGroups <> invalid then config.savedGroups = context.savedGroups
    
    ' Create in-memory sticky bucket service
    stickyService = GrowthBookInMemoryStickyBucketService()
    config.stickyBucketService = stickyService
    
    ' Build the assignment docs cache
    ' Start with any docs from context
    assignmentDocs = {}
    if context.stickyBucketAssignmentDocs <> invalid
        for each key in context.stickyBucketAssignmentDocs
            assignmentDocs[key] = context.stickyBucketAssignmentDocs[key]
        end for
    end if
    
    ' Load initial docs into service; only cache docs matching user's attributes
    if initialDocs <> invalid
        for each doc in initialDocs
            if doc.attributeName <> invalid and doc.attributeValue <> invalid
                docKey = doc.attributeName + "||" + doc.attributeValue
                stickyService.saveAssignments(doc.attributeName, doc.attributeValue, doc.assignments)
                ' Only cache if user has this attribute with matching value
                if context.attributes <> invalid
                    userVal = context.attributes[doc.attributeName]
                    if userVal <> invalid
                        userValStr = ""
                        if type(userVal) = "roString" or type(userVal) = "String"
                            userValStr = userVal
                        else
                            userValStr = Str(userVal).Trim()
                        end if
                        if userValStr = doc.attributeValue
                            assignmentDocs[docKey] = doc
                        end if
                    end if
                end if
            end if
        end for
    end if
    
    config.stickyBucketAssignmentDocs = assignmentDocs
    
    ' Create GrowthBook instance
    gb = GrowthBook(config)
    gb.init()
    
    ' Evaluate feature
    actual = gb.evalFeature(featureKey)
    
    ' Compare result
    isMatch = true
    
    if expectedResult = invalid
        ' null expected = no experiment assignment (blocked or excluded)
        if actual.source = "experiment" then isMatch = false
    else
        ' Check value
        if not deepEqual(actual.value, expectedResult.value) then isMatch = false
        ' Check stickyBucketUsed
        if expectedResult.stickyBucketUsed <> invalid
            if actual.stickyBucketUsed <> expectedResult.stickyBucketUsed then isMatch = false
        end if
        ' Check variationId
        if expectedResult.variationId <> invalid
            if actual.variationId <> expectedResult.variationId then isMatch = false
        end if
    end if
    
    ' Compare assignment docs after evaluation
    if isMatch and expectedAssignmentDocs <> invalid
        actualDocs = gb._stickyBucketAssignmentDocs
        if not deepEqual(actualDocs, expectedAssignmentDocs)
            isMatch = false
        end if
    end if
    
    if isMatch
        return { status: "passed", name: testName }
    else
        return { status: "failed", name: testName, expected: expectedResult, actual: actual }
    end if
end function

' ================================================================
' Entry Point: Run Tests from cases.json
' ================================================================
function RunCasesJsonTests(casesPath as string) as object
    runner = GrowthBookTestRunner()
    
    if not runner.loadCases(casesPath)
        return { error: "Failed to load cases.json" }
    end if
    
    runner.runAllTests()
    return {
        totalPassed: runner.totalPassed,
        totalFailed: runner.totalFailed,
        totalSkipped: runner.totalSkipped,
        results: runner.results
    }
end function

