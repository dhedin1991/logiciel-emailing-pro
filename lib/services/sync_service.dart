import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/contact.dart';
import '../models/message_template.dart';
import '../models/signature.dart';
import 'contact_storage.dart';
import 'template_storage.dart';
import 'signature_storage.dart';

/// Synchronise contacts, modèles et signatures entre Windows et Android
/// via Supabase (gratuit). Les comptes e-mail et leurs jetons de connexion
/// ne sont JAMAIS synchronisés par ce service : chaque appareil doit se
/// reconnecter à Gmail séparément, pour ne jamais faire transiter de jeton
/// sensible par une base de données à accès partagé.
/// Traduit une exception technique (souvent illisible pour un utilisateur
/// non technique) en message clair. Les détails techniques bruts restent
/// disponibles via `error.toString()` pour les logs si besoin, mais ne
/// doivent jamais s'afficher tels quels à l'écran.
String friendlySyncError(Object error) {
  final message = error.toString();
  if (message.contains('SocketException') || message.contains('Failed host lookup')) {
    return 'Pas de connexion Internet, ou le serveur Supabase est introuvable (vérifiez votre réseau ou vos données mobiles).';
  }
  if (message.contains('TimeoutException')) {
    return 'Le serveur met trop de temps à répondre (connexion lente ou instable).';
  }
  if (message.contains('401') || message.contains('403')) {
    return 'Accès refusé par le serveur — la configuration de synchronisation doit être vérifiée.';
  }
  return 'Une erreur est survenue pendant la synchronisation. Réessayez dans quelques instants.';
}

class SyncService {
  static const _supabaseUrl = 'https://dgpdmiqobgrcszmjyuhi.supabase.co';
  static const _apiKey = 'sb_publishable_LCSAjO9CVdMIQ-hx0OlGZA_Z4bndveU';

  final _secureStorage = const FlutterSecureStorage();
  final _uuid = const Uuid();

  final _contactStorage = ContactStorage();
  final _templateStorage = TemplateStorage();
  final _signatureStorage = SignatureStorage();

  /// Le "code de synchronisation" : identifiant privé qui relie vos
  /// appareils entre eux. À entrer sur votre autre appareil pour lier
  /// les deux. Ne pas partager : quiconque le connaît peut lire/écrire
  /// vos contacts, modèles et signatures synchronisés.
  Future<String> getOrCreateSyncCode() async {
    var code = await _secureStorage.read(key: 'sync_code');
    if (code == null || code.isEmpty) {
      code = _uuid.v4();
      await _secureStorage.write(key: 'sync_code', value: code);
    }
    return code;
  }

  Future<void> setSyncCode(String code) async {
    await _secureStorage.write(key: 'sync_code', value: code.trim());
  }

  Future<void> _push(String dataType, dynamic payload) async {
    final syncCode = await getOrCreateSyncCode();
    final response = await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/sync_blobs'),
      headers: {
        'apikey': _apiKey,
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: jsonEncode({
        'sync_id': syncCode,
        'data_type': dataType,
        'payload': payload,
      }),
    );
    if (response.statusCode >= 300) {
      throw Exception('Échec de l\'envoi ($dataType) : ${response.body}');
    }
  }

  Future<dynamic> _pull(String dataType) async {
    final syncCode = await getOrCreateSyncCode();
    final response = await http.get(
      Uri.parse('$_supabaseUrl/rest/v1/sync_blobs'
          '?sync_id=eq.$syncCode&data_type=eq.$dataType&select=payload'),
      headers: {
        'apikey': _apiKey,
        'Authorization': 'Bearer $_apiKey',
      },
    );
    if (response.statusCode >= 300) {
      throw Exception('Échec de la récupération ($dataType) : ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    if (list.isEmpty) return null;
    return (list.first as Map<String, dynamic>)['payload'];
  }

  /// Envoie contacts, modèles et signatures de cet appareil vers le cloud
  /// (écrase ce qui s'y trouvait pour ces catégories).
  /// Vérifie que le projet Supabase est joignable et correctement
  /// configuré (utilisé par le centre de diagnostic). Retourne un message
  /// clair pour l'utilisateur plutôt qu'une exception technique brute.
  Future<String?> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/'),
        headers: {'apikey': _apiKey},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 500) {
        return null; // joignable (même un 401/404 prouve que le serveur répond)
      }
      return 'Le serveur a répondu avec une erreur (code ${response.statusCode}).';
    } catch (e) {
      return friendlySyncError(e);
    }
  }

  Future<void> pushAll() async {
    final contacts = await _contactStorage.loadContacts();
    final templates = await _templateStorage.loadTemplates();
    final signatures = await _signatureStorage.loadSignatures();

    await _push('contacts', contacts.map((c) => c.toJson()).toList());
    await _push('templates', templates.map((t) => t.toJson()).toList());
    await _push('signatures', signatures.map((s) => s.toJson()).toList());
    await _secureStorage.write(key: 'last_backup_at', value: DateTime.now().toIso8601String());
  }

  Future<DateTime?> lastBackupAt() async {
    final raw = await _secureStorage.read(key: 'last_backup_at');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<int> reminderFrequencyDays() async {
    final raw = await _secureStorage.read(key: 'backup_reminder_days');
    return int.tryParse(raw ?? '') ?? 7;
  }

  Future<void> setReminderFrequencyDays(int days) async {
    await _secureStorage.write(key: 'backup_reminder_days', value: days.toString());
  }

  /// Récupère contacts, modèles et signatures depuis le cloud et
  /// REMPLACE les données de cet appareil (à utiliser sur un nouvel
  /// appareil, ou pour revenir à la dernière version envoyée).
  Future<void> pullAll() async {
    final contactsRaw = await _pull('contacts');
    final templatesRaw = await _pull('templates');
    final signaturesRaw = await _pull('signatures');

    if (contactsRaw != null) {
      final contacts = (contactsRaw as List<dynamic>)
          .map((e) => Contact.fromJson(e as Map<String, dynamic>))
          .toList();
      await _contactStorage.saveContacts(contacts);
    }
    if (templatesRaw != null) {
      final templates = (templatesRaw as List<dynamic>)
          .map((e) => MessageTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      await _templateStorage.saveTemplates(templates);
    }
    if (signaturesRaw != null) {
      final signatures = (signaturesRaw as List<dynamic>)
          .map((e) => Signature.fromJson(e as Map<String, dynamic>))
          .toList();
      await _signatureStorage.saveSignatures(signatures);
    }
  }
}
