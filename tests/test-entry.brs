sub Main()
    results = RunCasesJsonTests("pkg:/tests/cases.json")
    
    if results.error <> invalid
        print "ERROR: " + results.error
        print "--- NATIVE TESTS FAILED ---"
        return
    end if

    if results.totalFailed <> invalid and results.totalFailed > 0
        print "--- NATIVE TESTS FAILED ---"
    else if results.totalPassed = invalid or results.totalPassed = 0
        print "ERROR: No tests were run"
        print "--- NATIVE TESTS FAILED ---"
    else
        print "--- NATIVE TESTS PASSED ---"
    end if
end sub
