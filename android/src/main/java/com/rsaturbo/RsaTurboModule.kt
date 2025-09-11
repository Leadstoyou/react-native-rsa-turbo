package com.rsaturbo

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.rsaturbo.NativeRsaTurboSpec
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.Arguments
import java.nio.charset.Charset
import java.security.*
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import android.util.Base64
import java.security.KeyStore

class RSATurboModule(reactContext: ReactApplicationContext) :
  NativeRsaTurboSpec(reactContext) {

  companion object {
    const val NAME = "RSATurbo"
    private const val CIPHER_RSA = "RSA/ECB/PKCS1Padding"
    private const val DEFAULT_SIG_ALG = "SHA512withRSA"
    private val UTF8: Charset = Charsets.UTF_8
  }

  override fun getName() = NAME

  // ===== PEM (thuần) =====

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
      val cipher = Cipher.getInstance(CIPHER_RSA)
      cipher.init(Cipher.ENCRYPT_MODE, pub)
      val out = Base64.encodeToString(cipher.doFinal(message.toByteArray(UTF8)), Base64.NO_WRAP)
      promise.resolve(out)
    } catch (e: Exception) { promise.reject("E_ENC", e) }
  }

  override fun decrypt(encoded: String, privateKeyPem: String, promise: Promise) {
    try {
      val priv = Pem.decodePrivate(privateKeyPem)
      val cipher = Cipher.getInstance(CIPHER_RSA)
      cipher.init(Cipher.DECRYPT_MODE, priv)
      val out = String(cipher.doFinal(Base64.decode(encoded, Base64.NO_WRAP)), UTF8)
      promise.resolve(out)
    } catch (e: Exception) { promise.reject("E_DEC", e) }
  }

  override fun sign(message: String, privateKeyPem: String, algorithm: String?, promise: Promise) {
    try {
      val alg = algorithm ?: DEFAULT_SIG_ALG
      val priv = Pem.decodePrivate(privateKeyPem)
      val sig = Signature.getInstance(alg)
      sig.initSign(priv)
      sig.update(message.toByteArray(UTF8))
      promise.resolve(Base64.encodeToString(sig.sign(), Base64.NO_WRAP))
    } catch (e: Exception) { promise.reject("E_SIGN", e) }
  }

  override fun verify(signatureB64: String, message: String, publicKeyPem: String, algorithm: String?, promise: Promise) {
    try {
      val alg = algorithm ?: DEFAULT_SIG_ALG
      val pub = Pem.decodePublic(publicKeyPem)
      val sig = Signature.getInstance(alg)
      sig.initVerify(pub)
      sig.update(message.toByteArray(UTF8))
      promise.resolve(sig.verify(Base64.decode(signatureB64, Base64.NO_WRAP)))
    } catch (e: Exception) { promise.reject("E_VERIFY", e) }
  }

  // ===== Android Keystore =====

  override fun kcGenerateKeys(keyTag: String, bits: Double, promise: Promise) {
    try {
      val kpg = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore")
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

  override fun kcGenerate(keyTag: String, promise: Promise) =
    kcGenerateKeys(keyTag, 2048.0, promise)

  private fun getKeyStoreEntryOrThrow(keyTag: String): KeyStore.PrivateKeyEntry {
    val ks = KeyStore.getInstance("AndroidKeyStore")
    ks.load(null)
    val entry = ks.getEntry(keyTag, null)
    if (entry !is KeyStore.PrivateKeyEntry) {
      throw IllegalStateException("No PrivateKeyEntry for tag: $keyTag")
    }
    return entry
  }

  override fun kcEncrypt(message: String, keyTag: String, promise: Promise) {
    try {
      val entry = getKeyStoreEntryOrThrow(keyTag)
      val pub = entry.certificate.publicKey
      val cipher = Cipher.getInstance(CIPHER_RSA)
      cipher.init(Cipher.ENCRYPT_MODE, pub)
      val enc = cipher.doFinal(message.toByteArray(UTF8))
      promise.resolve(Base64.encodeToString(enc, Base64.NO_WRAP))
    } catch (e: Exception) { promise.reject("E_KC_ENC", e) }
  }

  override fun kcDecrypt(encoded: String, keyTag: String, promise: Promise) {
    try {
      val entry = getKeyStoreEntryOrThrow(keyTag)
      val priv = entry.privateKey
      val cipher = Cipher.getInstance(CIPHER_RSA)
      cipher.init(Cipher.DECRYPT_MODE, priv)
      val dec = cipher.doFinal(Base64.decode(encoded, Base64.NO_WRAP))
      promise.resolve(String(dec, UTF8))
    } catch (e: Exception) { promise.reject("E_KC_DEC", e) }
  }

  override fun kcSign(message: String, keyTag: String, algorithm: String?, promise: Promise) {
    try {
      val entry = getKeyStoreEntryOrThrow(keyTag)
      val priv = entry.privateKey
      val alg = algorithm ?: DEFAULT_SIG_ALG
      val sig = Signature.getInstance(alg)
      sig.initSign(priv)
      sig.update(message.toByteArray(UTF8))
      val out = Base64.encodeToString(sig.sign(), Base64.NO_WRAP)
      promise.resolve(out)
    } catch (e: Exception) { promise.reject("E_KC_SIGN", e) }
  }

  override fun kcVerify(signature: String, message: String, keyTag: String, algorithm: String?, promise: Promise) {
    try {
      val entry = getKeyStoreEntryOrThrow(keyTag)
      val pub = entry.certificate.publicKey
      val alg = algorithm ?: DEFAULT_SIG_ALG
      val sig = Signature.getInstance(alg)
      sig.initVerify(pub)
      sig.update(message.toByteArray(UTF8))
      val ok = sig.verify(Base64.decode(signature, Base64.NO_WRAP))
      promise.resolve(ok)
    } catch (e: Exception) { promise.reject("E_KC_VERIFY", e) }
  }

  override fun kcDeletePrivateKey(keyTag: String, promise: Promise) {
    try {
      val ks = KeyStore.getInstance("AndroidKeyStore")
      ks.load(null)
      val exists = ks.containsAlias(keyTag)
      if (exists) ks.deleteEntry(keyTag)
      promise.resolve(true)
    } catch (e: Exception) { promise.reject("E_KC_DEL", e) }
  }
}
