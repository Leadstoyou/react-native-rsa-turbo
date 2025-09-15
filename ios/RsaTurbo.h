#import <React/RCTBridgeModule.h>
#import <Security/Security.h>

@interface RsaTurbo : NSObject <RCTBridgeModule>

// Helper methods
- (NSString *)exportPublicKeyToPEM:(SecKeyRef)publicKey;
- (NSString *)exportPrivateKeyToPEM:(SecKeyRef)privateKey;
- (SecKeyRef)importPublicKeyFromPEM:(NSString *)pemString;
- (SecKeyRef)importPrivateKeyFromPEM:(NSString *)pemString;
- (SecKeyRef)getKeychainPublicKey:(NSString *)keyTag;
- (SecKeyRef)getKeychainPrivateKey:(NSString *)keyTag;
- (SecKeyAlgorithm)getSecKeyAlgorithm:(NSString *)algorithm;

@end
