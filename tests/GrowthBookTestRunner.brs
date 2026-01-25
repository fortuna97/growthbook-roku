'
' GrowthBook Test Runner
' Parses and executes test cases from cases.json
' Validates SDK logic against official GrowthBook specification
'
' Requires: TestUtilities.brs (for deepEqual, createGBFromSDKConfig)
'

' ================================================================
' Main Test Runner
' ================================================================
function GrowthBookTestRunner() as object
    instance = {
        ' State
        cases: invalid
        results: {}
        totalPassed: 0
        totalFailed: 0
        totalSkipped: 0
        
        ' Public Methods
        loadCases: GrowthBookTestRunner_loadCases
        runAllTests: GrowthBookTestRunner_runAllTests
        runCategory: GrowthBookTestRunner_runCategory
        getResults: GrowthBookTestRunner_getResults
        printSummary: GrowthBookTestRunner_printSummary
        
        ' Private Methods (test runners)
        _runSingleTest: GrowthBookTestRunner_runSingleTest
        _runEvalConditionTest: GrowthBookTestRunner_runEvalConditionTest
        _runHashTest: GrowthBookTestRunner_runHashTest
        _runGetBucketRangeTest: GrowthBookTestRunner_runGetBucketRangeTest
        _runChooseVariationTest: GrowthBookTestRunner_runChooseVariationTest
        _runFeatureTest: GrowthBookTestRunner_runFeatureTest
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
    
    print "Loaded cases.json (specVersion: " + m.cases.specVersion + ")"
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
        passed: passed
        failed: failed
        skipped: skipped
        total: tests.Count()
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
        categories: m.results
        totalPassed: m.totalPassed
        totalFailed: m.totalFailed
        totalSkipped: m.totalSkipped
        total: m.totalPassed + m.totalFailed + m.totalSkipped
    }
end function

' ================================================================
' Print Summary
' ================================================================
function GrowthBookTestRunner_printSummary() as void
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
end function

' ================================================================
' Category Test Runners (stubs - to be implemented in next commits)
' ================================================================

function GrowthBookTestRunner_runEvalConditionTest(test as object) as object
    ' Test format: [name, condition, attributes, expected, savedGroups?]
    return { status: "skipped", name: "evalCondition - not yet implemented" }
end function

function GrowthBookTestRunner_runHashTest(test as object) as object
    ' Test format: [seed, value, version, expected]
    return { status: "skipped", name: "hash - not yet implemented" }
end function

function GrowthBookTestRunner_runGetBucketRangeTest(test as object) as object
    ' Test format: [name, [numVariations, coverage, weights], expectedRanges]
    return { status: "skipped", name: "getBucketRange - not yet implemented" }
end function

function GrowthBookTestRunner_runChooseVariationTest(test as object) as object
    ' Test format: [name, n, ranges, expected]
    return { status: "skipped", name: "chooseVariation - not yet implemented" }
end function

function GrowthBookTestRunner_runFeatureTest(test as object) as object
    ' Test format: [name, context, featureKey, expected]
    return { status: "skipped", name: "feature - not yet implemented" }
end function

function GrowthBookTestRunner_runExperimentTest(test as object) as object
    ' Test format: [name, context, experiment, value, inExperiment, hashUsed]
    return { status: "skipped", name: "run - not yet implemented" }
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

