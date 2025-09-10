import { Text, View, StyleSheet } from 'react-native';
import { RSA } from 'react-native-rsa-turbo';

const result = await RSA.generateKeys(2048);

export default function App() {
  console.log('result', result.public);
  return (
    <View style={styles.container}>
      <Text>Result: {result.public}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
