import { type TurboModule, TurboModuleRegistry } from 'react-native';

export type KeyPair = { privateKey?: string; publicKey: string };
export type Algorithm = 'SHA512withRSA' | 'SHA256withRSA';

export interface Spec extends TurboModule {
  generateKeys(bits: number): Promise<KeyPair>;
  generate(): Promise<KeyPair>; // = 2048
  encrypt(message: string, publicKey: string): Promise<string>;
  decrypt(encoded: string, privateKey: string): Promise<string>;
  sign(
    message: string,
    privateKey: string,
    algorithm?: Algorithm
  ): Promise<string>;
  verify(
    signature: string,
    message: string,
    publicKey: string,
    algorithm?: Algorithm
  ): Promise<boolean>;

  kcGenerateKeys(keyTag: string, bits: number): Promise<{ publicKey: string }>;
  kcGenerate(keyTag: string): Promise<{ publicKey: string }>;
  kcEncrypt(message: string, keyTag: string): Promise<string>;
  kcDecrypt(encoded: string, keyTag: string): Promise<string>;
  kcSign(
    message: string,
    keyTag: string,
    algorithm?: Algorithm
  ): Promise<string>;
  kcVerify(
    signature: string,
    message: string,
    keyTag: string,
    algorithm?: Algorithm
  ): Promise<boolean>;
  kcDeletePrivateKey(keyTag: string): Promise<boolean>;
}

// Try TurboModule first, fallback to Legacy module
let RSATurbo: Spec;

try {
  RSATurbo = TurboModuleRegistry.getEnforcing<Spec>('RSATurbo');
} catch (error) {
  console.warn('TurboModule RSATurbo not found, falling back to Legacy module');
  // Fallback to Legacy module
  const { NativeModules } = require('react-native');
  const LegacyRSATurbo = NativeModules.RsaTurbo;

  if (!LegacyRSATurbo) {
    throw new Error('Neither TurboModule nor Legacy module RSATurbo found');
  }

  // Create a compatibility layer for Legacy module
  RSATurbo = {
    generateKeys: (bits: number) => LegacyRSATurbo.generateKeys(bits),
    generate: () => LegacyRSATurbo.generate(),
    encrypt: (message: string, publicKey: string) =>
      LegacyRSATurbo.encrypt(message, publicKey),
    decrypt: (encoded: string, privateKey: string) =>
      LegacyRSATurbo.decrypt(encoded, privateKey),
    sign: (message: string, privateKey: string, algorithm?: Algorithm) =>
      LegacyRSATurbo.sign(message, privateKey, algorithm),
    verify: (
      signature: string,
      message: string,
      publicKey: string,
      algorithm?: Algorithm
    ) => LegacyRSATurbo.verify(signature, message, publicKey, algorithm),
    kcGenerateKeys: (keyTag: string, bits: number) =>
      LegacyRSATurbo.kcGenerateKeys(keyTag, bits),
    kcGenerate: (keyTag: string) => LegacyRSATurbo.kcGenerate(keyTag),
    kcEncrypt: (message: string, keyTag: string) =>
      LegacyRSATurbo.kcEncrypt(message, keyTag),
    kcDecrypt: (encoded: string, keyTag: string) =>
      LegacyRSATurbo.kcDecrypt(encoded, keyTag),
    kcSign: (message: string, keyTag: string, algorithm?: Algorithm) =>
      LegacyRSATurbo.kcSign(message, keyTag, algorithm),
    kcVerify: (
      signature: string,
      message: string,
      keyTag: string,
      algorithm?: Algorithm
    ) => LegacyRSATurbo.kcVerify(signature, message, keyTag, algorithm),
    kcDeletePrivateKey: (keyTag: string) =>
      LegacyRSATurbo.kcDeletePrivateKey(keyTag),
  } as Spec;
}

export default RSATurbo;
