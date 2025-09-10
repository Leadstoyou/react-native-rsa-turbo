// example/metro.config.js
const path = require('path');
const { getDefaultConfig } = require('@react-native/metro-config');

/** @type {import('metro-config').MetroConfig | Promise<import('metro-config').MetroConfig} */
module.exports = (async () => {
  // ESM-only → dùng dynamic import
  const { withMetroConfig } = await import('react-native-monorepo-config');

  // monorepo root = .. (ra ngoài example/)
  const root = path.resolve(__dirname, '..');

  // mở rộng config mặc định của Metro bằng cấu hình monorepo
  return withMetroConfig(getDefaultConfig(__dirname), {
    root, // đường dẫn tới monorepo root
    dirname: __dirname,
  });
})();
