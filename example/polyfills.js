// Enhanced polyfills for React Native 0.79.6 + Real Device
// This file must be loaded after ErrorUtils setup

console.log('Polyfills loaded - ErrorUtils available:', !!global.ErrorUtils);
if (global.ErrorUtils) {
  console.log('ErrorUtils methods:', {
    setGlobalHandler: typeof global.ErrorUtils.setGlobalHandler,
    getGlobalHandler: typeof global.ErrorUtils.getGlobalHandler,
    reportError: typeof global.ErrorUtils.reportError,
    reportFatalError: typeof global.ErrorUtils.reportFatalError,
  });
} else {
  console.error('ErrorUtils not available in polyfills!');
}

// Additional polyfills for real device compatibility
if (typeof global.console === 'undefined') {
  global.console = {
    log: () => {},
    error: () => {},
    warn: () => {},
    info: () => {},
  };
}

// Fix fetch if undefined
if (typeof global.fetch === 'undefined') {
  global.fetch = () => Promise.reject(new Error('fetch not available'));
}

// Fix other common issues for real device
if (typeof global.setTimeout === 'undefined') {
  global.setTimeout = (fn, delay) => {
    // Simple setTimeout polyfill
    return 0;
  };
}

if (typeof global.clearTimeout === 'undefined') {
  global.clearTimeout = () => {};
}

if (typeof global.setInterval === 'undefined') {
  global.setInterval = (fn, delay) => {
    // Simple setInterval polyfill
    return 0;
  };
}

if (typeof global.clearInterval === 'undefined') {
  global.clearInterval = () => {};
}

// Ensure process is available for real device
if (typeof global.process === 'undefined') {
  global.process = {
    env: { NODE_ENV: 'development' },
    nextTick: (fn) => setTimeout(fn, 0),
  };
}

console.log('Enhanced polyfills loaded successfully for real device');

// Additional polyfills for React Native 0.75.4 + JavaScriptCore
if (typeof global.console === 'undefined') {
  global.console = {
    log: () => {},
    error: () => {},
    warn: () => {},
    info: () => {},
  };
}

// Fix fetch if undefined
if (typeof global.fetch === 'undefined') {
  global.fetch = () => Promise.reject(new Error('fetch not available'));
}

// Fix other common issues
if (typeof global.setTimeout === 'undefined') {
  global.setTimeout = (fn, delay) => {
    // Simple setTimeout polyfill
    return 0;
  };
}

if (typeof global.clearTimeout === 'undefined') {
  global.clearTimeout = () => {};
}

if (typeof global.setInterval === 'undefined') {
  global.setInterval = (fn, delay) => {
    // Simple setInterval polyfill
    return 0;
  };
}

if (typeof global.clearInterval === 'undefined') {
  global.clearInterval = () => {};
}

// Additional React Native 0.75.4 specific polyfills
if (typeof global.require === 'undefined') {
  global.require = (module) => {
    console.warn('require() called but not available:', module);
    return {};
  };
}

// Fix potential issues with React Native's error boundary
if (typeof global.__DEV__ === 'undefined') {
  global.__DEV__ = true;
}

// Ensure process is available
if (typeof global.process === 'undefined') {
  global.process = {
    env: { NODE_ENV: 'development' },
    nextTick: (fn) => setTimeout(fn, 0),
  };
}

console.log('Polyfills loaded successfully for React Native 0.75.4');
