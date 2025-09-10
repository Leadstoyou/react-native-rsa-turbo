import { type TurboModule, TurboModuleRegistry } from 'react-native';

export type KeyPair = { private?: string; public: string };
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

  kcGenerateKeys(keyTag: string, bits: number): Promise<{ public: string }>;
  kcGenerate(keyTag: string): Promise<{ public: string }>;
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

export default TurboModuleRegistry.getEnforcing<Spec>('RSATurbo');
