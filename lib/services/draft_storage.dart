import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/email_draft.dart';

class DraftStorage {
  static const _key = 'email_drafts';
  final _storage = const FlutterSecureStorage();

  Future<List<EmailDraft>> loadDrafts() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    final drafts = list.map((e) => EmailDraft.fromJson(e as Map<String, dynamic>)).toList();
    drafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return drafts;
  }

  Future<void> saveDrafts(List<EmailDraft> drafts) async {
    final raw = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  Future<void> addDraft(EmailDraft draft) async {
    final drafts = await loadDrafts();
    drafts.add(draft);
    await saveDrafts(drafts);
  }

  Future<void> removeDraft(String id) async {
    final drafts = await loadDrafts();
    drafts.removeWhere((d) => d.id == id);
    await saveDrafts(drafts);
  }
}
