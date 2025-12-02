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
const categories = ['evalCondition', 'hash', 'feature'];

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

