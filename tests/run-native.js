const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * GrowthBook Native BrightScript Test Runner (Headless)
 * 
 * This script runs the native BrightScript test runner using the 'brs' interpreter.
 * It simulates running the tests on a Roku device.
 */

const projectRoot = path.join(__dirname, '..');
const sourceFile = path.join(projectRoot, 'source', 'GrowthBook.brs');
const utilitiesFile = path.join(projectRoot, 'tests', 'TestUtilities.brs');
const runnerFile = path.join(projectRoot, 'tests', 'GrowthBookTestRunner.brs');
const casesFile = path.join(projectRoot, 'tests', 'cases.json');

// Create a temporary entry point
const entryFile = path.join(__dirname, 'test-entry.brs');
const entryContent = `
sub Main()
    ' The path should be relative to the root of the project
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
`;

console.log('🧪 Running Native BrightScript spec tests...');

try {
    fs.writeFileSync(entryFile, entryContent);

    // Run brs with all necessary files
    // The order matters - entry point first
    const result = spawnSync('npx', [
        '@rokucommunity/brs',
        entryFile,
        sourceFile,
        utilitiesFile,
        runnerFile
    ], {
        cwd: projectRoot,
        encoding: 'utf8',
        stdio: 'inherit'
    });

    // Check for our failure marker in the output
    // Note: since we used stdio: inherit, we can't easily check stdout here
    // unless we change it to 'pipe'. But we want the user to see the output.
    
    // Let's re-run or capture output if we need to fail the process
    const captureResult = spawnSync('npx', [
        '@rokucommunity/brs',
        entryFile,
        sourceFile,
        utilitiesFile,
        runnerFile
    ], {
        cwd: projectRoot,
        encoding: 'utf8'
    });

    const output = (captureResult.stdout || '') + (captureResult.stderr || '');

    if (output.includes('--- NATIVE TESTS FAILED ---') || 
        output.includes('BRIGHTSCRIPT: ERROR:') ||
        output.includes('ERROR:') ||
        captureResult.status !== 0) {
        console.error('\n❌ Native Spec Tests Failed!');
        process.exit(1);
    }

    console.log('\n✅ Native Spec Tests Passed!');

} catch (err) {
    console.error('Error running native tests:', err);
    process.exit(1);
} finally {
    if (fs.existsSync(entryFile)) {
        fs.unlinkSync(entryFile);
    }
}
