' GrowthBook SDK Test Runner for brs-desktop
' Runs runtime smoke tests + official cases.json spec tests

function RunSDKTests() as object
    testResults = {
        totalTests: 0,
        passedTests: 0,
        failedTests: 0,
        results: [],
        specResults: invalid
    }

    print ""
    print "========================================"
    print "PART 1: Runtime Smoke Tests"
    print "========================================"
    testResults = runInitializationTests(testResults)
    testResults = runPerformanceTests(testResults)
    testResults = runNetworkTests(testResults)
    testResults = runEncryptionTests(testResults)
    testResults = runStickyBucketServiceTests(testResults)
    testResults = runTrackingPluginTests(testResults)
    testResults = runRefreshFeaturesTests(testResults)

    print ""
    print "========================================"
    print "PART 2: Official Spec Tests (cases.json)"
    print "========================================"
    testResults = runSpecTests(testResults)

    successRate = 0
    if testResults.totalTests > 0
        successRate = (testResults.passedTests * 100) / testResults.totalTests
    end if

    print ""
    print "========================================"
    print "FINAL: " + Str(testResults.passedTests).Trim() + "/" + Str(testResults.totalTests).Trim() + " passed (" + Str(Int(successRate)).Trim() + "%)"
    print "========================================"

    return testResults
end function

' ================================================================
' Spec Tests (cases.json via GrowthBookTestRunner)
' ================================================================
function runSpecTests(testResults as object) as object
    casesPath = "pkg:/source/cases.json"
    runner = GrowthBookTestRunner()

    if not runner.loadCases(casesPath)
        testResults = recordTestResult(testResults, "Load cases.json", false, "Failed to load " + casesPath)
        return testResults
    end if
    testResults = recordTestResult(testResults, "Load cases.json", true, "Loaded successfully")

    runner.runAllTests()
    specResults = runner.getResults()
    testResults.specResults = specResults

    for each category in specResults.categories
        catResult = specResults.categories[category]
        catTotal = catResult.passed + catResult.failed

        testResults.totalTests = testResults.totalTests + catTotal
        testResults.passedTests = testResults.passedTests + catResult.passed
        testResults.failedTests = testResults.failedTests + catResult.failed

        passed = (catResult.failed = 0)
        pct = 0
        if catTotal > 0 then pct = Int((catResult.passed * 100) / catTotal)

        testResults.results.push({
            name: "Spec: " + category,
            status: iif(passed, "PASS", "FAIL"),
            message: Str(catResult.passed).Trim() + "/" + Str(catTotal).Trim() + " (" + Str(pct).Trim() + "%)",
            passed: passed
        })
    end for

    return testResults
end function

' ================================================================
' Smoke Tests
' ================================================================
function runInitializationTests(testResults as object) as object
    print "Testing SDK Initialization..."

    testName = "SDK Initialization"
    try
        gb = GrowthBook({
            clientKey: "test_key",
            attributes: { userId: "test_user" }
        })
        if gb <> invalid
            testResults = recordTestResult(testResults, testName, true, "OK")
        else
            testResults = recordTestResult(testResults, testName, false, "Returned invalid")
        end if
    catch error
        testResults = recordTestResult(testResults, testName, false, "Exception: " + errorMessage(error))
    end try

    testName = "Invalid Config Handling"
    try
        gb = GrowthBook({
            clientKey: "",
            attributes: invalid,
            features: { "test": { "enabled": true } }
        })
        if gb <> invalid
            testResults = recordTestResult(testResults, testName, true, "Handled gracefully")
        else
            testResults = recordTestResult(testResults, testName, false, "Returned invalid")
        end if
    catch error
        testResults = recordTestResult(testResults, testName, false, "Exception: " + errorMessage(error))
    end try

    return testResults
end function

function runPerformanceTests(testResults as object) as object
    print "Testing Performance..."

    testName = "1000 Feature Evaluations"
    try
        gb = GrowthBook({
            clientKey: "test_key",
            features: { "perf_test": { "defaultValue": "fast" } }
        })
        gb.init()

        startTime = CreateObject("roDateTime").AsSeconds()
        for i = 1 to 1000
            gb.evalFeature("perf_test")
        end for
        endTime = CreateObject("roDateTime").AsSeconds()
        duration = endTime - startTime

        if duration < 5
            testResults = recordTestResult(testResults, testName, true, Str(duration).Trim() + "s")
        else
            testResults = recordTestResult(testResults, testName, false, "Too slow: " + Str(duration).Trim() + "s")
        end if
    catch error
        testResults = recordTestResult(testResults, testName, false, "Exception: " + errorMessage(error))
    end try

    return testResults
end function

function runNetworkTests(testResults as object) as object
    print "Testing Network Components..."

    testName = "Network Component Creation"
    try
        http = CreateObject("roURLTransfer")
        port = CreateObject("roMessagePort")

        if http <> invalid and port <> invalid
            testResults = recordTestResult(testResults, testName, true, "OK")
        else
            testResults = recordTestResult(testResults, testName, false, "Component creation failed")
        end if
    catch error
        testResults = recordTestResult(testResults, testName, false, "Exception: " + errorMessage(error))
    end try

    return testResults
end function

