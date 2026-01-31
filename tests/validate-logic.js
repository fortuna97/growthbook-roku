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
        this.savedGroups = config.savedGroups || {};
        this.forcedVariations = config.forcedVariations || {};
        this._evaluationStack = [];
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

        // Process all conditions - ALL must pass (AND logic at top level)
        for (const [attr, conditionValue] of Object.entries(condition)) {
            // Handle top-level logical operators
            if (attr === '$or') {
                if (!Array.isArray(conditionValue) || conditionValue.length === 0) {
                    continue;
                }
                if (!conditionValue.some(c => this._evaluateConditions(c))) {
                    return false;
                }
                continue;
            }

            if (attr === '$nor') {
                if (!Array.isArray(conditionValue)) continue;
                if (conditionValue.some(c => this._evaluateConditions(c))) {
                    return false;
                }
                continue;
            }

            if (attr === '$and') {
                if (!Array.isArray(conditionValue) || conditionValue.length === 0) {
                    continue;
                }
                if (!conditionValue.every(c => this._evaluateConditions(c))) {
                    return false;
                }
                continue;
            }

            if (attr === '$not') {
                if (this._evaluateConditions(conditionValue)) {
                    return false;
                }
                continue;
            }

            // Handle attribute conditions

            const value = this._getAttributeValue(attr);

            if (typeof conditionValue === 'object' && conditionValue !== null && !Array.isArray(conditionValue)) {
                // Operator conditions
                if ('$eq' in conditionValue && value !== conditionValue.$eq) return false;
                if ('$ne' in conditionValue && value === conditionValue.$ne) return false;
                if ('$lt' in conditionValue && !(value < conditionValue.$lt)) return false;
                if ('$lte' in conditionValue && !(value <= conditionValue.$lte)) return false;
                if ('$gt' in conditionValue && !(value > conditionValue.$gt)) return false;
                if ('$gte' in conditionValue && !(value >= conditionValue.$gte)) return false;
                
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
                        let itemAttrs;
                        let tempCond;
                        
                        if (typeof item === 'object' && item !== null && !Array.isArray(item)) {
                            // For objects, evaluate condition directly against item
                            itemAttrs = item;
                            tempCond = conditionValue.$elemMatch;
                        } else {
                            // For primitives, wrap in special "_" attribute
                            itemAttrs = { _: item };
                            tempCond = { _: conditionValue.$elemMatch };
                        }
                        
                        const tempGB = new GrowthBook({ attributes: itemAttrs, savedGroups: this.savedGroups });
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
                        const tempGB = new GrowthBook({ attributes: { _size: value.length }, savedGroups: this.savedGroups });
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

                if ('$inGroup' in conditionValue) {
                    const groupId = conditionValue.$inGroup;
                    if (typeof groupId !== 'string') return false;
                    const savedGroup = this.savedGroups[groupId];
                    if (!savedGroup) return false;
                    if (!Array.isArray(savedGroup)) return false;
                    if (!savedGroup.includes(value)) return false;
                }

                if ('$notInGroup' in conditionValue) {
                    const groupId = conditionValue.$notInGroup;
                    if (typeof groupId !== 'string') return false;
                    const savedGroup = this.savedGroups[groupId];
                    if (!savedGroup) return true; // Group not found, so not in group
                    if (!Array.isArray(savedGroup)) return false;
                    if (savedGroup.includes(value)) return false;
                }

                if ('$not' in conditionValue) {
                    // Negation operator on attribute value
                    const tempGB = new GrowthBook({ attributes: this.attributes, savedGroups: this.savedGroups });
                    const tempCond = { [attr]: conditionValue.$not };
                    if (tempGB._evaluateConditions(tempCond)) {
                        return false;
                    }
                }

                // Check for unknown operators (operators starting with $)
                const knownOps = ['$eq', '$ne', '$lt', '$lte', '$gt', '$gte', '$veq', '$vne', '$vlt', '$vlte', '$vgt', '$vgte', '$in', '$nin', '$exists', '$type', '$regex', '$elemMatch', '$size', '$all', '$inGroup', '$notInGroup', '$not'];
                let hasOperator = false;
                for (const key of Object.keys(conditionValue)) {
                    if (key.startsWith('$')) {
                        if (!knownOps.includes(key)) {
                            // Unknown operator - fail the condition
                            return false;
                        }
                        hasOperator = true;
                    }
                }
                
                // If no operators found, treat as direct equality
                if (!hasOperator) {
                    if (!this._deepEqual(value, conditionValue)) return false;
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
                    return null;
                }
            }
            return value === undefined ? null : value;
        }
        const val = this.attributes[attr];
        return val === undefined ? null : val;
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
        // Handle null/undefined - both null and undefined are considered equal
        if ((a === null || a === undefined) && (b === null || b === undefined)) return true;
        if (a === null || b === null || a === undefined || b === undefined) return false;
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

    evalFeature(key) {
        const result = {
            value: null,
            on: false,
            off: true,
            source: 'unknownFeature',
            ruleId: ''
        };

        if (!this.features || !this.features[key]) {
            return result;
        }

        // Check for cycles
        if (this._evaluationStack.includes(key)) {
            result.source = 'cyclicPrerequisite';
            return result;
        }

        this._evaluationStack.push(key);

        const feature = this.features[key];

        if (typeof feature === 'object' && feature !== null && !Array.isArray(feature)) {
            if (feature.rules) {
                for (const rule of feature.rules) {
                    // Check parent conditions (prerequisites)
                    if (rule.parentConditions) {
                        let parentsPassed = true;
                        for (const parent of rule.parentConditions) {
                            const parentResult = this.evalFeature(parent.id);
                            
                            // Propagate cyclic prerequisite
                            if (parentResult.source === 'cyclicPrerequisite') {
                                result.source = 'cyclicPrerequisite';
                                this._evaluationStack.pop();
                                return result;
                            }
                            
                            // Check if parent gate is satisfied
                            if (parent.gate && !parentResult.on) {
                                result.source = 'prerequisite';
                                this._evaluationStack.pop();
                                return result;
                            }
                            
                            // Check parent condition
                            if (parent.condition) {
                                const tempGb = new GrowthBook({
                                    attributes: { value: parentResult.value },
                                    savedGroups: this.savedGroups
                                });
                                if (!tempGb._evaluateConditions(parent.condition)) {
                                    result.source = 'prerequisite';
                                    this._evaluationStack.pop();
                                    return result;
                                }
                            }
                        }
                    }
                    
                    if (this._evaluateConditions(rule.condition)) {
                        if (rule.force !== undefined) {
                            // Check if force rule has coverage, range, filters, or hashVersion
                            if (rule.coverage !== undefined || rule.range || rule.filters || (rule.hashVersion && rule.hashVersion !== 1)) {
                                const hashAttribute = rule.hashAttribute || 'id';
                                let hashValue = this._getAttributeValue(hashAttribute);
                                if (hashValue !== null && hashValue !== '') {
                                    if (typeof hashValue !== 'string') {
                                        hashValue = String(hashValue);
                                    }
                                    const hashVersion = rule.hashVersion || 1;
                                    
                                    // Check filters (all must pass)
                                    if (rule.filters) {
                                        let passedFilters = true;
                                        for (const filter of rule.filters) {
                                            const filterSeed = filter.seed || key;
                                            const n = this._gbhash(filterSeed, hashValue, hashVersion);
                                            if (n === null) {
                                                passedFilters = false;
                                                break;
                                            }
                                            let inAnyRange = false;
                                            for (const range of filter.ranges) {
                                                if (this._inRange(n, range)) {
                                                    inAnyRange = true;
                                                    break;
                                                }
                                            }
                                            if (!inAnyRange) {
                                                passedFilters = false;
                                                break;
                                            }
                                        }
                                        if (!passedFilters) {
                                            continue;
                                        }
                                    } else {
                                        const seed = rule.seed || rule.key || key;
                                        const n = this._gbhash(seed, hashValue, hashVersion);
                                        if (n === null) {
                                            continue;
                                        }
                                        
                                        // Check range first (takes precedence over coverage)
                                        if (rule.range) {
                                            if (!this._inRange(n, rule.range)) {
                                                continue;
                                            }
                                        } else if (rule.coverage !== undefined) {
                                            // Check coverage only if no range (0 means skip everyone)
                                            if (rule.coverage === 0 || n > rule.coverage) {
                                                continue;
                                            }
                                        }
                                    }
                                } else {
                                    // Missing hashAttribute, skip rule
                                    continue;
                                }
                            }
                            result.value = rule.force;
                            result.on = !!result.value;
                            result.off = !result.on;
                            result.source = 'force';
                            result.ruleId = rule.ruleId || '';
                            this._evaluationStack.pop();
                            return result;
                        }
                        if (rule.variations) {
                            // Check forcedVariations first
                            if (this.forcedVariations && this.forcedVariations[key] !== undefined) {
                                const forcedIndex = this.forcedVariations[key];
                                if (forcedIndex >= 0 && forcedIndex < rule.variations.length) {
                                    result.value = rule.variations[forcedIndex];
                                    result.on = !!result.value;
                                    result.off = !result.on;
                                    result.source = 'experiment';
                                    result.ruleId = rule.ruleId || '';
                                    result.experiment = {
                                        key: rule.key || key,
                                        variations: rule.variations
                                    };
                                    this._evaluationStack.pop();
                                    return result;
                                }
                            }
                            
                            const expResult = this._evaluateExperiment(key, rule, result);
                            if (expResult.source === 'experiment') {
                                // Check if this variation has passthrough meta
                                if (rule.meta && expResult.variationIndex !== undefined) {
                                    const variationMeta = rule.meta[expResult.variationIndex];
                                    if (variationMeta && variationMeta.passthrough) {
                                        // Continue to next rule instead of returning
                                        continue;
                                    }
                                }
                                this._evaluationStack.pop();
                                return expResult;
                            }
                            // User excluded, continue to next rule
                        }
                    }
                }
            }
            // Empty object or has defaultValue
            result.value = feature.defaultValue !== undefined ? feature.defaultValue : null;
            result.on = !!result.value;
            result.off = !result.on;
            result.source = 'defaultValue';
        } else {
            result.value = feature;
            result.on = !!feature;
            result.off = !result.on;
        }

        this._evaluationStack.pop();
        return result;
    }

    _evaluateExperiment(featureKey, rule, result) {
        if (!rule.variations || rule.variations.length === 0) {
            return result;
        }

        const hashAttribute = rule.hashAttribute || 'id';
        let hashValue = this._getAttributeValue(hashAttribute);
        
        // Skip if required hashAttribute is missing
        if (hashValue === null || hashValue === '') {
            return result;
        }
        
        if (typeof hashValue !== 'string') {
            hashValue = String(hashValue);
        }

        const seed = rule.seed || rule.key || featureKey;
        const hashVersion = rule.hashVersion || 1;

        // Check namespace exclusion
        if (rule.namespace) {
            const [nsId, nsStart, nsEnd] = rule.namespace;
            const n = this._gbhash('__' + nsId, hashValue, hashVersion);
            if (n === null || n < nsStart || n >= nsEnd) {
                return result;
            }
        }

        const coverage = rule.coverage !== undefined ? rule.coverage : 1.0;

        const n = this._gbhash(seed, hashValue, hashVersion);
        if (n === null) return result;

        if (coverage < 1.0) {
            if (n > coverage) return result;
        }

        const ranges = rule.ranges || this._getBucketRanges(rule.variations.length, coverage, rule.weights);
        const variationIndex = this._chooseVariation(n, ranges);
        
        if (variationIndex === -1) return result;

        result.value = rule.variations[variationIndex];
        result.on = !!result.value;
        result.off = !result.on;
        result.source = 'experiment';
        result.ruleId = rule.ruleId || '';
        result.variationIndex = variationIndex;
        result.experiment = {
            key: rule.key || featureKey,
            variations: rule.variations,
            hashVersion: hashVersion
        };
        if (rule.condition) result.experiment.condition = rule.condition;
        if (ranges) result.experiment.ranges = ranges;

        return result;
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
                const [condition, attributes, expected, savedGroups] = rest;
                const gb = new GrowthBook({ attributes, savedGroups });
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
            } else if (category === 'feature') {
                const [context, featureKey, expected] = rest;
                const gb = new GrowthBook({
                    attributes: context.attributes,
                    features: context.features,
                    savedGroups: context.savedGroups,
                    forcedVariations: context.forcedVariations
                });
                result = gb.evalFeature(featureKey);
                
                // Compare key fields
                const match = result.value === expected.value &&
                             result.on === expected.on &&
                             result.off === expected.off &&
                             result.source === expected.source;
                
                if (match) {
                    passed++;
                    process.stdout.write('✓');
                } else {
                    failed++;
                    process.stdout.write('✗');
                    failures.push({ name, expected: JSON.stringify(expected), actual: JSON.stringify(result) });
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

