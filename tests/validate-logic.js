#!/usr/bin/env node

/**
 * GrowthBook BrightScript Logic Validator
 * 
 * This validates the core SDK logic by:
 * 1. Reading cases.json test definitions
 * 2. Implementing the same logic in JavaScript (mirroring BrightScript)
 * 3. Running tests to verify correctness
 * 
 * This lets you test without a Roku device!
 */

const fs = require('fs');
const path = require('path');

// Load test cases
const casesPath = path.join(__dirname, 'cases.json');
const cases = JSON.parse(fs.readFileSync(casesPath, 'utf8'));

console.log('🧪 GrowthBook BrightScript Logic Validator\n');
console.log(`Loaded ${Object.keys(cases).length} test categories from cases.json\n`);

// ================================================================
// Mock GrowthBook Implementation (JavaScript version of your BrightScript)
// ================================================================

class GrowthBook {
    constructor(config = {}) {
        this.attributes = config.attributes || {};
        this.features = config.features || {};
    }

    // Evaluate conditions (mirrors your BrightScript implementation)
    _evaluateConditions(condition) {
        if (!condition || typeof condition !== 'object') {
            return true;
        }

        // Empty condition
        if (Object.keys(condition).length === 0) {
            return true;
        }

        // Logical operators
        if (condition.$or) {
            if (!Array.isArray(condition.$or) || condition.$or.length === 0) {
                return true;
            }
            return condition.$or.some(c => this._evaluateConditions(c));
        }

        if (condition.$nor) {
            if (!Array.isArray(condition.$nor)) return true;
            return !condition.$nor.some(c => this._evaluateConditions(c));
        }

        if (condition.$and) {
            if (!Array.isArray(condition.$and) || condition.$and.length === 0) {
                return true;
            }
            return condition.$and.every(c => this._evaluateConditions(c));
        }

        if (condition.$not) {
            return !this._evaluateConditions(condition.$not);
        }

        // Attribute conditions
        for (const [attr, conditionValue] of Object.entries(condition)) {
            if (['$or', '$and', '$not', '$nor'].includes(attr)) continue;

            const value = this._getAttributeValue(attr);

            if (typeof conditionValue === 'object' && conditionValue !== null && !Array.isArray(conditionValue)) {
                // Operator conditions
                if ('$eq' in conditionValue && value !== conditionValue.$eq) return false;
                if ('$ne' in conditionValue && value === conditionValue.$ne) return false;
                if ('$lt' in conditionValue && (value === undefined || !(value < conditionValue.$lt))) return false;
                if ('$lte' in conditionValue && (value === undefined || !(value <= conditionValue.$lte))) return false;
                if ('$gt' in conditionValue && (value === undefined || !(value > conditionValue.$gt))) return false;
                if ('$gte' in conditionValue && (value === undefined || !(value >= conditionValue.$gte))) return false;
                
                // Version comparison operators
                if ('$veq' in conditionValue) {
                    const v1 = this._paddedVersionString(value);
                    const v2 = this._paddedVersionString(conditionValue.$veq);
                    if (v1 !== v2) return false;
                }
                if ('$vne' in conditionValue) {
                    const v1 = this._paddedVersionString(value);
                    const v2 = this._paddedVersionString(conditionValue.$vne);
                    if (v1 === v2) return false;
                }
                if ('$vlt' in conditionValue) {
                    const v1 = this._paddedVersionString(value);
                    const v2 = this._paddedVersionString(conditionValue.$vlt);
                    if (!(v1 < v2)) return false;
                }
                if ('$vlte' in conditionValue) {
                    const v1 = this._paddedVersionString(value);
                    const v2 = this._paddedVersionString(conditionValue.$vlte);
                    if (!(v1 <= v2)) return false;
                }
                if ('$vgt' in conditionValue) {
                    const v1 = this._paddedVersionString(value);
                    const v2 = this._paddedVersionString(conditionValue.$vgt);
                    if (!(v1 > v2)) return false;
                }
                if ('$vgte' in conditionValue) {
                    const v1 = this._paddedVersionString(value);
                    const v2 = this._paddedVersionString(conditionValue.$vgte);
                    if (!(v1 >= v2)) return false;
                }
                
                if ('$in' in conditionValue) {
                    if (!Array.isArray(conditionValue.$in)) return false;
                    if (Array.isArray(value)) {
                        // Array intersection
                        if (!value.some(v => conditionValue.$in.includes(v))) return false;
                    } else {
                        if (!conditionValue.$in.includes(value)) return false;
                    }
                }
                
                if ('$nin' in conditionValue) {
                    if (!Array.isArray(conditionValue.$nin)) return false;
                    if (Array.isArray(value)) {
                        if (value.some(v => conditionValue.$nin.includes(v))) return false;
                    } else {
                        if (conditionValue.$nin.includes(value)) return false;
                    }
                }

                if ('$exists' in conditionValue) {
                    const exists = value !== undefined && value !== null;
                    if (exists !== conditionValue.$exists) return false;
                }

                if ('$type' in conditionValue) {
                    const actualType = this._getType(value);
                    if (actualType !== conditionValue.$type) return false;
                }

                if ('$regex' in conditionValue) {
                    if (typeof value !== 'string') return false;
                    try {
                        const regex = new RegExp(conditionValue.$regex);
                        if (!regex.test(value)) return false;
                    } catch (e) {
                        return false;
                    }
                }

                if ('$elemMatch' in conditionValue) {
                    if (!Array.isArray(value)) return false;
                    let found = false;
                    for (const item of value) {
                        const tempGB = new GrowthBook({ attributes: { _item: item } });
                        const tempCond = {};
                        for (const [k, v] of Object.entries(conditionValue.$elemMatch)) {
                            tempCond[`_item.${k}`] = v;
                        }
                        if (tempGB._evaluateConditions(tempCond)) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) return false;
                }

                if ('$size' in conditionValue) {
                    if (!Array.isArray(value)) return false;
                    if (typeof conditionValue.$size === 'number') {
                        if (value.length !== conditionValue.$size) return false;
                    } else if (typeof conditionValue.$size === 'object') {
                        const tempGB = new GrowthBook({ attributes: { _size: value.length } });
                        const tempCond = { _size: conditionValue.$size };
                        if (!tempGB._evaluateConditions(tempCond)) return false;
                    }
                }

                if ('$all' in conditionValue) {
                    if (!Array.isArray(value) || !Array.isArray(conditionValue.$all)) return false;
                    for (const required of conditionValue.$all) {
                        if (!value.includes(required)) return false;
                    }
                }
            } else {
                // Direct equality
                if (!this._deepEqual(value, conditionValue)) return false;
            }
        }

        return true;
    }

