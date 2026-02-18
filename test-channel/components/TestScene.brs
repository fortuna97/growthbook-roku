sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.resultsLabel = m.top.findNode("resultsLabel")
end sub

sub displayResults(testResults as object)
    if testResults = invalid
        m.statusLabel.text = "Error: No test results"
        m.statusLabel.color = "0xFF0000FF"
        return
    end if

    resultsText = "GROWTHBOOK SDK TEST RESULTS" + chr(10) + chr(10)

    successRate = 0
    if testResults.totalTests > 0
        successRate = Int((testResults.passedTests * 100) / testResults.totalTests)
    end if
    resultsText = resultsText + "Total: " + Str(testResults.passedTests).Trim() + "/" + Str(testResults.totalTests).Trim() + " passed (" + Str(successRate).Trim() + "%)" + chr(10) + chr(10)

    for each result in testResults.results
        resultsText = resultsText + result.status + "  " + result.name
        if result.message <> invalid and result.message <> ""
            resultsText = resultsText + " - " + result.message
        end if
        resultsText = resultsText + chr(10)
    end for

    m.resultsLabel.text = resultsText

    if testResults.failedTests = 0
        m.statusLabel.text = "All " + Str(testResults.totalTests).Trim() + " tests passed! SDK is device-ready."
        m.statusLabel.color = "0x00FF00FF"
    else
        m.statusLabel.text = Str(testResults.failedTests).Trim() + " of " + Str(testResults.totalTests).Trim() + " tests failed."
        m.statusLabel.color = "0xFF4444FF"
    end if
end sub
