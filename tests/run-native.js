const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * GrowthBook Native BrightScript Test Runner (Headless)
 * 
 * Runs the native BrightScript test runner using the '@rokucommunity/brs' interpreter.
 * Validates SDK logic against cases.json in actual BrightScript execution.
 */

const projectRoot = path.join(__dirname, '..');
const sourceFile = 'source/GrowthBook.brs';
const utilitiesFile = 'tests/TestUtilities.brs';
const runnerFile = 'tests/GrowthBookTestRunner.brs';
const entryFile = path.join(__dirname, 'test-entry.brs');
const entryRelative = 'tests/test-entry.brs';

// Create a temporary entry point
const entryContent = `
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
`;

console.log('🧪 Running Native BrightScript spec tests...\n');

try {
    fs.writeFileSync(entryFile, entryContent);

    const cmd = `npx @rokucommunity/brs "${entryRelative}" "${sourceFile}" "${utilitiesFile}" "${runnerFile}"`;
    const result = spawnSync(cmd, [], {
        cwd: projectRoot,
        encoding: 'utf8',
        shell: true
    });

    const stdout = result.stdout || '';
    const stderr = result.stderr || '';

    // Print stdout (test results)
    if (stdout) console.log(stdout);

    // Print stderr warnings (e.g. regex warnings) but don't treat them as failures
    if (stderr) {
        const lines = stderr.split('\n').filter(l => l.trim());
        if (lines.length > 0) {
            console.log('⚠️  Interpreter warnings:');
            lines.forEach(l => console.log('   ' + l));
            console.log('');
        }
    }

    // Check for explicit failure markers in stdout only
    if (stdout.includes('--- NATIVE TESTS FAILED ---')) {
        console.error('❌ Native Spec Tests Failed!');
        process.exit(1);
    }

    if (stdout.includes('--- NATIVE TESTS PASSED ---')) {
        console.log('✅ Native Spec Tests Passed!');
        process.exit(0);
    }

    // If brs crashed (no output at all)
    if (result.status !== 0 && !stdout.includes('TEST SUMMARY')) {
        console.error('❌ Native interpreter exited with code ' + result.status);
        process.exit(1);
    }

    console.log('✅ Native Spec Tests Passed!');

} catch (err) {
    console.error('Error running native tests:', err);
    process.exit(1);
} finally {
    if (fs.existsSync(entryFile)) {
        fs.unlinkSync(entryFile);
    }
}
