import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/email_draft.dart';
import 'trash_service.dart';

class DraftStorage {
  static const _key = 'email_drafts';
  final _storage = const FlutterSecureStorage();
  static Future<void> _queue = Future.value();

  /// Verrou : l'enregistrement automatique et l'enregistrement manuel ne
  /// peuvent plus s'écraser (cause possible de brouillons "disparus").
  Future<T> _locked<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<List<EmailDraft>> _load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => EmailDraft.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _save(List<EmailDraft> drafts) =>
      _storage.write(key: _key, value: jsonEncode(drafts.map((d) => d.toJson()).toList()));

  Future<List<EmailDraft>> loadDrafts() => _locked(() async {
        final drafts = await _load();
        drafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
        return drafts;
      });

  Future<void> saveDrafts(List<EmailDraft> drafts) => _locked(() => _save(drafts));

  /// Un seul brouillon par message : même id = mise à jour, pas de doublon.
  Future<void> upsertDraft(EmailDraft draft) => _locked(() async {
        final drafts = await _load();
        final index = drafts.indexWhere((d) => d.id == draft.id);
        if (index >= 0) {
          drafts[index] = draft;
        } else {
          drafts.add(draft);
        }
        await _save(drafts);
      });

  Future<void> addDraft(EmailDraft draft) => upsertDraft(draft);

  /// Supprime un brouillon. Par défaut il va dans la corbeille ;
  /// [toTrash] = false pour le retirer silencieusement (ex. message envoyé).
  Future<void> removeDraft(String id, {bool toTrash = true}) => _locked(() async {
        final drafts = await _load();
        final removed = drafts.where((d) => d.id == id).toList();
        drafts.removeWhere((d) => d.id == id);
        await _save(drafts);
        if (toTrash && removed.isNotEmpty) {
          final d = removed.first;
          await TrashService.instance.add(
            type: 'draft',
            label: d.subject.isEmpty ? '(sans objet)' : d.subject,
            payloads: [d.toJson()],
          );
        }
      });
}
