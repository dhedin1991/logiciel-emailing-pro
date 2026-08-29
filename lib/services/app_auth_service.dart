import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Protège l'accès au logiciel avec un identifiant + mot de passe choisis
/// par l'utilisateur.
///
/// L'identifiant/mot de passe (sensibles) restent dans le coffre chiffré
/// (flutter_secure_storage). L'état "session active" (pas sensible en soi,
/// juste un indicateur "déjà connecté") est stocké dans un simple fichier
/// local, plus fiable pour la persistance entre redémarrages sur Windows
/// que le coffre chiffré (bug connu de la bibliothèque sur cette plateforme).
class AppAuthService {
  static const _usernameKey = 'app_lock_username';
  static const _passwordHashKey = 'app_lock_password_hash';
  static const _saltKey = 'app_lock_salt';
  static const sessionDuration = Duration(days: 7);
  final _storage = const FlutterSecureStorage();

  Future<File> _sessionFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/session.json');
  }

  Future<bool> hasCredentials() async {
    final username = await _storage.read(key: _usernameKey);
    return username != null && username.isNotEmpty;
  }

  /// Vrai si une session a été ouverte et date de moins de 7 jours.
  Future<bool> isSessionActive() async {
    try {
      final file = await _sessionFile();
      if (!await file.exists()) return false;
      final content = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (content['active'] != true) return false;
      final startedAt = DateTime.tryParse(content['startedAt'] as String? ?? '');
      if (startedAt == null) return false;
      if (DateTime.now().difference(startedAt) > sessionDuration) {
        await setSessionActive(false);
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Date/heure à laquelle la session expirera (null si pas de session active).
  Future<DateTime?> sessionExpiresAt() async {
    try {
      final file = await _sessionFile();
      if (!await file.exists()) return null;
      final content = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final startedAt = DateTime.tryParse(content['startedAt'] as String? ?? '');
      if (startedAt == null) return null;
      return startedAt.add(sessionDuration);
    } catch (_) {
      return null;
    }
  }

  Future<void> setSessionActive(bool active) async {
    final file = await _sessionFile();
    final data = <String, dynamic>{'active': active};
    if (active) {
      data['startedAt'] = DateTime.now().toIso8601String();
    }
    await file.writeAsString(jsonEncode(data));
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
