// ios/RSATurbo.mm
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTLog.h>
#import "NativeRsaTurboSpec.h" // <-- do codegen sinh ra, giữ nguyên tên file đã phát sinh

using namespace facebook;

// ======= Small DER helpers (enough for PKCS8/SPKI wrapping) =======

static NSData *DERLen(NSUInteger len) {
  if (len < 0x80) {
    uint8_t b = (uint8_t)len;
    return [NSData dataWithBytes:&b length:1];
  }
  // long form
  NSMutableData *m = [NSMutableData data];
  NSMutableData *bytes = [NSMutableData data];
  NSUInteger v = len;
  while (v > 0) { uint8_t b = (uint8_t)(v & 0xFF); [bytes insertBytes:&b length:1 atIndex:0]; v >>= 8; }
  uint8_t tag = 0x80 | (uint8_t)bytes.length;
  [m appendBytes:&tag length:1];
  [m appendData:bytes];
  return m;
}

static NSData *DERWrap(uint8_t tag, NSData *content) {
  NSMutableData *m = [NSMutableData dataWithCapacity:content.length + 8];
  [m appendBytes:&tag length:1];
  [m appendData:DERLen(content.length)];
  [m appendData:content];
  return m;
}

static NSData *DERNULL() {
  uint8_t n[2] = {0x05, 0x00};
  return [NSData dataWithBytes:n length:2];
}

static NSData *DERInt0() { // INTEGER 0
  uint8_t v[3] = {0x02, 0x01, 0x00};
  return [NSData dataWithBytes:v length:3];
}

// OID(1.2.840.113549.1.1.1) = rsaEncryption
static NSData *OID_RSA() {
  const uint8_t oid[] = {0x06,0x09,0x2a,0x86,0x48,0x86,0xf7,0x0d,0x01,0x01,0x01};
  return [NSData dataWithBytes:oid length:sizeof(oid)];
}

// AlgorithmIdentifier = SEQUENCE { OID rsaEncryption, NULL }
static NSData *AlgId_RSA() {
  NSMutableData *seq = [NSMutableData data];
  [seq appendData:OID_RSA()];
  [seq appendData:DERNULL()];
  return DERWrap(0x30, seq); // SEQUENCE
}

// PKCS#8 PrivateKeyInfo = SEQ { 0, AlgId, OCTETSTRING( RSAPrivateKey(der) ) }
static NSData *WrapPKCS8(NSData *rsaPKCS1PrivDER) {
  NSMutableData *body = [NSMutableData data];
  [body appendData:DERInt0()];
  [body appendData:AlgId_RSA()];
  [body appendData:DERWrap(0x04, rsaPKCS1PrivDER)]; // OCTET STRING
  return DERWrap(0x30, body); // SEQUENCE
}

// SubjectPublicKeyInfo = SEQ { AlgId, BIT STRING(0x00 || RSAPublicKey(der)) }
static NSData *WrapSPKI(NSData *rsaPKCS1PubDER) {
  NSMutableData *bit = [NSMutableData dataWithCapacity:1 + rsaPKCS1PubDER.length];
  uint8_t zero = 0x00; // unused bits=0
  [bit appendBytes:&zero length:1];
  [bit appendData:rsaPKCS1PubDER];
  NSMutableData *body = [NSMutableData data];
  [body appendData:AlgId_RSA()];
  [body appendData:DERWrap(0x03, bit)]; // BIT STRING
  return DERWrap(0x30, body); // SEQUENCE
}

static NSString *PEMEncode(NSString *header, NSData *der) {
  NSString *b64 = [der base64EncodedStringWithOptions:0]; // NO_WRAP như Android
  return [NSString stringWithFormat:@"-----BEGIN %@-----\n%@\n-----END %@-----", header, b64, header];
}

static NSData *PEMDecodeBody(NSString *pem) {
  NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSString *s = [[pem stringByReplacingOccurrencesOfString:@"-----BEGIN PUBLIC KEY-----" withString:@""]
                     stringByReplacingOccurrencesOfString:@"-----END PUBLIC KEY-----" withString:@""];
  s = [s stringByReplacingOccurrencesOfString:@"-----BEGIN PRIVATE KEY-----" withString:@""];
  s = [s stringByReplacingOccurrencesOfString:@"-----END PRIVATE KEY-----" withString:@""];
  s = [s stringByTrimmingCharactersInSet:ws];
  return [[NSData alloc] initWithBase64EncodedString:s options:0];
}

