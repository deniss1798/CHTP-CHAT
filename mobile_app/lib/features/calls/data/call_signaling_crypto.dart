import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Ephemeral X25519 + HKDF + AES-256-GCM для сигналинга WebRTC.
/// Медиа дополнительно защищено DTLS-SRTP внутри WebRTC (ключи не на сервере).
final class CallSignalingCrypto {
  CallSignalingCrypto._(this._keyPair);

  final SimpleKeyPair _keyPair;

  static final _x25519 = X25519();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _aes = AesGcm.with256bits();

  static Future<CallSignalingCrypto> generate() async {
    final kp = await _x25519.newKeyPair();
    return CallSignalingCrypto._(kp);
  }

  Future<String> publicKeyBase64() async {
    final data = await _keyPair.extract();
    final pk = data.publicKey;
    return base64Encode(pk.bytes);
  }

  Future<SecretKey> deriveSharedSecret(String remotePubB64) async {
    final raw = base64Decode(remotePubB64);
    final remote = SimplePublicKey(raw, type: KeyPairType.x25519);
    final shared = await _x25519.sharedSecretKey(
      keyPair: _keyPair,
      remotePublicKey: remote,
    );
    final ikm = await shared.extractBytes();
    return _hkdf.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: const <int>[],
      info: utf8.encode('messanger-call-signaling-v1'),
    );
  }

  Future<String> encryptString(SecretKey key, String plain) async {
    final box = await _aes.encrypt(
      utf8.encode(plain),
      secretKey: key,
    );
    return base64Encode(box.concatenation());
  }

  Future<String> decryptString(SecretKey key, String blobB64) async {
    final bytes = base64Decode(blobB64);
    final box = SecretBox.fromConcatenation(
      bytes,
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    final clear = await _aes.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  }
}
