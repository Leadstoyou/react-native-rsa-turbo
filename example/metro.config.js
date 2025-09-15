// example/metro.config.js
const path = require('path');

// Patch Node.js v16 compatibility issues
const os = require('os');
if (!os.availableParallelism) {
  os.availableParallelism = () => os.cpus().length;
}

// Patch AbortSignal for Node.js v16 compatibility
if (typeof global.AbortSignal !== 'undefined' && global.AbortSignal.prototype) {
  if (!global.AbortSignal.prototype.throwIfAborted) {
    global.AbortSignal.prototype.throwIfAborted = function () {
      if (this.aborted) {
        throw new Error('The operation was aborted');
      }
    };
  }
}

// Fix ErrorUtils for React Native 0.79.6 + JavaScriptCore
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

/** @type {import('metro-config').MetroConfig} */
module.exports = (async () => {
  // ESM-only → dùng dynamic import
  const { withMetroConfig } = await import('react-native-monorepo-config');

  // monorepo root = .. (ra ngoài example/)
  const root = path.resolve(__dirname, '..');

  // Create a basic Metro config that's compatible with Node.js v16
  const config = {
    resolver: {
      alias: {
        'react-native-rsa-turbo': path.resolve(root, 'src'),
      },
      // Fix asset resolution issues
      assetExts: [
        'png',
        'jpg',
        'jpeg',
        'gif',
        'svg',
        'ttf',
        'otf',
        'woff',
        'woff2',
      ],
      sourceExts: ['js', 'jsx', 'ts', 'tsx', 'json'],
      // Fix missing-asset-registry-path error
      platforms: ['ios', 'android', 'native', 'web'],
      // Add resolverMainFields to fix asset registry path
      resolverMainFields: ['react-native', 'browser', 'main'],
    },
    watchFolders: [root],
    transformer: {
      getTransformOptions: async () => ({
        transform: {
          experimentalImportSupport: false,
          inlineRequires: true,
        },
      }),
      // Fix asset registry path resolution
      assetRegistryPath: 'react-native/Libraries/Image/AssetRegistry',
    },
    // Override maxWorkers to avoid os.availableParallelism() call
    maxWorkers: require('os').cpus().length,
  };

  // mở rộng config mặc định của Metro bằng cấu hình monorepo
  return withMetroConfig(config, {
    root, // đường dẫn tới monorepo root
    dirname: __dirname,
  });
})();