    _getAttributeValue(attr) {
        if (attr.includes('.')) {
            const parts = attr.split('.');
            let value = this.attributes;
            for (const part of parts) {
                if (value && typeof value === 'object') {
                    value = value[part];
                } else {
                    return undefined;
                }
            }
            return value;
        }
        return this.attributes[attr];
    }

    _getType(value) {
        if (value === null || value === undefined) return 'null';
        if (typeof value === 'string') return 'string';
        if (typeof value === 'number') return 'number';
        if (typeof value === 'boolean') return 'boolean';
        if (Array.isArray(value)) return 'array';
        if (typeof value === 'object') return 'object';
        return 'unknown';
    }

    _deepEqual(a, b) {
        if (a === b) return true;
        if (a === null || b === null || a === undefined || b === undefined) return a === b;
        if (typeof a !== typeof b) return false;
        if (Array.isArray(a) && Array.isArray(b)) {
            if (a.length !== b.length) return false;
            return a.every((val, i) => this._deepEqual(val, b[i]));
        }
        if (typeof a === 'object' && typeof b === 'object') {
            const keysA = Object.keys(a);
            const keysB = Object.keys(b);
            if (keysA.length !== keysB.length) return false;
            return keysA.every(key => this._deepEqual(a[key], b[key]));
        }
        return false;
    }

