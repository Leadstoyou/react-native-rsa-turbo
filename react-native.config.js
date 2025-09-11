module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: '../android/',
        packageImportPath: 'import com.rsaturbo.RsaTurboPackage;',
      },
      ios: {
        podspecPath: '../ios/react-native-rsa-turbo.podspec',
      },
    },
  },
};
