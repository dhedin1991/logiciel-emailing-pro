import 'dart:convert';
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

  Future<void> setCredentials(String username, String password) async {
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = _hash(password, salt);
    await _storage.write(key: _usernameKey, value: username.trim());
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _passwordHashKey, value: hash);
  }

  /// Vérifie l'identifiant + mot de passe (utilisé pour la création/mise à
  /// jour des identifiants).
  Future<bool> verify(String username, String password) async {
    final storedUsername = await _storage.read(key: _usernameKey);
    final storedHash = await _storage.read(key: _passwordHashKey);
    final salt = await _storage.read(key: _saltKey);
    if (storedUsername == null || storedHash == null || salt == null) return false;
    if (storedUsername != username.trim()) return false;
    return _hash(password, salt) == storedHash;
  }

  /// Vérifie uniquement le mot de passe : utilisé à l'écran de connexion,
  /// où l'identifiant est déjà connu et affiché (pas ressaisi).
  Future<bool> verifyPassword(String password) async {
    final storedHash = await _storage.read(key: _passwordHashKey);
    final salt = await _storage.read(key: _saltKey);
    if (storedHash == null || salt == null) return false;
    return _hash(password, salt) == storedHash;
  }

  /// Supprime complètement la protection (identifiant + mot de passe).
  Future<void> removeLock() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordHashKey);
    await _storage.delete(key: _saltKey);
  }

  String _hash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }
}
