// RSATurboModule.kt (rút gọn ý chính)
package com.rsaturbo

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.rsaturbo.NativeRsaTurboSpec
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.Arguments
import java.security.*
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import android.util.Base64

class RSATurboModule(reactContext: ReactApplicationContext) :
  NativeRsaTurboSpec(reactContext) {

  override fun getName() = "RSATurbo"

  // RSA thuần (PEM)
  override fun generateKeys(bits: Double, promise: Promise) {
    try {
      val kpg = KeyPairGenerator.getInstance("RSA")
      kpg.initialize(bits.toInt())
      val kp = kpg.generateKeyPair()
      val privPem = Pem.encodePrivate(kp.private)
      val pubPem  = Pem.encodePublic(kp.public)
      val result = Arguments.createMap()
      result.putString("publicKey", pubPem)
      result.putString("privateKey", privPem)
      promise.resolve(result)
    } catch (e: Exception) { promise.reject("E_GEN", e) }
  }

  override fun generate(promise: Promise) = generateKeys(2048.0, promise)

  override fun encrypt(message: String, publicKeyPem: String, promise: Promise) {
    try {
      val pub = Pem.decodePublic(publicKeyPem)
      val cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding")
      cipher.init(Cipher.ENCRYPT_MODE, pub)
      val out = Base64.encodeToString(cipher.doFinal(message.toByteArray()), Base64.NO_WRAP)
      promise.resolve(out)
    } catch (e: Exception) { promise.reject("E_ENC", e) }
  }

  override fun decrypt(encoded: String, privateKeyPem: String, promise: Promise) {
    try {
      val priv = Pem.decodePrivate(privateKeyPem)
      val cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding")
      cipher.init(Cipher.DECRYPT_MODE, priv)
      val out = String(cipher.doFinal(Base64.decode(encoded, Base64.NO_WRAP)))
      promise.resolve(out)
    } catch (e: Exception) { promise.reject("E_DEC", e) }
  }

  // ký/verify với SHA256/512
  override fun sign(message: String, privateKeyPem: String, algorithm: String?, promise: Promise) {
    try {
      val alg = algorithm ?: "SHA512withRSA"
      val priv = Pem.decodePrivate(privateKeyPem)
      val sig = Signature.getInstance(alg)
      sig.initSign(priv)
      sig.update(message.toByteArray())
      promise.resolve(Base64.encodeToString(sig.sign(), Base64.NO_WRAP))
    } catch (e: Exception) { promise.reject("E_SIGN", e) }
  }

  override fun verify(signatureB64: String, message: String, publicKeyPem: String, algorithm: String?, promise: Promise) {
    try {
      val alg = algorithm ?: "SHA512withRSA"
      val pub = Pem.decodePublic(publicKeyPem)
      val sig = Signature.getInstance(alg)
      sig.initVerify(pub)
      sig.update(message.toByteArray())
      promise.resolve(sig.verify(Base64.decode(signatureB64, Base64.NO_WRAP)))
    } catch (e: Exception) { promise.reject("E_VERIFY", e) }
  }

  // Keystore (kc*)
  override fun kcGenerateKeys(keyTag: String, bits: Double, promise: Promise) {
    try {
      val kpg = KeyPairGenerator.getInstance(
        KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore"
      )
      kpg.initialize(
        KeyGenParameterSpec.Builder(
          keyTag,
          KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT or
          KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        )
          .setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)
          .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1)
          .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_PKCS1)
          .setKeySize(bits.toInt())
          .build()
      )
      val kp = kpg.generateKeyPair()
      val pubPem = Pem.encodePublic(kp.public)
      val result = Arguments.createMap()
      result.putString("publicKey", pubPem)
      promise.resolve(result)
    } catch (e: Exception) { promise.reject("E_KC_GEN", e) }
  }

  override fun kcGenerate(keyTag: String, promise: Promise) = kcGenerateKeys(keyTag, 2048.0, promise)

  override fun kcEncrypt(message: String, keyTag: String, promise: Promise) {
    // TODO: Implement Android Keystore encryption using keyTag
    promise.reject("E_NOT_IMPL", "kcEncrypt not implemented yet")
  }

  override fun kcDecrypt(encoded: String, keyTag: String, promise: Promise) {
    // TODO: Implement Android Keystore decryption using keyTag
    promise.reject("E_NOT_IMPL", "kcDecrypt not implemented yet")
  }

  override fun kcSign(message: String, keyTag: String, algorithm: String?, promise: Promise) {
    // TODO: Implement Android Keystore signing using keyTag
    promise.reject("E_NOT_IMPL", "kcSign not implemented yet")
  }

  override fun kcVerify(signature: String, message: String, keyTag: String, algorithm: String?, promise: Promise) {
    // TODO: Implement Android Keystore verify using keyTag
    promise.reject("E_NOT_IMPL", "kcVerify not implemented yet")
  }

  override fun kcDeletePrivateKey(keyTag: String, promise: Promise) {
    // TODO: Implement Android Keystore private key deletion using keyTag
    promise.reject("E_NOT_IMPL", "kcDeletePrivateKey not implemented yet")
  }

  // kcEncrypt/kcDecrypt/kcSign/kcVerify/kcDeletePrivateKey tương tự:
  // - Lấy key bằng KeyStore.getInstance("AndroidKeyStore").getKey(keyTag, null)
  // - Dùng Cipher/Signature như ở trên
}
