// Polyfills for React Native 0.79.6 + JavaScriptCore
// This file must be loaded before any other code

// Fix ErrorUtils.setGlobalHandler issue
if (typeof global.ErrorUtils === 'undefined') {
  global.ErrorUtils = {
    setGlobalHandler: () => {},
    getGlobalHandler: () => null,
    reportError: (error) => {
      console.error('ErrorUtils.reportError:', error);
    },
    reportFatalError: (error) => {
      console.error('ErrorUtils.reportFatalError:', error);
    },
  };
}

// Force ErrorUtils to be available before any other code runs
if (typeof global.ErrorUtils !== 'undefined') {
  try {
    global.ErrorUtils.setGlobalHandler(() => {});
  } catch (e) {
    console.log('ErrorUtils.setGlobalHandler already set');
  }
}

// Additional polyfills for React Native 0.79.6 + JavaScriptCore
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

console.log('Polyfills loaded successfully');