static BOOL DataLooksLikeSPKI(NSData *der) {
  // crude check: SEQ -> SEQ -> OID rsaEncryption present near start
  if (der.length < 16) return NO;
  const uint8_t *p = (const uint8_t *)der.bytes;
  // find OID bytes sequence
  const uint8_t pattern[] = {0x06,0x09,0x2a,0x86,0x48,0x86,0xf7,0x0d,0x01,0x01,0x01};
  for (NSUInteger i=0; i+sizeof(pattern)<=der.length; i++) {
    if (memcmp(p+i, pattern, sizeof(pattern))==0) return YES;
  }
  return NO;
}

// Build SecKey from PEM (PKCS8 private / SPKI public). Prefer SecItemImport (auto-detect)
static SecKeyRef SecKeyFromPEM(NSString *pem, BOOL isPrivate) {
  NSData *der = PEMDecodeBody(pem);
  if (!der) return nil;

  CFArrayRef items = NULL;
  NSDictionary *opt = @{
    (__bridge id)kSecImportExportPassphrase: @"",
  };
  OSStatus st = SecItemImport((__bridge CFDataRef)der, NULL, NULL, NULL, 0, (__bridge CFDictionaryRef)opt, NULL, &items);
  if (st == errSecSuccess && items && CFArrayGetCount(items) > 0) {
    CFDictionaryRef dict = (CFDictionaryRef)CFArrayGetValueAtIndex(items, 0);
    SecKeyRef key = (SecKeyRef)CFDictionaryGetValue(dict, kSecImportItemKey);
    if (key) CFRetain(key);
    CFRelease(items);
    return key;
  }
  if (items) CFRelease(items);

  // Fallback: SecKeyCreateWithData (when import fails)
  NSDictionary *attrs = @{
    (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeyClass: isPrivate ? (__bridge id)kSecAttrKeyClassPrivate : (__bridge id)kSecAttrKeyClassPublic,
  };
  SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)der, (__bridge CFDictionaryRef)attrs, NULL);
  return key;
}

static NSString *AlgStringOrDefault(NSString *alg) {
  return (alg && alg.length) ? alg : @"SHA512withRSA";
}

static SecKeyAlgorithm SigAlgFromString(NSString *algStr, BOOL forMessage) {
  if ([algStr isEqualToString:@"SHA256withRSA"]) {
    return forMessage ? kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256
                      : kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256;
  }
  // default SHA512
  return forMessage ? kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512
                    : kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA512;
}

static NSString *Base64NoWrap(NSData *d) {
  return [d base64EncodedStringWithOptions:0];
}

static NSData *Base64DecodeNoWrap(NSString *s) {
  return [[NSData alloc] initWithBase64EncodedString:s options:0];
}

// ======= Keychain helpers (kc*) =======

