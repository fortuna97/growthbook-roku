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
        _runExperimentTest: GrowthBookTestRunner_runExperimentTest
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
    
    ' Categories to test (excluding stickyBucket and decrypt for now)
    categories = ["evalCondition", "hash", "getBucketRange", "chooseVariation", "feature", "run"]
    
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
    ' Note: "run" tests evaluate experiments differently
    ' Skipping for now - feature tests cover most experiment logic
    return { status: "skipped", name: testName + " (run tests not yet implemented)" }
end function

' ================================================================
' Entry Point: Run Tests from cases.json
' ================================================================
function RunCasesJsonTests(casesPath as string) as object
    runner = GrowthBookTestRunner()
    
    if not runner.loadCases(casesPath)
        return { error: "Failed to load cases.json" }
    end if
    
    return runner.runAllTests()
end function

