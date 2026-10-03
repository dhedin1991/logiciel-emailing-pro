import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Protège l'accès au logiciel avec un identifiant + mot de passe choisis
/// par l'utilisateur.
///
/// Le mot de passe est désormais redemandé obligatoirement à chaque
/// ouverture de l'application (aucune session persistante) : dès que
/// l'application est fermée puis relancée, l'écran de connexion réapparaît.
/// Seul l'identifiant reste mémorisé pour être pré-rempli et accélérer la
/// reconnexion.
class AppAuthService {
  static const _usernameKey = 'app_lock_username';
  static const _passwordHashKey = 'app_lock_password_hash';
  static const _saltKey = 'app_lock_salt';
  final _storage = const FlutterSecureStorage();

  /// Vrai si un identifiant/mot de passe ont déjà été créés.
  Future<bool> hasCredentials() async {
    final username = await _storage.read(key: _usernameKey);
    return username != null && username.isNotEmpty;
  }

  /// Identifiant mémorisé, pour le pré-remplir à l'écran de connexion.
  Future<String?> getUsername() async {
    return _storage.read(key: _usernameKey);
  }

  static const _algoKey = 'app_lock_algo';
  static const _failuresKey = 'app_lock_failures';
  static const _lockUntilKey = 'app_lock_until';
  static const _pbkdf2Iterations = 60000;
  static const _maxFreeAttempts = 5;

  Future<void> setCredentials(String username, String password) async {
    // Sel aléatoire + PBKDF2 (calcul volontairement lent : décourage les essais en masse).
    final rnd = Random.secure();
    final salt = base64.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    final hash = _pbkdf2(password, salt);
    await _storage.write(key: _usernameKey, value: username.trim());
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _passwordHashKey, value: hash);
    await _storage.write(key: _algoKey, value: 'pbkdf2');
    await _resetFailures();
  }

  /// Secondes restantes avant de pouvoir réessayer (0 = pas de blocage).
  Future<int> remainingLockSeconds() async {
    final raw = await _storage.read(key: _lockUntilKey);
    final until = raw == null ? null : DateTime.tryParse(raw);
    if (until == null) return 0;
    final left = until.difference(DateTime.now()).inSeconds;
    return left > 0 ? left : 0;
  }

  Future<void> _resetFailures() async {
    await _storage.delete(key: _failuresKey);
    await _storage.delete(key: _lockUntilKey);
  }

  /// Après 5 erreurs : blocage de 30 s, puis 60 s, 120 s... (plafonné à 15 min).
  Future<void> _registerFailure() async {
    final n = (int.tryParse(await _storage.read(key: _failuresKey) ?? '') ?? 0) + 1;
    await _storage.write(key: _failuresKey, value: '$n');
    if (n >= _maxFreeAttempts) {
      final seconds = min(900, 30 * (1 << min(n - _maxFreeAttempts, 5)));
      await _storage.write(
        key: _lockUntilKey,
        value: DateTime.now().add(Duration(seconds: seconds)).toIso8601String(),
      );
    }
  }

  Future<bool> _matches(String password) async {
    final storedHash = await _storage.read(key: _passwordHashKey);
    final salt = await _storage.read(key: _saltKey);
    if (storedHash == null || salt == null) return false;
    final algo = await _storage.read(key: _algoKey);
    if (algo == 'pbkdf2') return _pbkdf2(password, salt) == storedHash;
    // Ancien format (SHA-256 simple) : accepté une dernière fois puis converti.
    if (_legacyHash(password, salt) != storedHash) return false;
    final username = await _storage.read(key: _usernameKey) ?? '';
    await setCredentials(username, password);
    return true;
  }

  /// Vérifie l'identifiant + mot de passe (utilisé pour la création/mise à
  /// jour des identifiants).
  Future<bool> verify(String username, String password) async {
    if (await remainingLockSeconds() > 0) return false;
    final storedUsername = await _storage.read(key: _usernameKey);
    if (storedUsername == null || storedUsername != username.trim()) return false;
    final ok = await _matches(password);
    if (ok) {
      await _resetFailures();
    } else {
      await _registerFailure();
    }
    return ok;
  }

  /// Vérifie uniquement le mot de passe : utilisé à l'écran de connexion,
  /// où l'identifiant est déjà connu et affiché (pas ressaisi).
  Future<bool> verifyPassword(String password) async {
    if (await remainingLockSeconds() > 0) return false;
    final ok = await _matches(password);
    if (ok) {
      await _resetFailures();
    } else {
      await _registerFailure();
    }
    return ok;
  }

  /// Supprime complètement la protection (identifiant + mot de passe).
  Future<void> removeLock() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordHashKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _algoKey);
    await _resetFailures();
  }

  String _legacyHash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  /// PBKDF2-HMAC-SHA256 (RFC 2898), 32 octets de sortie.
  String _pbkdf2(String password, String salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final saltBytes = utf8.encode(salt);
    final block = <int>[...saltBytes, 0, 0, 0, 1];
    var u = hmac.convert(block).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < _pbkdf2Iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return base64.encode(result);
  }
}
