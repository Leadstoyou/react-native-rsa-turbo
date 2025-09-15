import { useCallback, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Button,
  Platform,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TextInput,
  View,
  Pressable,
} from 'react-native';
import { RSA, RSAKeychain, type Algorithm } from 'react-native-rsa-turbo';

// Import polyfills first
import '../polyfills';

type KeyPair = { publicKey: string; privateKey: string };

const DEFAULT_MESSAGE = 'Hello from RN + RSA Turbo!';
const DEFAULT_KEY_TAG = 'rsa-demo-key';
const algoOptions: Algorithm[] = ['SHA512withRSA', 'SHA256withRSA'];

function ExpandableMono({
  value,
  max = 600,
}: {
  value?: string;
  max?: number;
}) {
  const [open, setOpen] = useState(false);
  if (!value) {
    return <Text style={styles.mono}>—</Text>;
  }
  const tooLong = value.length > max;
  const shown = open || !tooLong ? value : value.slice(0, max) + ' …';
  return (
    <View>
      <Text selectable style={styles.mono}>
        {shown}
      </Text>
      {tooLong && (
        <Pressable onPress={() => setOpen((v) => !v)} style={styles.linkBtn}>
          <Text style={styles.linkText}>
            {open ? 'Show less' : 'Show more'}
          </Text>
        </Pressable>
      )}
    </View>
  );
}

