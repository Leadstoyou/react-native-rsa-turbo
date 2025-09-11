import { useEffect, useState } from 'react';
import { Text, View, StyleSheet } from 'react-native';
import { RSA } from 'react-native-rsa-turbo';

type KeyPair = {
  publicKey: string;
  privateKey?: string;
};

export default function App() {
  const [result, setResult] = useState<KeyPair | null>(null);

  useEffect(() => {
    RSA.generateKeys(2048)
      .then((keys: KeyPair) => {
        setResult(keys);
        console.log('Generated keys:', keys);
      })
      .catch((err: any) => {
        console.log('Error generating keys:', err);
      });
  }, []);

  return (
    <View style={styles.container}>
      <Text>Public Key:</Text>
      <Text numberOfLines={5} ellipsizeMode="tail">
        {result?.publicKey || 'Generating...'}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
  },
});
