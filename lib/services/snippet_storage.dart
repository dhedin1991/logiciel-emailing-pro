import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/snippet.dart';

class SnippetStorage {
  static const _key = 'snippets';
  final _storage = const FlutterSecureStorage();

  Future<List<Snippet>> loadSnippets() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Snippet.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveSnippets(List<Snippet> snippets) async {
    final raw = jsonEncode(snippets.map((s) => s.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  Future<void> addSnippet(Snippet snippet) async {
    final snippets = await loadSnippets();
    snippets.add(snippet);
    await saveSnippets(snippets);
  }

  Future<void> removeSnippet(String id) async {
    final snippets = await loadSnippets();
    snippets.removeWhere((s) => s.id == id);
    await saveSnippets(snippets);
  }
}
