import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/contact.dart';
import '../models/message_template.dart';
import '../models/signature.dart';
import 'contact_storage.dart';
import 'template_storage.dart';
import 'signature_storage.dart';
import 'contact_list_storage.dart';
import 'log_service.dart';

/// Sauvegarde locale automatique (filet de sécurité en plus de la synchro
/// cloud) : écrit périodiquement un instantané JSON des contacts, modèles,
/// signatures et listes dans le dossier de l'application, et ne garde que
/// les [_maxBackups] plus récentes copies pour ne pas accumuler de fichiers
/// indéfiniment. Entièrement local, ne dépend d'aucun service externe.
/// Fusionne un instantané de données (contacts/modèles/signatures, même
/// format que les sauvegardes locales et la synchro Wi-Fi) dans les données
/// actuelles de l'appareil — ajoute ce qui manque, n'écrase et ne supprime
/// jamais rien d'existant.
Future<void> mergeSyncData(Map<String, dynamic> data) async {
  final contactStorage = ContactStorage();
  final existingContacts = await contactStorage.loadContacts();
  final existingEmails = existingContacts.map((c) => c.email.toLowerCase()).toSet();
  for (final c in (data['contacts'] as List<dynamic>? ?? [])) {
    final contact = Contact.fromJson(c as Map<String, dynamic>);
    if (!existingEmails.contains(contact.email.toLowerCase())) {
      await contactStorage.addContact(contact);
    }
  }

  final templateStorage = TemplateStorage();
  final existingTemplateIds = (await templateStorage.loadTemplates()).map((t) => t.id).toSet();
  for (final t in (data['templates'] as List<dynamic>? ?? [])) {
    final template = MessageTemplate.fromJson(t as Map<String, dynamic>);
    if (!existingTemplateIds.contains(template.id)) {
      await templateStorage.addTemplate(template);
    }
  }

  final signatureStorage = SignatureStorage();
  final existingSignatureIds = (await signatureStorage.loadSignatures()).map((s) => s.id).toSet();
  for (final s in (data['signatures'] as List<dynamic>? ?? [])) {
    final signature = Signature.fromJson(s as Map<String, dynamic>);
    if (!existingSignatureIds.contains(signature.id)) {
      await signatureStorage.addSignature(signature);
    }
  }
}

/// Construit l'instantané JSON (mêmes clés que les sauvegardes locales)
/// des données actuellement sur l'appareil.
Future<Map<String, dynamic>> buildSyncSnapshot() async {
  final contacts = await ContactStorage().loadContacts();
  final templates = await TemplateStorage().loadTemplates();
  final signatures = await SignatureStorage().loadSignatures();
  final lists = await ContactListStorage().loadAll();
  return {
    'createdAt': DateTime.now().toIso8601String(),
    'contacts': contacts.map((c) => c.toJson()).toList(),
    'templates': templates.map((t) => t.toJson()).toList(),
    'signatures': signatures.map((s) => s.toJson()).toList(),
    'contactLists': lists.map((l) => l.toJson()).toList(),
  };
}

class LocalBackupService {
  static const _maxBackups = 5;
  static const _minIntervalHours = 24;

  Future<Directory> _backupDir() async {
    final dir = await getApplicationSupportDirectory();
    final backupDir = Directory('${dir.path}/backups');
    if (!await backupDir.exists()) await backupDir.create(recursive: true);
    return backupDir;
  }

  /// À appeler au démarrage de l'app : crée une sauvegarde si la dernière
  /// date de plus de 24h (ou s'il n'y en a jamais eu). Ne bloque jamais le
  /// démarrage en cas d'erreur (best-effort, silencieux).
  Future<void> backupIfNeeded() async {
    try {
      final dir = await _backupDir();
      final existing = await dir.list().where((f) => f.path.endsWith('.json')).toList();
      if (existing.isNotEmpty) {
        existing.sort((a, b) => b.path.compareTo(a.path));
        final lastFile = File(existing.first.path);
        final lastModified = await lastFile.lastModified();
        if (DateTime.now().difference(lastModified).inHours < _minIntervalHours) return;
      }
      await createBackupNow();
    } catch (_) {
      // Non bloquant : la sauvegarde locale ne doit jamais empêcher l'app de démarrer.
    }
  }

  /// Crée une sauvegarde immédiatement, quelle que soit la dernière date.
  Future<File> createBackupNow() async {
    final contacts = await ContactStorage().loadContacts();
    final templates = await TemplateStorage().loadTemplates();
    final signatures = await SignatureStorage().loadSignatures();
    final lists = await ContactListStorage().loadAll();

    final data = {
      'createdAt': DateTime.now().toIso8601String(),
      'contacts': contacts.map((c) => c.toJson()).toList(),
      'templates': templates.map((t) => t.toJson()).toList(),
      'signatures': signatures.map((s) => s.toJson()).toList(),
      'contactLists': lists.map((l) => l.toJson()).toList(),
    };

    final dir = await _backupDir();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/backup_$timestamp.json');
    await file.writeAsString(jsonEncode(data));
    await _pruneOldBackups(dir);
    await LogService().log('Sauvegarde locale créée (${contacts.length} contacts, ${templates.length} modèles, ${signatures.length} signatures)');
    return file;
  }

  Future<void> _pruneOldBackups(Directory dir) async {
    final files = await dir.list().where((f) => f.path.endsWith('.json')).toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    for (var i = _maxBackups; i < files.length; i++) {
      try {
        await File(files[i].path).delete();
      } catch (_) {}
    }
  }

  /// Liste les sauvegardes disponibles, la plus récente en premier.
  Future<List<File>> listBackups() async {
    final dir = await _backupDir();
    final files = await dir.list().where((f) => f.path.endsWith('.json')).map((f) => File(f.path)).toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Restaure une sauvegarde : ajoute les éléments manquants sans écraser
  /// les données actuelles (fusion, jamais de suppression).
  Future<void> restoreBackup(File file) async {
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    await mergeSyncData(data);
  }

  /// Exporte les données actuelles vers un fichier choisi par l'utilisateur
  /// (boîte de dialogue "Enregistrer sous") — pour l'envoyer ensuite vers
  /// un autre appareil par n'importe quel moyen déjà utilisé (e-mail,
  /// WhatsApp, Google Drive...), sans dépendre d'un réseau entre les deux
  /// appareils. Retourne false si l'utilisateur annule.
  Future<bool> exportToChosenLocation() async {
    final snapshot = await buildSyncSnapshot();
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(snapshot)));
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final path = await FilePicker.platform.saveFile(
      fileName: 'emailing-pro-sauvegarde-$timestamp.json',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return false;
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes);
    }
    await LogService().log('Sauvegarde exportée vers un fichier choisi par l\'utilisateur');
    return true;
  }

  /// Importe un fichier de sauvegarde choisi par l'utilisateur (reçu par
  /// e-mail, WhatsApp, Google Drive, clé USB...) et fusionne son contenu
  /// avec les données actuelles — jamais d'écrasement. Retourne false si
  /// l'utilisateur annule.
  Future<bool> importFromChosenFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return false;
    final content = utf8.decode(result.files.single.bytes!);
    final data = jsonDecode(content) as Map<String, dynamic>;
    await mergeSyncData(data);
    await LogService().log('Sauvegarde importée depuis un fichier choisi par l\'utilisateur');
    return true;
  }
}