function runEncryptionTests(testResults as object) as object
    print "Testing Encrypted Features API..."

    testName = "Encryption Config"
    try
        gb = GrowthBook({
            clientKey: "test_key",
            decryptionKey: "test_decrypt_key_123"
        })
        if gb <> invalid and gb.decryptionKey = "test_decrypt_key_123"
            testResults = recordTestResult(testResults, testName, true, "OK")
        else
            testResults = recordTestResult(testResults, testName, false, "decryptionKey not set")
        end if
    catch error
        testResults = recordTestResult(testResults, testName, false, "Exception: " + errorMessage(error))
    end try

    testName = "Decrypt Invalid Input"
    try
        gb = GrowthBook({
            clientKey: "test_key",
            decryptionKey: "key123"
        })
        gb.init()
        result = gb._decrypt("", "")
        if result = ""
            testResults = recordTestResult(testResults, testName, true, "OK")
        else
            testResults = recordTestResult(testResults, testName, false, "Expected empty string, got: " + result)
        end if
    catch error
        testResults = recordTestResult(testResults, testName, false, "Exception: " + errorMessage(error))
    end try

    return testResults
end function

function runStickyBucketServiceTests(testResults as object) as object
    print "Testing Sticky Bucket Service..."

    testName = "InMemory Sticky Bucket Create"
    try
        sbs = GrowthBookInMemoryStickyBucketService()
        if sbs <> invalid and sbs.getAssignments <> invalid and sbs.saveAssignments <> invalid
            testResults = recordTestResult(testResults, testName, true, "OK")
        else
            testResults = recordTestResult(testResults, testName, false, "Missing methods")
        end if
    catch error
        testResults = recordTestResult(testResults, testName, false, "Exception: " + errorMessage(error))
    end try

    testName = "Sticky Bucket Round-Trip"
    try
        sbs = GrowthBookInMemoryStickyBucketService()
        sbs.saveAssignments("id", "user_123", { "exp__0": "1" })
        doc = sbs.getAssignments("id", "user_123")
        if doc <> invalid and doc.assignments <> invalid and doc.assignments["exp__0"] = "1"
            testResults = recordTestResult(testResults, testName, true, "OK")
        else
            testResults = recordTestResult(testResults, testName, false, "Assignments not persisted")
        end if
    catch error
        testResults = recordTestResult(testResults, testName, false, "Exception: " + errorMessage(error))
    end try

    return testResults
end function

function runTrackingPluginTests(testResults as object) as object
    print "Testing Tracking Plugins..."

    testName = "Tracking Plugin Create"
    try
        plugin = GrowthBookTrackingPlugin({
            ingestorHost: "https://test.example.com",
            clientKey: "sdk-abc123",
            batchSize: 5
        })
        if plugin <> invalid and plugin.ingestorHost = "https://test.example.com" and plugin.clientKey = "sdk-abc123" and plugin.batchSize = 5
            testResults = recordTestResult(testResults, testName, true, "OK")
        else
            testResults = recordTestResult(testResults, testName, false, "Plugin config mismatch")
        end if
    catch error
        testResults = recordTestResult(testResults, testName, false, "Exception: " + errorMessage(error))
    end try

    testName = "Register Tracking Plugin"
    try
        gb = GrowthBook({
            clientKey: "test_key"
        })
        gb.init()
        plugin = GrowthBookTrackingPlugin({
            ingestorHost: "https://test.example.com",
            clientKey: "sdk-abc123"
        })
        gb.registerTrackingPlugin(plugin)
        if gb.trackingPlugins.Count() = 1
            testResults = recordTestResult(testResults, testName, true, "OK")
        else
            testResults = recordTestResult(testResults, testName, false, "Plugin not registered")
        end if
    catch error
        testResults = recordTestResult(testResults, testName, false, "Exception: " + errorMessage(error))
    end try

    return testResults
end function

function runRefreshFeaturesTests(testResults as object) as object
    print "Testing Refresh Features API..."

    testName = "Refresh Features API"
    try
        gb = GrowthBook({
            clientKey: "test_key"
        })
        gb.init()
        result = gb.refreshFeatures()
        if type(result) = "roBoolean" or type(result) = "Boolean"
            testResults = recordTestResult(testResults, testName, true, "OK")
        else
            testResults = recordTestResult(testResults, testName, false, "Expected boolean, got: " + type(result))
        end if
    catch error
        testResults = recordTestResult(testResults, testName, false, "Exception: " + errorMessage(error))
    end try

    return testResults
end function

' ================================================================
' Helpers
' ================================================================
function recordTestResult(testResults as object, testName as string, passed as boolean, message as string) as object
    testResults.totalTests = testResults.totalTests + 1

    if passed
        testResults.passedTests = testResults.passedTests + 1
        status = "PASS"
        print "  PASS: " + testName + " - " + message
    else
        testResults.failedTests = testResults.failedTests + 1
        status = "FAIL"
        print "  FAIL: " + testName + " - " + message
    end if

    testResults.results.push({
        name: testName,
        status: status,
        message: message,
        passed: passed
    })

    return testResults
end function

function errorMessage(error as object) as string
    if error <> invalid and type(error) = "roAssociativeArray" and error.message <> invalid
        return error.message
    end if
    return "unknown error"
end function

function iif(condition as boolean, trueVal as string, falseVal as string) as string
    if condition then return trueVal
    return falseVal
end function
