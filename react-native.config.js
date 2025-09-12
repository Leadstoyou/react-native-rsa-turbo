module.exports = {
  dependencies: {
    'react-native-rsa-turbo': {
      platforms: {
        android: {
          sourceDir: './android',
        },
        ios: {
          podspecPath: './react-native-rsa-turbo.podspec',
        },
      },
    },
  },
};
