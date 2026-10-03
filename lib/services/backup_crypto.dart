import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Le fichier est chiffré avec un mot de passe : il faut le saisir pour l'ouvrir.
class BackupPassphraseRequired implements Exception {
  @override
  String toString() => 'Cette sauvegarde est protégée par un mot de passe.';
}

class BackupWrongPassphrase implements Exception {
  @override
  String toString() => 'Mot de passe incorrect, ou fichier abîmé.';
}

/// Chiffrement des sauvegardes (AES-256-GCM).
///
/// - Sauvegardes automatiques : clé aléatoire gardée dans le coffre sécurisé de l'appareil.
/// - Fichiers exportés vers un autre appareil : clé dérivée d'un mot de passe (PBKDF2),
///   utilisable partout. Sans mot de passe, le fichier reste en clair (ancien format).
class BackupCrypto {
  static const _format = 'emailingpro-backup';
  static const _deviceKeyName = 'backup_device_key';
  static const _iterations = 100000;
  static const _storage = FlutterSecureStorage();

  static Uint8List _randomBytes(int n) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => rnd.nextInt(256)));
  }

  /// PBKDF2-HMAC-SHA256, 32 octets.
  static Uint8List _pbkdf2(String password, Uint8List salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return Uint8List.fromList(result);
  }

  static Future<Uint8List> _deviceKey() async {
    final stored = await _storage.read(key: _deviceKeyName);
    if (stored != null && stored.isNotEmpty) return base64.decode(stored);
    final key = _randomBytes(32);
    await _storage.write(key: _deviceKeyName, value: base64.encode(key));
    return key;
  }

  static Map<String, dynamic>? _envelope(String content) {
    try {
      final data = jsonDecode(content);
      if (data is Map<String, dynamic> && data['format'] == _format) return data;
    } catch (_) {}
    return null;
  }

  static bool isEncrypted(String content) => _envelope(content) != null;

  static bool needsPassphrase(String content) => _envelope(content)?['mode'] == 'passphrase';

  /// [passphrase] vide ou nul : clé de l'appareil (sauvegardes automatiques).
  static Future<String> encrypt(String plain, {String? passphrase}) async {
    final iv = _randomBytes(12);
    final usePass = passphrase != null && passphrase.isNotEmpty;
    final salt = usePass ? _randomBytes(16) : null;
    final key = usePass ? _pbkdf2(passphrase, salt!, _iterations) : await _deviceKey();
    final encrypter = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(utf8.encode(plain), iv: enc.IV(iv));
    return jsonEncode({
      'format': _format,
      'v': 1,
      'mode': usePass ? 'passphrase' : 'device',
      'iterations': _iterations,
      'salt': salt == null ? null : base64.encode(salt),
      'iv': base64.encode(iv),
      'data': base64.encode(encrypted.bytes),
    });
  }

  /// Rend le texte JSON d'origine. Un contenu non chiffré (ancien format) est renvoyé tel quel.
  static Future<String> decrypt(String content, {String? passphrase}) async {
    final env = _envelope(content);
    if (env == null) return content;
    final isPass = env['mode'] == 'passphrase';
    if (isPass && (passphrase == null || passphrase.isEmpty)) throw BackupPassphraseRequired();
    try {
      final iv = enc.IV(base64.decode(env['iv'] as String));
      final key = isPass
          ? _pbkdf2(passphrase!, base64.decode(env['salt'] as String), (env['iterations'] as int?) ?? _iterations)
          : await _deviceKey();
      final encrypter = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
      final bytes = encrypter.decryptBytes(enc.Encrypted(base64.decode(env['data'] as String)), iv: iv);
      return utf8.decode(bytes);
    } catch (_) {
      throw BackupWrongPassphrase();
    }
  }
}
