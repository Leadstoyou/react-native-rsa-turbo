import RSATurbo, { type Algorithm } from './NativeRsaTurbo';

export const RSA = {
  generateKeys: (bits = 2048) => RSATurbo.generateKeys(bits),
  generate: () => RSATurbo.generate(),
  encrypt: RSATurbo.encrypt,
  decrypt: RSATurbo.decrypt,
  sign(
    message: string,
    privateKey: string,
    algorithm: Algorithm = 'SHA512withRSA'
  ) {
    return RSATurbo.sign(message, privateKey, algorithm);
  },

  verify(
    signatureB64: string,
    message: string,
    publicKeyPem: string,
    algorithm: Algorithm = 'SHA512withRSA'
  ) {
    return RSATurbo.verify(signatureB64, message, publicKeyPem, algorithm);
  },
};
export const RSAKeychain = {
  generateKeys: (keyTag: string, bits = 2048) =>
    RSATurbo.kcGenerateKeys(keyTag, bits),
  generate: (keyTag: string) => RSATurbo.kcGenerate(keyTag),
  encrypt: RSATurbo.kcEncrypt,
  decrypt: RSATurbo.kcDecrypt,
  sign: RSATurbo.kcSign,
  verify: RSATurbo.kcVerify,
  deletePrivateKey: RSATurbo.kcDeletePrivateKey,
};
export type { Algorithm };
