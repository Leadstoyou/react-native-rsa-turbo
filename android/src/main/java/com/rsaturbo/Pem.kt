package com.rsaturbo

import java.security.KeyFactory
import java.security.PrivateKey
import java.security.PublicKey
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.X509EncodedKeySpec
import android.util.Base64

object Pem {
    fun encodePrivate(privateKey: PrivateKey): String {
        val encoded = privateKey.encoded
        val b64 = Base64.encodeToString(encoded, Base64.NO_WRAP)
        return "-----BEGIN PRIVATE KEY-----\n" + b64 + "\n-----END PRIVATE KEY-----"
    }

    fun encodePublic(publicKey: PublicKey): String {
        val encoded = publicKey.encoded
        val b64 = Base64.encodeToString(encoded, Base64.NO_WRAP)
        return "-----BEGIN PUBLIC KEY-----\n" + b64 + "\n-----END PUBLIC KEY-----"
    }

    fun decodePrivate(pem: String): PrivateKey {
        val b64 = pem.replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replace("\n", "")
            .trim()
        val encoded = Base64.decode(b64, Base64.NO_WRAP)
        val keySpec = PKCS8EncodedKeySpec(encoded)
        val kf = KeyFactory.getInstance("RSA")
        return kf.generatePrivate(keySpec)
    }

    fun decodePublic(pem: String): PublicKey {
        val b64 = pem.replace("-----BEGIN PUBLIC KEY-----", "")
            .replace("-----END PUBLIC KEY-----", "")
            .replace("\n", "")
            .trim()
        val encoded = Base64.decode(b64, Base64.NO_WRAP)
        val keySpec = X509EncodedKeySpec(encoded)
        val kf = KeyFactory.getInstance("RSA")
        return kf.generatePublic(keySpec)
    }
}
