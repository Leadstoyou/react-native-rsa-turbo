// CRITICAL: ErrorUtils MUST be set up before ANY other code runs
// Import the dedicated ErrorUtils setup file first
import './error-utils-setup';

// Import polyfills
import './polyfills';

import { AppRegistry } from 'react-native';
import App from './src/App';
import { name as appName } from './app.json';

AppRegistry.registerComponent(appName, () => App);
