# React Native RSA Turbo

A high-performance RSA encryption/decryption library for React Native using TurboModules.

## Features

- 🔐 RSA key generation (2048, 4096 bits)
- 🔒 Encrypt/Decrypt messages
- ✍️ Digital signature and verification
- 🏪 Android Keystore integration
- ⚡ TurboModule for better performance
- 📱 Cross-platform (Android/iOS)

## Installation

### From GitHub
```bash
npm install git+https://github.com/Leadstoyou/react-native-rsa-turbo.git
```

### From npm (when published)
```bash
npm install react-native-rsa-turbo
```

## Usage

```tsx
import { RSA } from 'react-native-rsa-turbo';

// Generate RSA key pair
const keys = await RSA.generateKeys(2048);
console.log('Public key:', keys.publicKey);
console.log('Private key:', keys.privateKey);

// Encrypt/Decrypt
const message = 'Hello World';
const encrypted = await RSA.encrypt(message, keys.publicKey);
const decrypted = await RSA.decrypt(encrypted, keys.privateKey);

// Sign/Verify
const signature = await RSA.sign(message, keys.privateKey);
const isValid = await RSA.verify(signature, message, keys.publicKey);

// Android Keystore (Android only)
const keystoreKeys = await RSA.kcGenerateKeys('my-key-tag', 2048);
const keystoreEncrypted = await RSA.kcEncrypt(message, 'my-key-tag');
```

## API Reference

### Key Generation
- `generateKeys(bits: number): Promise<KeyPair>`
- `generate(): Promise<KeyPair>` (default 2048 bits)

### Encryption/Decryption
- `encrypt(message: string, publicKey: string): Promise<string>`
- `decrypt(encoded: string, privateKey: string): Promise<string>`

### Digital Signature
- `sign(message: string, privateKey: string, algorithm?: Algorithm): Promise<string>`
- `verify(signature: string, message: string, publicKey: string, algorithm?: Algorithm): Promise<boolean>`

### Android Keystore
- `kcGenerateKeys(keyTag: string, bits: number): Promise<KeyPair>`
- `kcEncrypt(message: string, keyTag: string): Promise<string>`
- `kcDecrypt(encoded: string, keyTag: string): Promise<string>`
- `kcSign(message: string, keyTag: string, algorithm?: Algorithm): Promise<string>`
- `kcVerify(signature: string, message: string, keyTag: string, algorithm?: Algorithm): Promise<boolean>`
- `kcDeletePrivateKey(keyTag: string): Promise<void>`

## Types

```tsx
type KeyPair = {
  publicKey: string;
  privateKey?: string;
};

type Algorithm = 'SHA512withRSA' | 'SHA256withRSA';
```

## Requirements

- React Native >= 0.60
- Android API 21+
- iOS 11+

## License

MIT

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request