    // Version string padding for semantic version comparison
    // Matches BrightScript _paddedVersionString implementation
    _paddedVersionString(input) {
        // Convert to string if number
        if (typeof input === 'number') {
            input = String(input);
        }
        
        if (!input || typeof input !== 'string') {
            return '0';
        }
        
        let version = input;
        
        // Remove leading "v" if present
        if (version.startsWith('v') || version.startsWith('V')) {
            version = version.substring(1);
        }
        
        // Remove build info after "+"
        const plusPos = version.indexOf('+');
        if (plusPos > -1) {
            version = version.substring(0, plusPos);
        }
        
        // Split on "." and "-"
        const parts = version.split(/[.\-]/);
        
        // If exactly 3 parts (SemVer without pre-release), add "~"
        // This makes "1.0.0" > "1.0.0-beta" since "~" > any letter
        if (parts.length === 3) {
            parts.push('~');
        }
        
        // Pad numeric parts with spaces (right-justify to 5 chars)
        const paddedParts = parts.map(part => {
            if (/^\d+$/.test(part)) {
                return part.padStart(5, ' ');
            }
            return part;
        });
        
        return paddedParts.join('-');
    }

    // FNV-1a 32-bit hash algorithm
    // Matches BrightScript _fnv1a32 implementation
    _fnv1a32(str) {
        let hval = 0x811c9dc5; // 2166136261 - offset basis
        const prime = 0x01000193; // 16777619 - FNV prime
        
        for (let i = 0; i < str.length; i++) {
            hval ^= str.charCodeAt(i);
            hval = Math.imul(hval, prime) >>> 0; // Keep 32-bit unsigned
        }
        
        return hval >>> 0; // Ensure unsigned
    }

    // GrowthBook hash function with seed and version support
    // Matches BrightScript _gbhash implementation
    _gbhash(seed, value, version) {
        // Convert to strings
        if (typeof value !== 'string') value = String(value);
        if (typeof seed !== 'string') seed = '';
        
        if (version === 2) {
            // Version 2: fnv1a32(str(fnv1a32(seed + value)))
            const combined = seed + value;
            const hash1 = this._fnv1a32(combined);
            const hash2 = this._fnv1a32(String(hash1));
            return (hash2 % 10000) / 10000;
        } else if (version === 1) {
            // Version 1: fnv1a32(value + seed)
            const combined = value + seed;
            const hash1 = this._fnv1a32(combined);
            return (hash1 % 1000) / 1000;
        }
        
        return null;
    }

    // Get bucket ranges for variation assignment
    // Matches BrightScript _getBucketRanges implementation
    _getBucketRanges(numVariations, coverage = 1, weights = null) {
        // Clamp coverage
        if (coverage < 0) coverage = 0;
        if (coverage > 1) coverage = 1;
        
        // Generate equal weights if not provided or invalid
        if (!weights || weights.length === 0 || weights.length !== numVariations) {
            weights = Array(numVariations).fill(1 / numVariations);
        }
        
        // Validate weights sum
        const weightSum = weights.reduce((a, b) => a + b, 0);
        if (weightSum < 0.99 || weightSum > 1.01) {
            weights = Array(numVariations).fill(1 / numVariations);
        }
        
        // Build bucket ranges
        const ranges = [];
        let cumulative = 0;
        for (const w of weights) {
            const start = cumulative;
            cumulative += w;
            ranges.push([start, start + coverage * w]);
        }
        
        return ranges;
    }

    // Choose variation based on hash value and bucket ranges
    _chooseVariation(n, ranges) {
        for (let i = 0; i < ranges.length; i++) {
            if (this._inRange(n, ranges[i])) {
                return i;
            }
        }
        return -1;
    }

    // Check if value is within a bucket range [start, end)
    _inRange(n, range) {
        return n >= range[0] && n < range[1];
    }
}

// ================================================================
// Test Runner
// ================================================================

