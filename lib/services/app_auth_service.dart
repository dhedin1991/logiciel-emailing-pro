import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Protège l'accès au logiciel avec un identifiant + mot de passe choisis
/// par l'utilisateur, stockés chiffrés sur l'appareil (jamais en clair,
/// jamais envoyés nulle part). La session reste active d'un lancement à
/// l'autre tant que l'utilisateur ne se déconnecte pas explicitement.
class AppAuthService {
  static const _usernameKey = 'app_lock_username';
  static const _passwordHashKey = 'app_lock_password_hash';
  static const _saltKey = 'app_lock_salt';
  static const _sessionKey = 'app_lock_session_active';
  final _storage = const FlutterSecureStorage();

  Future<bool> hasCredentials() async {
    final username = await _storage.read(key: _usernameKey);
    return username != null && username.isNotEmpty;
  }

  Future<bool> isSessionActive() async {
    final active = await _storage.read(key: _sessionKey);
    return active == 'true';
  }

  Future<void> setSessionActive(bool active) async {
    await _storage.write(key: _sessionKey, value: active.toString());
  }

  Future<void> setCredentials(String username, String password) async {
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = _hash(password, salt);
    await _storage.write(key: _usernameKey, value: username.trim());
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _passwordHashKey, value: hash);
  }

  Future<bool> verify(String username, String password) async {
    final storedUsername = await _storage.read(key: _usernameKey);
    final storedHash = await _storage.read(key: _passwordHashKey);
    final salt = await _storage.read(key: _saltKey);
    if (storedUsername == null || storedHash == null || salt == null) return false;
    if (storedUsername != username.trim()) return false;
    return _hash(password, salt) == storedHash;
  }

  /// Déconnecte : redemandera l'identifiant/mot de passe au prochain accès,
  /// sans effacer l'identifiant/mot de passe déjà choisis.
  Future<void> logout() async {
    await setSessionActive(false);
  }

  Future<void> removeLock() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordHashKey);
    await _storage.delete(key: _saltKey);
    await setSessionActive(false);
  }

  String _hash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }
}
