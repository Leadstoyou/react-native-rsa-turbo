import RSATurbo from './NativeRsaTurbo';

export const RSA = {
  generateKeys: (bits = 2048) => RSATurbo.generateKeys(bits),
  generate: () => RSATurbo.generate(),
  encrypt: RSATurbo.encrypt,
  decrypt: RSATurbo.decrypt,
  sign: RSATurbo.sign,
  verify: RSATurbo.verify,
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