static SecKeyRef CopyPrivateKeyWithTag(NSData *tag) {
  NSDictionary *qry = @{
    (__bridge id)kSecClass: (__bridge id)kSecClassKey,
    (__bridge id)kSecAttrApplicationTag: tag,
    (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecReturnRef: @YES,
    (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPrivate,
  };
  SecKeyRef key = NULL;
  OSStatus st = SecItemCopyMatching((__bridge CFDictionaryRef)qry, (CFTypeRef *)&key);
  if (st != errSecSuccess) return nil;
  return key;
}

static NSDictionary *MakeResolveMap(NSString *pub, NSString *priv) {
  return @{@"publicKey": pub ?: [NSNull null], @"privateKey": priv ?: [NSNull null]};
}

// ================= Module =================

@interface RSATurbo : NSObject <NativeRsaTurboSpec>
@end

@implementation RSATurbo

RCT_EXPORT_MODULE(RSATurbo);

- (void)generateKeys:(double)bits
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject
{
  @try {
    NSDictionary *attrs = @{
      (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
      (__bridge id)kSecAttrKeySizeInBits: @( (int)bits ),
    };
    CFErrorRef err = NULL;
    SecKeyRef priv = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attrs, &err);
    if (!priv) { NSError *e = CFBridgingRelease(err); reject(@"E_GEN", e.localizedDescription, e); return; }
    SecKeyRef pub = SecKeyCopyPublicKey(priv);

    // export DER
    CFErrorRef err2 = NULL;
    NSData *privDERPKCS1 = (NSData *)CFBridgingRelease(SecKeyCopyExternalRepresentation(priv, &err2));
    if (!privDERPKCS1) { NSError *e = CFBridgingRelease(err2); CFRelease(pub); CFRelease(priv); reject(@"E_GEN", e.localizedDescription, e); return; }
    NSData *privPKCS8 = WrapPKCS8(privDERPKCS1);

    CFErrorRef err3 = NULL;
    NSData *pubDER = (NSData *)CFBridgingRelease(SecKeyCopyExternalRepresentation(pub, &err3));
    if (!pubDER) { NSError *e = CFBridgingRelease(err3); CFRelease(pub); CFRelease(priv); reject(@"E_GEN", e.localizedDescription, e); return; }

    // If not already SPKI, wrap as SPKI
    NSData *pubSPKI = DataLooksLikeSPKI(pubDER) ? pubDER : WrapSPKI(pubDER);

    NSString *privPEM = PEMEncode(@"PRIVATE KEY", privPKCS8);
    NSString *pubPEM  = PEMEncode(@"PUBLIC KEY",  pubSPKI);

    CFRelease(pub);
    CFRelease(priv);
    resolve(MakeResolveMap(pubPEM, privPEM));
  } @catch (NSException *ex) {
    reject(@"E_GEN", ex.reason, nil);
  }
}

- (void)generate:(RCTPromiseResolveBlock)resolve
          reject:(RCTPromiseRejectBlock)reject
{
  [self generateKeys:2048 resolve:resolve reject:reject];
}

- (void)encrypt:(NSString *)message
  publicKeyPem:(NSString *)publicKeyPem
        resolve:(RCTPromiseResolveBlock)resolve
         reject:(RCTPromiseRejectBlock)reject
{
  SecKeyRef pub = SecKeyFromPEM(publicKeyPem, NO);
  if (!pub) { reject(@"E_ENC", @"Invalid public key", nil); return; }
  NSData *plain = [message dataUsingEncoding:NSUTF8StringEncoding];
  CFErrorRef err = NULL;
  NSData *enc = (NSData *)CFBridgingRelease(
      SecKeyCreateEncryptedData(pub, kSecKeyAlgorithmRSAEncryptionPKCS1, (__bridge CFDataRef)plain, &err)
  );
  CFRelease(pub);
  if (!enc) { NSError *e = CFBridgingRelease(err); reject(@"E_ENC", e.localizedDescription, e); return; }
  resolve(Base64NoWrap(enc));
}

- (void)decrypt:(NSString *)encoded
  privateKeyPem:(NSString *)privateKeyPem
        resolve:(RCTPromiseResolveBlock)resolve
         reject:(RCTPromiseRejectBlock)reject
{
  SecKeyRef priv = SecKeyFromPEM(privateKeyPem, YES);
  if (!priv) { reject(@"E_DEC", @"Invalid private key", nil); return; }
  NSData *cipher = Base64DecodeNoWrap(encoded);
  CFErrorRef err = NULL;
  NSData *dec = (NSData *)CFBridgingRelease(
      SecKeyCreateDecryptedData(priv, kSecKeyAlgorithmRSAEncryptionPKCS1, (__bridge CFDataRef)cipher, &err)
  );
  CFRelease(priv);
  if (!dec) { NSError *e = CFBridgingRelease(err); reject(@"E_DEC", e.localizedDescription, e); return; }
  resolve([[NSString alloc] initWithData:dec encoding:NSUTF8StringEncoding]);
}

- (void)sign:(NSString *)message
 privateKeyPem:(NSString *)privateKeyPem
    algorithm:(NSString *)algorithm
      resolve:(RCTPromiseResolveBlock)resolve
       reject:(RCTPromiseRejectBlock)reject
{
  SecKeyRef priv = SecKeyFromPEM(privateKeyPem, YES);
  if (!priv) { reject(@"E_SIGN", @"Invalid private key", nil); return; }
  NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
  NSString *algStr = AlgStringOrDefault(algorithm);
  SecKeyAlgorithm alg = SigAlgFromString(algStr, YES);
  CFErrorRef err = NULL;
  NSData *sig = (NSData *)CFBridgingRelease(
      SecKeyCreateSignature(priv, alg, (__bridge CFDataRef)data, &err)
  );
  CFRelease(priv);
  if (!sig) { NSError *e = CFBridgingRelease(err); reject(@"E_SIGN", e.localizedDescription, e); return; }
  resolve(Base64NoWrap(sig));
}

- (void)verify:(NSString *)signatureB64
       message:(NSString *)message
   publicKeyPem:(NSString *)publicKeyPem
     algorithm:(NSString *)algorithm
       resolve:(RCTPromiseResolveBlock)resolve
        reject:(RCTPromiseRejectBlock)reject
{
  SecKeyRef pub = SecKeyFromPEM(publicKeyPem, NO);
  if (!pub) { reject(@"E_VERIFY", @"Invalid public key", nil); return; }
  NSData *sig = Base64DecodeNoWrap(signatureB64);
  NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
  NSString *algStr = AlgStringOrDefault(algorithm);
  SecKeyAlgorithm alg = SigAlgFromString(algStr, YES);
  CFErrorRef err = NULL;
  BOOL ok = SecKeyVerifySignature(pub, alg, (__bridge CFDataRef)data, (__bridge CFDataRef)sig, &err);
  CFRelease(pub);
  if (!ok && err) { NSError *e = CFBridgingRelease(err); reject(@"E_VERIFY", e.localizedDescription, e); return; }
  resolve(@(ok));
}

// ===== AndroidKeyStore equivalents on iOS: Keychain-backed keys (kc*) =====

- (void)kcGenerateKeys:(NSString *)keyTag
                 bits:(double)bits
               resolve:(RCTPromiseResolveBlock)resolve
                reject:(RCTPromiseRejectBlock)reject
{
  @try {
    NSData *tag = [keyTag dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attrs = @{
      (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
      (__bridge id)kSecAttrKeySizeInBits: @( (int)bits ),
      (__bridge id)kSecAttrIsPermanent: @YES,
      (__bridge id)kSecAttrApplicationTag: tag,
      (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock,
    };
    CFErrorRef err = NULL;
    SecKeyRef priv = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attrs, &err);
    if (!priv) { NSError *e = CFBridgingRelease(err); reject(@"E_KC_GEN", e.localizedDescription, e); return; }
    SecKeyRef pub = SecKeyCopyPublicKey(priv);

    CFErrorRef err2 = NULL;
    NSData *pubDER = (NSData *)CFBridgingRelease(SecKeyCopyExternalRepresentation(pub, &err2));
    if (!pubDER) { NSError *e = CFBridgingRelease(err2); CFRelease(pub); CFRelease(priv); reject(@"E_KC_GEN", e.localizedDescription, e); return; }
    NSData *pubSPKI = DataLooksLikeSPKI(pubDER) ? pubDER : WrapSPKI(pubDER);
    NSString *pubPEM = PEMEncode(@"PUBLIC KEY", pubSPKI);

    CFRelease(pub);
    CFRelease(priv);
    resolve(@{@"publicKey": pubPEM});
  } @catch (NSException *ex) {
    reject(@"E_KC_GEN", ex.reason, nil);
  }
}

- (void)kcGenerate:(NSString *)keyTag
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject
{
  [self kcGenerateKeys:keyTag bits:2048 resolve:resolve reject:reject];
}

- (void)kcEncrypt:(NSString *)message
           keyTag:(NSString *)keyTag
          resolve:(RCTPromiseResolveBlock)resolve
           reject:(RCTPromiseRejectBlock)reject
{
  NSData *tag = [keyTag dataUsingEncoding:NSUTF8StringEncoding];
  SecKeyRef priv = CopyPrivateKeyWithTag(tag);
  if (!priv) { reject(@"E_KC_ENC", @"Key not found", nil); return; }
  SecKeyRef pub = SecKeyCopyPublicKey(priv);
  NSData *plain = [message dataUsingEncoding:NSUTF8StringEncoding];
  CFErrorRef err = NULL;
  NSData *enc = (NSData *)CFBridgingRelease(
      SecKeyCreateEncryptedData(pub, kSecKeyAlgorithmRSAEncryptionPKCS1, (__bridge CFDataRef)plain, &err)
  );
  CFRelease(pub);
  CFRelease(priv);
  if (!enc) { NSError *e = CFBridgingRelease(err); reject(@"E_KC_ENC", e.localizedDescription, e); return; }
  resolve(Base64NoWrap(enc));
}

- (void)kcDecrypt:(NSString *)encoded
           keyTag:(NSString *)keyTag
          resolve:(RCTPromiseResolveBlock)resolve
           reject:(RCTPromiseRejectBlock)reject
{
  NSData *tag = [keyTag dataUsingEncoding:NSUTF8StringEncoding];
  SecKeyRef priv = CopyPrivateKeyWithTag(tag);
  if (!priv) { reject(@"E_KC_DEC", @"Key not found", nil); return; }
  NSData *cipher = Base64DecodeNoWrap(encoded);
  CFErrorRef err = NULL;
  NSData *dec = (NSData *)CFBridgingRelease(
      SecKeyCreateDecryptedData(priv, kSecKeyAlgorithmRSAEncryptionPKCS1, (__bridge CFDataRef)cipher, &err)
  );
  CFRelease(priv);
  if (!dec) { NSError *e = CFBridgingRelease(err); reject(@"E_KC_DEC", e.localizedDescription, e); return; }
  resolve([[NSString alloc] initWithData:dec encoding:NSUTF8StringEncoding]);
}

- (void)kcSign:(NSString *)message
        keyTag:(NSString *)keyTag
     algorithm:(NSString *)algorithm
       resolve:(RCTPromiseResolveBlock)resolve
        reject:(RCTPromiseRejectBlock)reject
{
  NSData *tag = [keyTag dataUsingEncoding:NSUTF8StringEncoding];
  SecKeyRef priv = CopyPrivateKeyWithTag(tag);
  if (!priv) { reject(@"E_KC_SIGN", @"Key not found", nil); return; }
  NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
  NSString *algStr = AlgStringOrDefault(algorithm);
  SecKeyAlgorithm alg = SigAlgFromString(algStr, YES);
  CFErrorRef err = NULL;
  NSData *sig = (NSData *)CFBridgingRelease(
      SecKeyCreateSignature(priv, alg, (__bridge CFDataRef)data, &err)
  );
  CFRelease(priv);
  if (!sig) { NSError *e = CFBridgingRelease(err); reject(@"E_KC_SIGN", e.localizedDescription, e); return; }
  resolve(Base64NoWrap(sig));
}

- (void)kcVerify:(NSString *)signatureB64
         message:(NSString *)message
          keyTag:(NSString *)keyTag
       algorithm:(NSString *)algorithm
         resolve:(RCTPromiseResolveBlock)resolve
          reject:(RCTPromiseRejectBlock)reject
{
  NSData *tag = [keyTag dataUsingEncoding:NSUTF8StringEncoding];
  SecKeyRef priv = CopyPrivateKeyWithTag(tag);
  if (!priv) { reject(@"E_KC_VERIFY", @"Key not found", nil); return; }
  SecKeyRef pub = SecKeyCopyPublicKey(priv);
  NSData *sig = Base64DecodeNoWrap(signatureB64);
  NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
  NSString *algStr = AlgStringOrDefault(algorithm);
  SecKeyAlgorithm alg = SigAlgFromString(algStr, YES);
  CFErrorRef err = NULL;
  BOOL ok = SecKeyVerifySignature(pub, alg, (__bridge CFDataRef)data, (__bridge CFDataRef)sig, &err);
  CFRelease(pub);
  CFRelease(priv);
  if (!ok && err) { NSError *e = CFBridgingRelease(err); reject(@"E_KC_VERIFY", e.localizedDescription, e); return; }
  resolve(@(ok));
}

- (void)kcDeletePrivateKey:(NSString *)keyTag
                   resolve:(RCTPromiseResolveBlock)resolve
                    reject:(RCTPromiseRejectBlock)reject
{
  NSData *tag = [keyTag dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *qry = @{
    (__bridge id)kSecClass: (__bridge id)kSecClassKey,
    (__bridge id)kSecAttrApplicationTag: tag,
    (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
  };
  OSStatus st = SecItemDelete((__bridge CFDictionaryRef)qry);
  resolve(@(st == errSecSuccess || st == errSecItemNotFound));
}

@end
