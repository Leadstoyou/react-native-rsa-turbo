#import "RsaTurbo.h"
#import <React/RCTLog.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>

@implementation RsaTurbo
RCT_EXPORT_MODULE()

// RSA implementation using iOS Security framework

RCT_EXPORT_METHOD(generateKeys:(NSInteger)bits
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        // Generate RSA key pair
        NSMutableDictionary *keyPairAttr = [[NSMutableDictionary alloc] init];
        keyPairAttr[(__bridge NSString *)kSecAttrKeyType] = (__bridge NSString *)kSecAttrKeyTypeRSA;
        keyPairAttr[(__bridge NSString *)kSecAttrKeySizeInBits] = @(bits);
        keyPairAttr[(__bridge NSString *)kSecPrivateKeyAttrs] = @{
            (__bridge NSString *)kSecAttrIsPermanent: @NO,
        };
        
        SecKeyRef publicKey = NULL;
        SecKeyRef privateKey = NULL;
        
        OSStatus status = SecKeyGeneratePair((__bridge CFDictionaryRef)keyPairAttr, &publicKey, &privateKey);
        
        if (status != errSecSuccess) {
            reject(@"E_GEN", [NSString stringWithFormat:@"Failed to generate key pair: %d", (int)status], nil);
            return;
        }
        
        // Export public key to PEM format
        NSString *publicKeyPem = [self exportPublicKeyToPEM:publicKey];
        NSString *privateKeyPem = [self exportPrivateKeyToPEM:privateKey];
        
        NSDictionary *result = @{
            @"publicKey": publicKeyPem,
            @"privateKey": privateKeyPem
        };
        
        CFRelease(publicKey);
        CFRelease(privateKey);
        
        resolve(result);
    } @catch (NSException *exception) {
        reject(@"E_GEN", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(generate:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [self generateKeys:2048 resolver:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(encrypt:(NSString *)message
                  publicKey:(NSString *)publicKey
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        SecKeyRef pubKey = [self importPublicKeyFromPEM:publicKey];
        if (!pubKey) {
            reject(@"E_ENC", @"Failed to import public key", nil);
            return;
        }
        
        NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
        CFErrorRef error = NULL;
        
        NSData *encryptedData = (__bridge_transfer NSData *)SecKeyCreateEncryptedData(
            pubKey,
            kSecKeyAlgorithmRSAEncryptionPKCS1,
            (__bridge CFDataRef)messageData,
            &error
        );
        
        CFRelease(pubKey);
        
        if (!encryptedData) {
            reject(@"E_ENC", @"Encryption failed", nil);
            return;
        }
        
        NSString *base64Encrypted = [encryptedData base64EncodedStringWithOptions:0];
        resolve(base64Encrypted);
    } @catch (NSException *exception) {
        reject(@"E_ENC", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(decrypt:(NSString *)encoded
                  privateKey:(NSString *)privateKey
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        SecKeyRef privKey = [self importPrivateKeyFromPEM:privateKey];
        if (!privKey) {
            reject(@"E_DEC", @"Failed to import private key", nil);
            return;
        }
        
        NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:encoded options:0];
        if (!encryptedData) {
            reject(@"E_DEC", @"Invalid base64 encoded data", nil);
            return;
        }
        
        CFErrorRef error = NULL;
        NSData *decryptedData = (__bridge_transfer NSData *)SecKeyCreateDecryptedData(
            privKey,
            kSecKeyAlgorithmRSAEncryptionPKCS1,
            (__bridge CFDataRef)encryptedData,
            &error
        );
        
        CFRelease(privKey);
        
        if (!decryptedData) {
            reject(@"E_DEC", @"Decryption failed", nil);
            return;
        }
        
        NSString *decryptedMessage = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
        resolve(decryptedMessage);
    } @catch (NSException *exception) {
        reject(@"E_DEC", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(sign:(NSString *)message
                  privateKey:(NSString *)privateKey
                  algorithm:(NSString *)algorithm
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        SecKeyRef privKey = [self importPrivateKeyFromPEM:privateKey];
        if (!privKey) {
            reject(@"E_SIGN", @"Failed to import private key", nil);
            return;
        }
        
        NSString *alg = algorithm ?: @"SHA512withRSA";
        SecKeyAlgorithm secAlgorithm = [self getSecKeyAlgorithm:alg];
        
        NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
        CFErrorRef error = NULL;
        
        NSData *signatureData = (__bridge_transfer NSData *)SecKeyCreateSignature(
            privKey,
            secAlgorithm,
            (__bridge CFDataRef)messageData,
            &error
        );
        
        CFRelease(privKey);
        
        if (!signatureData) {
            reject(@"E_SIGN", @"Signing failed", nil);
            return;
        }
        
        NSString *base64Signature = [signatureData base64EncodedStringWithOptions:0];
        resolve(base64Signature);
    } @catch (NSException *exception) {
        reject(@"E_SIGN", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(verify:(NSString *)signature
                  message:(NSString *)message
                  publicKey:(NSString *)publicKey
                  algorithm:(NSString *)algorithm
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        SecKeyRef pubKey = [self importPublicKeyFromPEM:publicKey];
        if (!pubKey) {
            reject(@"E_VERIFY", @"Failed to import public key", nil);
            return;
        }
        
        NSString *alg = algorithm ?: @"SHA512withRSA";
        SecKeyAlgorithm secAlgorithm = [self getSecKeyAlgorithm:alg];
        
        NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
        NSData *signatureData = [[NSData alloc] initWithBase64EncodedString:signature options:0];
        
        if (!signatureData) {
            reject(@"E_VERIFY", @"Invalid base64 signature", nil);
            return;
        }
        
        CFErrorRef error = NULL;
        Boolean isValid = SecKeyVerifySignature(
            pubKey,
            secAlgorithm,
            (__bridge CFDataRef)messageData,
            (__bridge CFDataRef)signatureData,
            &error
        );
        
        CFRelease(pubKey);
        
        resolve(@(isValid));
    } @catch (NSException *exception) {
        reject(@"E_VERIFY", exception.reason, nil);
    }
}

// Keychain methods
RCT_EXPORT_METHOD(kcGenerateKeys:(NSString *)keyTag
                  bits:(NSInteger)bits
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        // Delete existing keys if they exist
        NSDictionary *deletePrivateQuery = @{
            (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassKey,
            (__bridge NSString *)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
        };
        SecItemDelete((__bridge CFDictionaryRef)deletePrivateQuery);
        
        NSString *publicKeyTag = [keyTag stringByAppendingString:@"-pub"];
        NSDictionary *deletePublicQuery = @{
            (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassKey,
            (__bridge NSString *)kSecAttrApplicationTag: [publicKeyTag dataUsingEncoding:NSUTF8StringEncoding],
        };
        SecItemDelete((__bridge CFDictionaryRef)deletePublicQuery);
        
        // Generate new key pair in keychain
        NSMutableDictionary *keyPairAttr = [[NSMutableDictionary alloc] init];
        keyPairAttr[(__bridge NSString *)kSecAttrKeyType] = (__bridge NSString *)kSecAttrKeyTypeRSA;
        keyPairAttr[(__bridge NSString *)kSecAttrKeySizeInBits] = @(bits);
        keyPairAttr[(__bridge NSString *)kSecPrivateKeyAttrs] = @{
            (__bridge NSString *)kSecAttrIsPermanent: @YES,
            (__bridge NSString *)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
        };
        keyPairAttr[(__bridge NSString *)kSecPublicKeyAttrs] = @{
            (__bridge NSString *)kSecAttrIsPermanent: @YES,
            (__bridge NSString *)kSecAttrApplicationTag: [[keyTag stringByAppendingString:@"-pub"] dataUsingEncoding:NSUTF8StringEncoding],
        };
        
        SecKeyRef publicKey = NULL;
        SecKeyRef privateKey = NULL;
        
        OSStatus status = SecKeyGeneratePair((__bridge CFDictionaryRef)keyPairAttr, &publicKey, &privateKey);
        
        if (status != errSecSuccess) {
            reject(@"E_KC_GEN", [NSString stringWithFormat:@"Failed to generate keychain key pair: %d", (int)status], nil);
            return;
        }
        
        // Export public key to PEM format
        NSString *publicKeyPem = [self exportPublicKeyToPEM:publicKey];
        
        NSDictionary *result = @{
            @"publicKey": publicKeyPem
        };
        
        CFRelease(publicKey);
        CFRelease(privateKey);
        
        resolve(result);
    } @catch (NSException *exception) {
        reject(@"E_KC_GEN", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(kcGenerate:(NSString *)keyTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [self kcGenerateKeys:keyTag bits:2048 resolver:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(kcEncrypt:(NSString *)message
                  keyTag:(NSString *)keyTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        SecKeyRef publicKey = [self getKeychainPublicKey:keyTag];
        if (!publicKey) {
            reject(@"E_KC_ENC", @"Failed to get keychain public key", nil);
            return;
        }
        
        NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
        CFErrorRef error = NULL;
        
        NSData *encryptedData = (__bridge_transfer NSData *)SecKeyCreateEncryptedData(
            publicKey,
            kSecKeyAlgorithmRSAEncryptionOAEPSHA256,
            (__bridge CFDataRef)messageData,
            &error
        );
        
        CFRelease(publicKey);
        
        if (!encryptedData) {
            reject(@"E_KC_ENC", @"Keychain encryption failed", nil);
            return;
        }
        
        NSString *base64Encrypted = [encryptedData base64EncodedStringWithOptions:0];
        resolve(base64Encrypted);
    } @catch (NSException *exception) {
        reject(@"E_KC_ENC", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(kcDecrypt:(NSString *)encoded
                  keyTag:(NSString *)keyTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        SecKeyRef privateKey = [self getKeychainPrivateKey:keyTag];
        if (!privateKey) {
            reject(@"E_KC_DEC", @"Failed to get keychain private key", nil);
            return;
        }
        
        NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:encoded options:0];
        if (!encryptedData) {
            reject(@"E_KC_DEC", @"Invalid base64 encoded data", nil);
            return;
        }
        
        CFErrorRef error = NULL;
        NSData *decryptedData = (__bridge_transfer NSData *)SecKeyCreateDecryptedData(
            privateKey,
            kSecKeyAlgorithmRSAEncryptionOAEPSHA256,
            (__bridge CFDataRef)encryptedData,
            &error
        );
        
        CFRelease(privateKey);
        
        if (!decryptedData) {
            reject(@"E_KC_DEC", @"Keychain decryption failed", nil);
            return;
        }
        
        NSString *decryptedMessage = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
        resolve(decryptedMessage);
    } @catch (NSException *exception) {
        reject(@"E_KC_DEC", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(kcSign:(NSString *)message
                  keyTag:(NSString *)keyTag
                  algorithm:(NSString *)algorithm
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        SecKeyRef privateKey = [self getKeychainPrivateKey:keyTag];
        if (!privateKey) {
            reject(@"E_KC_SIGN", @"Failed to get keychain private key", nil);
            return;
        }
        
        NSString *alg = algorithm ?: @"SHA512withRSA";
        SecKeyAlgorithm secAlgorithm = [self getSecKeyAlgorithm:alg];
        
        NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
        CFErrorRef error = NULL;
        
        NSData *signatureData = (__bridge_transfer NSData *)SecKeyCreateSignature(
            privateKey,
            secAlgorithm,
            (__bridge CFDataRef)messageData,
            &error
        );
        
        CFRelease(privateKey);
        
        if (!signatureData) {
            reject(@"E_KC_SIGN", @"Keychain signing failed", nil);
            return;
        }
        
        NSString *base64Signature = [signatureData base64EncodedStringWithOptions:0];
        resolve(base64Signature);
    } @catch (NSException *exception) {
        reject(@"E_KC_SIGN", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(kcVerify:(NSString *)signature
                  message:(NSString *)message
                  keyTag:(NSString *)keyTag
                  algorithm:(NSString *)algorithm
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        SecKeyRef publicKey = [self getKeychainPublicKey:keyTag];
        if (!publicKey) {
            reject(@"E_KC_VERIFY", @"Failed to get keychain public key", nil);
            return;
        }
        
        NSString *alg = algorithm ?: @"SHA512withRSA";
        SecKeyAlgorithm secAlgorithm = [self getSecKeyAlgorithm:alg];
        
        NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
        NSData *signatureData = [[NSData alloc] initWithBase64EncodedString:signature options:0];
        
        if (!signatureData) {
            reject(@"E_KC_VERIFY", @"Invalid base64 signature", nil);
            return;
        }
        
        CFErrorRef error = NULL;
        Boolean isValid = SecKeyVerifySignature(
            publicKey,
            secAlgorithm,
            (__bridge CFDataRef)messageData,
            (__bridge CFDataRef)signatureData,
            &error
        );
        
        CFRelease(publicKey);
        
        resolve(@(isValid));
    } @catch (NSException *exception) {
        reject(@"E_KC_VERIFY", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(kcDeletePrivateKey:(NSString *)keyTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        // Delete private key
        NSDictionary *deletePrivateQuery = @{
            (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassKey,
            (__bridge NSString *)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
        };
        OSStatus privateStatus = SecItemDelete((__bridge CFDictionaryRef)deletePrivateQuery);
        
        // Delete public key
        NSString *publicKeyTag = [keyTag stringByAppendingString:@"-pub"];
        NSDictionary *deletePublicQuery = @{
            (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassKey,
            (__bridge NSString *)kSecAttrApplicationTag: [publicKeyTag dataUsingEncoding:NSUTF8StringEncoding],
        };
        OSStatus publicStatus = SecItemDelete((__bridge CFDictionaryRef)deletePublicQuery);
        
        BOOL success = (privateStatus == errSecSuccess || privateStatus == errSecItemNotFound) &&
                      (publicStatus == errSecSuccess || publicStatus == errSecItemNotFound);
        resolve(@(success));
    } @catch (NSException *exception) {
        reject(@"E_KC_DEL", exception.reason, nil);
    }
}

// Helper methods
- (NSString *)exportPublicKeyToPEM:(SecKeyRef)publicKey {
    CFErrorRef error = NULL;
    NSData *keyData = (__bridge_transfer NSData *)SecKeyCopyExternalRepresentation(publicKey, &error);
    
    if (!keyData) {
        return nil;
    }
    
    // Convert to PEM format
    NSString *base64Key = [keyData base64EncodedStringWithOptions:64]; // 64 = line length 64
    return [NSString stringWithFormat:@"-----BEGIN PUBLIC KEY-----\n%@\n-----END PUBLIC KEY-----", base64Key];
}

- (NSString *)exportPrivateKeyToPEM:(SecKeyRef)privateKey {
    CFErrorRef error = NULL;
    NSData *keyData = (__bridge_transfer NSData *)SecKeyCopyExternalRepresentation(privateKey, &error);
    
    if (!keyData) {
        return nil;
    }
    
    // Convert to PEM format
    NSString *base64Key = [keyData base64EncodedStringWithOptions:64]; // 64 = line length 64
    return [NSString stringWithFormat:@"-----BEGIN PRIVATE KEY-----\n%@\n-----END PRIVATE KEY-----", base64Key];
}

- (SecKeyRef)importPublicKeyFromPEM:(NSString *)pemString {
    // Remove PEM headers and whitespace
    NSString *base64Key = [pemString stringByReplacingOccurrencesOfString:@"-----BEGIN PUBLIC KEY-----" withString:@""];
    base64Key = [base64Key stringByReplacingOccurrencesOfString:@"-----END PUBLIC KEY-----" withString:@""];
    base64Key = [base64Key stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    base64Key = [base64Key stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:base64Key options:0];
    if (!keyData) {
        return NULL;
    }
    
    CFErrorRef error = NULL;
    SecKeyRef publicKey = SecKeyCreateWithData((__bridge CFDataRef)keyData, (__bridge CFDictionaryRef)@{
        (__bridge NSString *)kSecAttrKeyType: (__bridge NSString *)kSecAttrKeyTypeRSA,
        (__bridge NSString *)kSecAttrKeyClass: (__bridge NSString *)kSecAttrKeyClassPublic,
    }, &error);
    
    return publicKey;
}

- (SecKeyRef)importPrivateKeyFromPEM:(NSString *)pemString {
    // Remove PEM headers and whitespace
    NSString *base64Key = [pemString stringByReplacingOccurrencesOfString:@"-----BEGIN PRIVATE KEY-----" withString:@""];
    base64Key = [base64Key stringByReplacingOccurrencesOfString:@"-----END PRIVATE KEY-----" withString:@""];
    base64Key = [base64Key stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    base64Key = [base64Key stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:base64Key options:0];
    if (!keyData) {
        return NULL;
    }
    
    CFErrorRef error = NULL;
    SecKeyRef privateKey = SecKeyCreateWithData((__bridge CFDataRef)keyData, (__bridge CFDictionaryRef)@{
        (__bridge NSString *)kSecAttrKeyType: (__bridge NSString *)kSecAttrKeyTypeRSA,
        (__bridge NSString *)kSecAttrKeyClass: (__bridge NSString *)kSecAttrKeyClassPrivate,
    }, &error);
    
    return privateKey;
}

- (SecKeyRef)getKeychainPublicKey:(NSString *)keyTag {
    NSString *publicKeyTag = [keyTag stringByAppendingString:@"-pub"];
    NSDictionary *query = @{
        (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassKey,
        (__bridge NSString *)kSecAttrApplicationTag: [publicKeyTag dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge NSString *)kSecAttrKeyType: (__bridge NSString *)kSecAttrKeyTypeRSA,
        (__bridge NSString *)kSecReturnRef: @YES,
    };
    
    SecKeyRef keyRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&keyRef);
    
    if (status != errSecSuccess) {
        return NULL;
    }
    
    return keyRef;
}

- (SecKeyRef)getKeychainPrivateKey:(NSString *)keyTag {
    NSDictionary *query = @{
        (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassKey,
        (__bridge NSString *)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge NSString *)kSecAttrKeyType: (__bridge NSString *)kSecAttrKeyTypeRSA,
        (__bridge NSString *)kSecReturnRef: @YES,
    };
    
    SecKeyRef keyRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&keyRef);
    
    if (status != errSecSuccess) {
        return NULL;
    }
    
    return keyRef;
}

- (SecKeyAlgorithm)getSecKeyAlgorithm:(NSString *)algorithm {
    if ([algorithm isEqualToString:@"SHA1withRSA"]) {
        return kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1;
    } else if ([algorithm isEqualToString:@"SHA256withRSA"]) {
        return kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256;
    } else if ([algorithm isEqualToString:@"SHA512withRSA"]) {
        return kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512;
    } else {
        return kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512; // Default
    }
}

@end
