module.exports = {
  extends: ['@react-native', 'prettier'],
  plugins: ['prettier'],
  rules: {
    'react/react-in-jsx-scope': 'off',
    'prettier/prettier': 'error',
    'curly': 'error',
  },
  ignorePatterns: ['node_modules/', 'lib/'],
};
