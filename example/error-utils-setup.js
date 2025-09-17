// error-utils-setup.js
// This file MUST be loaded before any other React Native code
// It sets up ErrorUtils in a bulletproof way

(function () {
  'use strict';

  console.log('Setting up ErrorUtils...');

  // Create global object if it doesn't exist
  if (typeof global === 'undefined') {
    console.warn('global object not available');
    return;
  }

  // Initialize ErrorUtils with all required methods
  global.ErrorUtils = {
    setGlobalHandler: function (handler) {
      console.log('ErrorUtils.setGlobalHandler called');
      global._globalErrorHandler = handler;
    },

    getGlobalHandler: function () {
      return global._globalErrorHandler || null;
    },

    reportError: function (error) {
      console.error('ErrorUtils.reportError:', error);
    },

    reportFatalError: function (error) {
      console.error('ErrorUtils.reportFatalError:', error);
    },
  };

  // Set up a default error handler
  try {
    global.ErrorUtils.setGlobalHandler(function (error, isFatal) {
      console.log('Global error caught:', error, 'isFatal:', isFatal);
      // Don't crash the app, just log
    });
    console.log('ErrorUtils setup completed successfully');
  } catch (e) {
    console.error('Failed to setup ErrorUtils:', e);
  }

  // Verify setup
  console.log('ErrorUtils verification:', {
    exists: !!global.ErrorUtils,
    setGlobalHandler: typeof global.ErrorUtils.setGlobalHandler,
    getGlobalHandler: typeof global.ErrorUtils.getGlobalHandler,
    reportError: typeof global.ErrorUtils.reportError,
    reportFatalError: typeof global.ErrorUtils.reportFatalError,
  });
})();
