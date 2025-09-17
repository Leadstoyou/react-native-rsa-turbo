// example/metro.config.js
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const path = require('path');

// Fix Node.js v16 compatibility issues
const os = require('os');
if (!os.availableParallelism) {
  os.availableParallelism = () => os.cpus().length;
}

// Fix abortSignal compatibility for Node.js v16
if (typeof global.AbortSignal === 'undefined') {
  global.AbortSignal = class AbortSignal {
    constructor() {
      this.aborted = false;
    }
    throwIfAborted() {
      if (this.aborted) {
        throw new Error('Operation was aborted');
      }
    }
  };
}

const defaultConfig = getDefaultConfig(__dirname);

/** @type {import('metro-config').MetroConfig} */
const config = {
  resolver: {
    alias: {
      'react-native-rsa-turbo': path.resolve(__dirname, '../src'),
      'react-native': path.resolve(__dirname, '../node_modules/react-native'),
    },
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
    platforms: ['ios', 'android', 'native', 'web'],
    resolverMainFields: ['react-native', 'browser', 'main'],
  },
  watchFolders: [
    path.resolve(__dirname, '..'),
    path.resolve(__dirname, '../node_modules'),
  ],
  transformer: {
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: false,
        inlineRequires: true,
      },
    }),
    assetRegistryPath: 'react-native/Libraries/Image/AssetRegistry',
  },
  // Override maxWorkers to avoid os.availableParallelism() call
  maxWorkers: os.cpus().length,
};

module.exports = mergeConfig(defaultConfig, config);
