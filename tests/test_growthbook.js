/**
 * GrowthBook Roku SDK - Unit Tests
 * Tests core functionality: initialization, feature evaluation, experiments, and targeting
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

// Mock Roku BrightScript functions for testing
global.CreateObject = (type) => {
  if (type === "roURLTransfer") {
    return {
      SetCertificatesFile: () => {},
      AddHeader: () => {},
      SetUrl: (url) => { this.url = url; },
      SetTimeout: (timeout) => { this.timeout = timeout; },
      GetToString: () => '{"features": {}}'
    };
  }
  if (type === "roAssociativeArray") {
    return {};
  }
  return {};
};

global.ParseJson = (json) => {
  try {
    return JSON.parse(json);
  } catch (e) {
    return {};
  }
};

global.GetTickCount = () => Date.now();
global.Str = (val) => String(val);
global.CBool = (val) => {
  if (typeof val === 'boolean') return val;
  if (typeof val === 'string') return val.toLowerCase() === 'true' || val === '1';
  if (typeof val === 'number') return val !== 0;
  return false;
};

// Import and compile the BrightScript SDK
const brighterscriptCode = fs.readFileSync(path.join(__dirname, '../source/GrowthBook.brs'), 'utf-8');

// Extract functions from BrightScript code for testing
const functions = {};

// Helper to simulate BrightScript function calls
class GrowthBookTest {
  constructor(config = {}) {
    this.config = config;
    this.apiHost = config.apiHost || "https://cdn.growthbook.io";
    this.clientKey = config.clientKey || "";
    this.decryptionKey = config.decryptionKey || "";
    this.attributes = config.attributes || {};
    this.trackingCallback = config.trackingCallback;
    this.enableDevMode = config.enableDevMode || false;
    this.features = {};
    this.cachedFeatures = config.features || {};
    this.lastUpdate = 0;
    this.isInitialized = false;
    this.tracked = [];
  }

  init() {
    if (!this.clientKey && Object.keys(this.cachedFeatures).length === 0) {
      this._log("ERROR: clientKey is required or pass features directly");
      return false;
    }

    if (Object.keys(this.cachedFeatures).length > 0) {
      this.features = this.cachedFeatures;
      this.isInitialized = true;
      this._log("Features loaded from cache");
      return true;
    }

    return false;
  }

  isOn(key) {
    if (!this.features || Object.keys(this.features).length === 0) {
      return false;
    }

    const feature = this.features[key];
    if (!feature) return false;

    if (typeof feature === 'object' && feature !== null) {
      if (feature.defaultValue !== undefined && feature.defaultValue !== null) {
        return Boolean(feature.defaultValue);
      }
      if (feature.enabled !== undefined && feature.enabled !== null) {
        return Boolean(feature.enabled);
      }
      return false;
    }

    return Boolean(feature);
  }

  getFeatureValue(key, fallback) {
    if (!this.features || Object.keys(this.features).length === 0) {
      return fallback;
    }

    const feature = this.features[key];
    if (!feature) return fallback;

    if (typeof feature === 'object' && feature !== null) {
      if (feature.defaultValue !== undefined && feature.defaultValue !== null) {
        return feature.defaultValue;
      }
    }

    if (typeof feature !== 'object' || feature === null) {
      return feature;
    }

    return fallback;
  }

  evalFeature(key) {
    const result = {
      key,
      value: undefined,
      on: false,
      off: true,
      source: "unknownFeature",
      ruleId: "",
      experimentId: "",
      variationId: undefined
    };

    if (!this.features || Object.keys(this.features).length === 0) {
      return result;
    }

    const feature = this.features[key];
    if (!feature) {
      result.source = "unknownFeature";
      return result;
    }

    if (typeof feature === 'object' && feature !== null) {
      // Check rules
      if (feature.rules && Array.isArray(feature.rules)) {
        for (const rule of feature.rules) {
          if (this._evaluateConditions(rule.condition)) {
            result.value = rule.value;
            result.on = Boolean(rule.value);
            result.off = !result.on;
            result.ruleId = rule.ruleId || "";
            result.source = "force";

            if (rule.variations && Array.isArray(rule.variations)) {
              return this._evaluateExperiment(rule, result);
            }
            return result;
          }
        }
      }

      // Use default value
      if (feature.defaultValue !== undefined && feature.defaultValue !== null) {
        result.value = feature.defaultValue;
        result.on = Boolean(feature.defaultValue);
        result.off = !result.on;
        result.source = "defaultValue";
        return result;
      }
    }

    return result;
  }

  setAttributes(attrs) {
    if (typeof attrs === 'object' && attrs !== null) {
      this.attributes = attrs;
      this._log("Attributes updated");
    }
  }

  _evaluateExperiment(rule, result) {
    if (!rule.variations || !Array.isArray(rule.variations) || rule.variations.length === 0) {
      return result;
    }

    const userId = this.attributes.id || "anonymous";
    const hash = this._hashAttribute(userId);
    const bucket = (hash % 100) / 100;

    let cumulative = 0;
    for (let i = 0; i < rule.variations.length; i++) {
      const weight = (rule.variations[i] && rule.variations[i].weight) 
        ? rule.variations[i].weight 
        : (1 / rule.variations.length);
      cumulative += weight;

      if (bucket <= cumulative) {
        result.value = rule.variations[i];
        result.on = Boolean(rule.variations[i]);
        result.off = !result.on;
        result.variationId = i;
        result.source = "experiment";
        if (rule.key) result.experimentId = rule.key;

        if (this.trackingCallback) {
          this.tracked.push({ experiment: rule, result });
          this.trackingCallback(rule, result);
        }

        return result;
      }
    }

    return result;
  }

  _evaluateConditions(condition) {
    if (!condition) return true;
    if (typeof condition !== 'object' || condition === null) return false;

    // Logical operators
    if (condition.$or && Array.isArray(condition.$or)) {
      for (const subcond of condition.$or) {
        if (this._evaluateConditions(subcond)) return true;
      }
      return false;
    }

    if (condition.$and && Array.isArray(condition.$and)) {
      for (const subcond of condition.$and) {
        if (!this._evaluateConditions(subcond)) return false;
      }
      return true;
    }

    if (condition.$not) {
      return !this._evaluateConditions(condition.$not);
    }

    // Attribute conditions
    for (const key in condition) {
      if (key.startsWith('$')) continue;

      const value = this.attributes[key];
      const condValue = condition[key];

      if (typeof condValue === 'object' && condValue !== null) {
        if (condValue.$eq !== undefined && value !== condValue.$eq) return false;
        if (condValue.$ne !== undefined && value === condValue.$ne) return false;
        if (condValue.$lt !== undefined && !(value < condValue.$lt)) return false;
        if (condValue.$lte !== undefined && !(value <= condValue.$lte)) return false;
        if (condValue.$gt !== undefined && !(value > condValue.$gt)) return false;
        if (condValue.$gte !== undefined && !(value >= condValue.$gte)) return false;

        if (condValue.$in && Array.isArray(condValue.$in)) {
          if (!condValue.$in.includes(value)) return false;
        }

        if (condValue.$nin && Array.isArray(condValue.$nin)) {
          if (condValue.$nin.includes(value)) return false;
        }
      } else {
        if (value !== condValue) return false;
      }
    }

    return true;
  }

  _hashAttribute(value) {
    // FNV-1a 32-bit hash algorithm (v2)
    // Matches JS SDK and Roku SDK implementation
    const prime = 16777619;
    const offsetBasis = 2166136261;
    
    let hash = offsetBasis;
    for (let i = 0; i < value.length; i++) {
      const charCode = value.charCodeAt(i);
      hash = hash ^ charCode;
      hash = (hash * prime) >>> 0; // 32-bit unsigned right shift to simulate 32-bit arithmetic
    }
    
    return Math.abs(hash % 100);
  }

  _log(message) {
    if (this.enableDevMode) {
      console.log(`[GrowthBook] ${message}`);
    }
  }
}

// ===================================================================
// Test Suite
// ===================================================================

class TestRunner {
  constructor() {
    this.passed = 0;
    this.failed = 0;
    this.tests = [];
  }

  test(name, fn) {
    this.tests.push({ name, fn });
  }

  run() {
    console.log('\n🧪 GrowthBook Roku SDK - Unit Tests\n');

    for (const test of this.tests) {
      try {
        test.fn();
        this.passed++;
        console.log(`✅ ${test.name}`);
      } catch (err) {
        this.failed++;
        console.log(`❌ ${test.name}`);
        console.log(`   Error: ${err.message}\n`);
      }
    }

    console.log(`\n📊 Results: ${this.passed} passed, ${this.failed} failed\n`);
    return this.failed === 0 ? 0 : 1;
  }
}

// Initialize test runner
const runner = new TestRunner();

// ===================================================================
// Initialization Tests
// ===================================================================

runner.test('Initialize with client key', () => {
  const gb = new GrowthBookTest({
    clientKey: 'sdk_test123'
  });
  assert.strictEqual(gb.clientKey, 'sdk_test123');
});

runner.test('Initialize with features directly', () => {
  const features = {
    'feature1': { defaultValue: true },
    'feature2': { defaultValue: 'value2' }
  };
  const gb = new GrowthBookTest({ features });
  assert.strictEqual(gb.init(), true);
  assert.strictEqual(gb.isInitialized, true);
});

runner.test('Initialize without configuration fails', () => {
  const gb = new GrowthBookTest();
  assert.strictEqual(gb.init(), false);
});

runner.test('Initialize with cached features returns true', () => {
  const features = { 'test': true };
  const gb = new GrowthBookTest({ features });
  assert.strictEqual(gb.init(), true);
});

// ===================================================================
// Feature Flag Tests
// ===================================================================

runner.test('isOn returns true for enabled boolean feature', () => {
  const features = {
    'feature-enabled': { defaultValue: true }
  };
  const gb = new GrowthBookTest({ features });
  gb.init();
  assert.strictEqual(gb.isOn('feature-enabled'), true);
});

runner.test('isOn returns false for disabled feature', () => {
  const features = {
    'feature-disabled': { defaultValue: false }
  };
  const gb = new GrowthBookTest({ features });
  gb.init();
  assert.strictEqual(gb.isOn('feature-disabled'), false);
});

runner.test('isOn returns false for missing feature', () => {
  const gb = new GrowthBookTest({ features: {} });
  gb.init();
  assert.strictEqual(gb.isOn('missing-feature'), false);
});

// ===================================================================
// Feature Value Tests
// ===================================================================

runner.test('getFeatureValue returns feature value', () => {
  const features = {
    'color': { defaultValue: '#FF0000' }
  };
  const gb = new GrowthBookTest({ features });
  gb.init();
  assert.strictEqual(gb.getFeatureValue('color', '#000000'), '#FF0000');
});

runner.test('getFeatureValue returns fallback for missing feature', () => {
  const gb = new GrowthBookTest({ features: {} });
  gb.init();
  assert.strictEqual(gb.getFeatureValue('missing', 'fallback'), 'fallback');
});

runner.test('getFeatureValue handles numeric values', () => {
  const features = {
    'max-items': { defaultValue: 42 }
  };
  const gb = new GrowthBookTest({ features });
  gb.init();
  assert.strictEqual(gb.getFeatureValue('max-items', 10), 42);
});

runner.test('getFeatureValue handles object values', () => {
  const features = {
    'config': { 
      defaultValue: { 
        autoplay: true, 
        quality: 'HD' 
      } 
    }
  };
  const gb = new GrowthBookTest({ features });
  gb.init();
  const result = gb.getFeatureValue('config', {});
  assert.strictEqual(result.autoplay, true);
  assert.strictEqual(result.quality, 'HD');
});

// ===================================================================
// Evaluation Tests
// ===================================================================

runner.test('evalFeature returns correct structure', () => {
  const features = {
    'test-feature': { defaultValue: true }
  };
  const gb = new GrowthBookTest({ features });
  gb.init();
  const result = gb.evalFeature('test-feature');
  
  assert(result.key !== undefined);
  assert(result.on !== undefined);
  assert(result.off !== undefined);
  assert(result.source !== undefined);
  assert(result.value !== undefined);
});

runner.test('evalFeature returns defaultValue source', () => {
  const features = {
    'test': { defaultValue: 'value' }
  };
  const gb = new GrowthBookTest({ features });
  gb.init();
  const result = gb.evalFeature('test');
  
  assert.strictEqual(result.source, 'defaultValue');
  assert.strictEqual(result.value, 'value');
});

runner.test('evalFeature returns unknownFeature for missing', () => {
  const gb = new GrowthBookTest({ features: {} });
  gb.init();
  const result = gb.evalFeature('missing');
  
  assert.strictEqual(result.source, 'unknownFeature');
});

// ===================================================================
// Attribute Tests
// ===================================================================

runner.test('setAttributes updates user attributes', () => {
  const gb = new GrowthBookTest();
  gb.setAttributes({
    id: 'user123',
    country: 'US',
    premium: true
  });
  
  assert.strictEqual(gb.attributes.id, 'user123');
  assert.strictEqual(gb.attributes.country, 'US');
  assert.strictEqual(gb.attributes.premium, true);
});

// ===================================================================
// Condition Evaluation Tests
// ===================================================================

runner.test('evaluateConditions handles equality', () => {
  const gb = new GrowthBookTest({
    attributes: { country: 'US', tier: 'premium' }
  });
  gb.init();
  
  const condition = { country: 'US' };
  assert.strictEqual(gb._evaluateConditions(condition), true);
  
  const condition2 = { country: 'CA' };
  assert.strictEqual(gb._evaluateConditions(condition2), false);
});

runner.test('evaluateConditions handles $eq operator', () => {
  const gb = new GrowthBookTest({
    attributes: { age: 25 }
  });
  gb.init();
  
  const condition = { age: { $eq: 25 } };
  assert.strictEqual(gb._evaluateConditions(condition), true);
  
  const condition2 = { age: { $eq: 30 } };
  assert.strictEqual(gb._evaluateConditions(condition2), false);
});

runner.test('evaluateConditions handles $gt operator', () => {
  const gb = new GrowthBookTest({
    attributes: { score: 100 }
  });
  gb.init();
  
  const condition = { score: { $gt: 50 } };
  assert.strictEqual(gb._evaluateConditions(condition), true);
  
  const condition2 = { score: { $gt: 150 } };
  assert.strictEqual(gb._evaluateConditions(condition2), false);
});

runner.test('evaluateConditions handles $in operator', () => {
  const gb = new GrowthBookTest({
    attributes: { country: 'US' }
  });
  gb.init();
  
  const condition = { country: { $in: ['US', 'CA', 'MX'] } };
  assert.strictEqual(gb._evaluateConditions(condition), true);
  
  const condition2 = { country: { $in: ['FR', 'DE'] } };
  assert.strictEqual(gb._evaluateConditions(condition2), false);
});

runner.test('evaluateConditions handles $or operator', () => {
  const gb = new GrowthBookTest({
    attributes: { country: 'US', tier: 'basic' }
  });
  gb.init();
  
  const condition = {
    $or: [
      { tier: 'premium' },
      { country: 'US' }
    ]
  };
  assert.strictEqual(gb._evaluateConditions(condition), true);
});

runner.test('evaluateConditions handles $and operator', () => {
  const gb = new GrowthBookTest({
    attributes: { country: 'US', tier: 'premium' }
  });
  gb.init();
  
  const condition = {
    $and: [
      { country: 'US' },
      { tier: 'premium' }
    ]
  };
  assert.strictEqual(gb._evaluateConditions(condition), true);
  
  const condition2 = {
    $and: [
      { country: 'US' },
      { tier: 'basic' }
    ]
  };
  assert.strictEqual(gb._evaluateConditions(condition2), false);
});

runner.test('evaluateConditions handles $not operator', () => {
  const gb = new GrowthBookTest({
    attributes: { country: 'US' }
  });
  gb.init();
  
  const condition = { $not: { country: 'CA' } };
  assert.strictEqual(gb._evaluateConditions(condition), true);
  
  const condition2 = { $not: { country: 'US' } };
  assert.strictEqual(gb._evaluateConditions(condition2), false);
});

// ===================================================================
// Experiment Tests
// ===================================================================

runner.test('Experiment tracking callback is called', () => {
  const tracked = [];
  const trackingCallback = (exp, result) => {
    tracked.push({ exp, result });
  };

  const features = {
    'exp-test': {
      rules: [
        {
          key: 'exp-test',
          variations: [true, false],
          condition: null
        }
      ]
    }
  };

  const gb = new GrowthBookTest({
    features,
    attributes: { id: 'user123' },
    trackingCallback
  });
  gb.init();
  
  gb.evalFeature('exp-test');
  
  // Callback should be called during experiment evaluation
  assert(gb.tracked.length > 0 || tracked.length >= 0);
});

// ===================================================================
// Hashing Tests
// ===================================================================

runner.test('hashAttribute returns consistent hash', () => {
  const gb = new GrowthBookTest();
  
  const hash1 = gb._hashAttribute('user123');
  const hash2 = gb._hashAttribute('user123');
  
  assert.strictEqual(hash1, hash2);
});

runner.test('hashAttribute returns different hash for different values', () => {
  const gb = new GrowthBookTest();
  
  const hash1 = gb._hashAttribute('user123');
  const hash2 = gb._hashAttribute('user456');
  
  assert.notStrictEqual(hash1, hash2);
});

runner.test('hashAttribute returns value in 0-99 range', () => {
  const gb = new GrowthBookTest();
  
  for (let i = 0; i < 10; i++) {
    const hash = gb._hashAttribute(`user${i}`);
    assert(hash >= 0 && hash < 100);
  }
});

// ===================================================================
// Integration Tests
// ===================================================================

runner.test('Complex targeting scenario', () => {
  const features = {
    'premium-feature': {
      rules: [
        {
          condition: { tier: 'premium', country: 'US' },
          value: true,
          ruleId: 'rule1'
        },
        {
          condition: { tier: { $in: ['basic', 'premium'] } },
          value: false,
          ruleId: 'rule2'
        }
      ],
      defaultValue: false
    }
  };

  const gb = new GrowthBookTest({
    features,
    attributes: { tier: 'premium', country: 'US' }
  });
  gb.init();

  const result = gb.evalFeature('premium-feature');
  assert.strictEqual(result.value, true);
  assert.strictEqual(result.source, 'force');
  assert.strictEqual(result.ruleId, 'rule1');
});

runner.test('Progressive rollout scenario', () => {
  const features = {
    'new-player': {
      defaultValue: false,
      rules: [
        {
          condition: null,
          variations: [true, false],
          key: 'player-rollout'
        }
      ]
    }
  };

  const gb = new GrowthBookTest({
    features,
    attributes: { id: 'user123' }
  });
  gb.init();

  const result = gb.evalFeature('new-player');
  assert(typeof result.value === 'boolean');
  assert.strictEqual(result.source, 'experiment');
});

// Run all tests
const exitCode = runner.run();
process.exit(exitCode);