function runTests(category, tests) {
    console.log(`\n📦 Testing: ${category}`);
    console.log('─'.repeat(60));

    let passed = 0;
    let failed = 0;
    const failures = [];

    for (const test of tests) {
        const [name, ...rest] = test;
        
        try {
            let result;

            if (category === 'evalCondition') {
                const [condition, attributes, expected] = rest;
                const gb = new GrowthBook({ attributes });
                result = gb._evaluateConditions(condition);
                
                if (result === expected) {
                    passed++;
                    process.stdout.write('✓');
                } else {
                    failed++;
                    process.stdout.write('✗');
                    failures.push({ name, expected, actual: result });
                }
            } else if (category === 'hash') {
                // Hash tests: [seed, value, version, expected] - no name field
                const [seed, value, version, expected] = test;
                const testName = `hash(${seed}, ${value}, v${version})`;
                const gb = new GrowthBook({});
                result = gb._gbhash(seed, value, version);
                
                // Compare with tolerance for floating point, or both null
                const isMatch = (result === null && expected === null) ||
                    (result !== null && expected !== null && Math.abs(result - expected) < 0.001);
                
                if (isMatch) {
                    passed++;
                    process.stdout.write('✓');
                } else {
                    failed++;
                    process.stdout.write('✗');
                    failures.push({ name: testName, expected, actual: result });
                }
                
                // Skip the normal name extraction for this category
                continue;
            } else if (category === 'getBucketRange') {
                // getBucketRange tests: [[numVariations, coverage, weights], expectedRanges]
                const [[numVariations, coverage, weights], expected] = rest;
                const gb = new GrowthBook({});
                result = gb._getBucketRanges(numVariations, coverage, weights);
                
                // Compare ranges with tolerance
                let match = result.length === expected.length;
                if (match) {
                    for (let i = 0; i < result.length; i++) {
                        if (Math.abs(result[i][0] - expected[i][0]) > 0.001 ||
                            Math.abs(result[i][1] - expected[i][1]) > 0.001) {
                            match = false;
                            break;
                        }
                    }
                }
                
                if (match) {
                    passed++;
                    process.stdout.write('✓');
                } else {
                    failed++;
                    process.stdout.write('✗');
                    failures.push({ name, expected: JSON.stringify(expected), actual: JSON.stringify(result) });
                }
            } else if (category === 'chooseVariation') {
                // chooseVariation tests: [n, ranges, expected]
                const [n, ranges, expected] = rest;
                const gb = new GrowthBook({});
                result = gb._chooseVariation(n, ranges);
                
                if (result === expected) {
                    passed++;
                    process.stdout.write('✓');
                } else {
                    failed++;
                    process.stdout.write('✗');
                    failures.push({ name, expected, actual: result });
                }
            } else {
                // Skip tests for categories not yet implemented
                process.stdout.write('○');
            }
        } catch (error) {
            failed++;
            process.stdout.write('✗');
            failures.push({ name, error: error.message });
        }

        // Line break every 50 tests
        if ((passed + failed) % 50 === 0) process.stdout.write('\n');
    }

    console.log('\n');
    console.log(`Results: ${passed} passed, ${failed} failed, ${tests.length - passed - failed} skipped`);

    if (failures.length > 0 && failures.length <= 20) {
        console.log('\n❌ Failures:');
        failures.forEach(f => {
            console.log(`  • ${f.name}`);
            if (f.expected !== undefined) {
                console.log(`    Expected: ${f.expected}, Got: ${f.actual}`);
            }
            if (f.error) {
                console.log(`    Error: ${f.error}`);
            }
        });
    }

    return { passed, failed, total: tests.length };
}

// ================================================================
// Run All Tests
// ================================================================

const results = {};
const categories = ['evalCondition', 'hash', 'getBucketRange', 'chooseVariation', 'feature'];

for (const category of categories) {
    if (cases[category]) {
        results[category] = runTests(category, cases[category]);
    }
}

// Summary
console.log('\n' + '='.repeat(60));
console.log('📊 SUMMARY');
console.log('='.repeat(60));

let totalPassed = 0;
let totalFailed = 0;
let totalTests = 0;

for (const [category, result] of Object.entries(results)) {
    totalPassed += result.passed;
    totalFailed += result.failed;
    totalTests += result.total;
    
    const percentage = result.total > 0 ? ((result.passed / result.total) * 100).toFixed(1) : 0;
    console.log(`${category.padEnd(20)} ${result.passed}/${result.total} (${percentage}%)`);
}

console.log('─'.repeat(60));
console.log(`TOTAL: ${totalPassed}/${totalTests} tests passed (${((totalPassed/totalTests)*100).toFixed(1)}%)`);

if (totalFailed === 0) {
    console.log('\n✅ All tests passed!');
    process.exit(0);
} else {
    console.log(`\n⚠️  ${totalFailed} tests failed`);
    process.exit(1);
}