export default function App() {
  // Common
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>('');
  const [message, setMessage] = useState(DEFAULT_MESSAGE);
  const [algo, setAlgo] = useState<Algorithm>('SHA512withRSA');
  const [bits, setBits] = useState('2048');

  // PEM states
  const [pemKeys, setPemKeys] = useState<KeyPair | null>(null);
  const [pemEnc, setPemEnc] = useState('');
  const [pemDec, setPemDec] = useState('');
  const [pemSig, setPemSig] = useState('');
  const [pemVerify, setPemVerify] = useState<boolean | null>(null);

  // Keystore (Android)
  const [keyTag, setKeyTag] = useState(DEFAULT_KEY_TAG);
  const [ksPub, setKsPub] = useState('');
  const [ksEnc, setKsEnc] = useState('');
  const [ksDec, setKsDec] = useState('');
  const [ksSig, setKsSig] = useState('');
  const [ksVerify, setKsVerify] = useState<boolean | null>(null);

  const isAndroid = Platform.OS === 'android';

  const resetPem = () => {
    setPemEnc('');
    setPemDec('');
    setPemSig('');
    setPemVerify(null);
  };
  const resetKs = () => {
    setKsEnc('');
    setKsDec('');
    setKsSig('');
    setKsVerify(null);
  };

  const runSafe = useCallback(async (fn: () => Promise<void>) => {
    setBusy(true);
    setError('');
    try {
      await fn();
    } catch (e: any) {
      setError(e?.message || String(e));
    } finally {
      setBusy(false);
    }
  }, []);

  // ===== PEM actions =====
  const onPemGenerate = () =>
    runSafe(async () => {
      resetPem();
      const b = parseInt(bits || '2048', 10) || 2048;
      const kp = (await RSA.generateKeys(b)) as KeyPair;
      setPemKeys(kp);
    });

  const onPemEncrypt = () =>
    runSafe(async () => {
      if (!pemKeys?.publicKey) {
        throw new Error('No PEM public key yet');
      }
      const enc = await RSA.encrypt(message, pemKeys.publicKey);
      setPemEnc(enc);
    });

  const onPemDecrypt = () =>
    runSafe(async () => {
      if (!pemKeys?.privateKey) {
        throw new Error('No PEM private key yet');
      }
      if (!pemEnc) {
        throw new Error('Nothing to decrypt. Encrypt first.');
      }
      const dec = await RSA.decrypt(pemEnc, pemKeys.privateKey);
      setPemDec(dec);
    });

  const onPemSign = () =>
    runSafe(async () => {
      if (!pemKeys?.privateKey) {
        throw new Error('No PEM private key yet');
      }
      const sig = await RSA.sign(message, pemKeys.privateKey, algo);
      setPemSig(sig);
    });

  const onPemVerify = () =>
    runSafe(async () => {
      if (!pemKeys?.publicKey) {
        throw new Error('No PEM public key yet');
      }
      if (!pemSig) {
        throw new Error('No signature yet. Sign first.');
      }
      const ok = await RSA.verify(pemSig, message, pemKeys.publicKey, algo);
      setPemVerify(ok);
    });

  // ===== Android Keystore actions =====
  const onKsGenerate = () =>
    runSafe(async () => {
      if (!isAndroid) {
        return;
      }
      resetKs();
      const b = parseInt(bits || '2048', 10) || 2048;
      const r = await RSAKeychain.generateKeys(keyTag, b);
      setKsPub(r?.publicKey || '');
    });

  const onKsEncrypt = () =>
    runSafe(async () => {
      if (!isAndroid) {
        return;
      }
      if (!ksPub) {
        throw new Error('No Keystore public key yet. Generate first.');
      }
      const enc = await RSAKeychain.encrypt(message, keyTag);
      setKsEnc(enc);
    });

  const onKsDecrypt = () =>
    runSafe(async () => {
      if (!isAndroid) {
        return;
      }
      if (!ksEnc) {
        throw new Error('Nothing to decrypt. Encrypt first.');
      }
      const dec = await RSAKeychain.decrypt(ksEnc, keyTag);
      setKsDec(dec);
    });

  const onKsSign = () =>
    runSafe(async () => {
      if (!isAndroid) {
        return;
      }
      if (!ksPub) {
        throw new Error('No Keystore key yet. Generate first.');
      }
      const sig = await RSAKeychain.sign(message, keyTag, algo);
      setKsSig(sig);
    });

  const onKsVerify = () =>
    runSafe(async () => {
      if (!isAndroid) {
        return;
      }
      if (!ksSig) {
        throw new Error('No signature yet. Sign first.');
      }
      const ok = await RSAKeychain.verify(ksSig, message, keyTag, algo);
      setKsVerify(ok);
    });

  const onKsDelete = () =>
    runSafe(async () => {
      if (!isAndroid) {
        return;
      }
      await RSAKeychain.deletePrivateKey(keyTag);
      setKsPub('');
      resetKs();
    });

  const AlgoSwitch = useMemo(
    () => (
      <View style={styles.row}>
        {algoOptions.map((a) => (
          <Pressable
            key={a}
            style={[
              styles.choice,
              algo === a ? styles.choiceActive : undefined,
            ]}
            onPress={() => setAlgo(a)}
          >
            <Text
              style={[
                styles.choiceText,
                algo === a ? styles.choiceTextActive : undefined,
              ]}
            >
              {a}
            </Text>
          </Pressable>
        ))}
      </View>
    ),
    [algo]
  );

  return (
    <SafeAreaView style={styles.root}>
      <StatusBar barStyle="dark-content" />
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>🔐 react-native-rsa-turbo — Full Demo</Text>

        {!!error && (
          <View style={styles.cardError}>
            <Text style={styles.cardTitle}>Error</Text>
            <Text selectable style={styles.mono}>
              {error}
            </Text>
          </View>
        )}

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Inputs</Text>
          <View style={styles.row}>
            <Text style={styles.label}>Message</Text>
            <TextInput
              style={styles.input}
              value={message}
              onChangeText={setMessage}
              placeholder="Message to encrypt/sign"
              multiline
            />
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Bits</Text>
            <TextInput
              style={styles.input}
              keyboardType="numeric"
              value={bits}
              onChangeText={setBits}
              placeholder="2048"
            />
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Algorithm</Text>
            {AlgoSwitch}
          </View>
          {isAndroid && (
            <View style={styles.row}>
              <Text style={styles.label}>Key Tag</Text>
              <TextInput
                style={styles.input}
                value={keyTag}
                onChangeText={setKeyTag}
                placeholder="rsa-demo-key"
              />
            </View>
          )}
        </View>

        {/* PEM Section */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>PEM (in-memory)</Text>
          <View style={styles.rowWrap}>
            <Button title="Generate Keys" onPress={onPemGenerate} />
            <Button title="Encrypt" onPress={onPemEncrypt} />
            <Button title="Decrypt" onPress={onPemDecrypt} />
            <Button title="Sign" onPress={onPemSign} />
            <Button title="Verify" onPress={onPemVerify} />
          </View>

          <Text style={styles.sub}>Public Key</Text>
          <ExpandableMono value={pemKeys?.publicKey} />

          <Text style={styles.sub}>Private Key</Text>
          <ExpandableMono value={pemKeys?.privateKey} />

          <Text style={styles.sub}>Encrypted (base64)</Text>
          <ExpandableMono value={pemEnc} />

          <Text style={styles.sub}>Decrypted</Text>
          <Text selectable style={styles.code}>
            {pemDec || '—'}
          </Text>

          <Text style={styles.sub}>Signature (base64)</Text>
          <ExpandableMono value={pemSig} />

          <Text style={styles.sub}>Verify</Text>
          <Text
            style={[
              styles.badge,
              pemVerify ? styles.badgeOk : styles.badgeFail,
            ]}
          >
            {pemVerify === null ? '—' : pemVerify ? 'VALID ✅' : 'INVALID ❌'}
          </Text>
        </View>

        {/* Android Keystore Section */}
        {isAndroid && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Android Keystore</Text>
            <View style={styles.rowWrap}>
              <Button title="Generate" onPress={onKsGenerate} />
              <Button title="Encrypt" onPress={onKsEncrypt} />
              <Button title="Decrypt" onPress={onKsDecrypt} />
              <Button title="Sign" onPress={onKsSign} />
              <Button title="Verify" onPress={onKsVerify} />
              <Button title="Delete Key" onPress={onKsDelete} />
            </View>

            <Text style={styles.sub}>Public Key</Text>
            <ExpandableMono value={ksPub} />

            <Text style={styles.sub}>Encrypted (base64)</Text>
            <ExpandableMono value={ksEnc} />

            <Text style={styles.sub}>Decrypted</Text>
            <Text selectable style={styles.code}>
              {ksDec || '—'}
            </Text>

            <Text style={styles.sub}>Signature (base64)</Text>
            <ExpandableMono value={ksSig} />

            <Text style={styles.sub}>Verify</Text>
            <Text
              style={[
                styles.badge,
                ksVerify ? styles.badgeOk : styles.badgeFail,
              ]}
            >
              {ksVerify === null ? '—' : ksVerify ? 'VALID ✅' : 'INVALID ❌'}
            </Text>
          </View>
        )}

        {busy && (
          <View style={styles.overlay}>
            <ActivityIndicator size="large" />
            <Text style={{ marginTop: 8 }}>Processing…</Text>
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#F7F7F7' },
  content: { padding: 16, rowGap: 12 },
  title: { fontSize: 20, fontWeight: '700', marginBottom: 4 },
  card: { backgroundColor: '#fff', borderRadius: 12, padding: 12, gap: 10 },
  cardError: {
    backgroundColor: '#ffe9e9',
    borderRadius: 12,
    padding: 12,
    gap: 8,
    borderWidth: 1,
    borderColor: '#ffbcbc',
  },
  cardTitle: { fontSize: 16, fontWeight: '600' },
  sub: { marginTop: 6, fontWeight: '600' },
  row: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  rowWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    alignItems: 'center',
  },
  label: { width: 90, color: '#374151' },
  input: {
    flex: 1,
    minHeight: 36,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderWidth: 1,
    borderColor: '#e5e7eb',
    borderRadius: 8,
    backgroundColor: '#fff',
  },
  mono: {
    fontFamily: Platform.select({ ios: 'Menlo', android: 'monospace' }),
    fontSize: 12,
    lineHeight: 16,
  },
  code: {
    fontFamily: Platform.select({ ios: 'Menlo', android: 'monospace' }),
    fontSize: 14,
  },
  badge: {
    alignSelf: 'flex-start',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 999,
    fontWeight: '700',
  },
  badgeOk: { backgroundColor: '#e6ffed', color: '#1a7f37' },
  badgeFail: { backgroundColor: '#ffe8e6', color: '#d1242f' },
  linkBtn: { paddingVertical: 4 },
  linkText: { color: '#2563eb', fontWeight: '600' },
  choice: {
    borderWidth: 1,
    borderColor: '#d1d5db',
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  choiceActive: { backgroundColor: '#eef2ff', borderColor: '#818cf8' },
  choiceText: { color: '#374151', fontWeight: '600' },
  choiceTextActive: { color: '#4f46e5' },
  overlay: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 20,
    alignSelf: 'center',
    padding: 10,
    backgroundColor: '#ffffffdd',
    borderRadius: 10,
    alignItems: 'center',
  },
});
