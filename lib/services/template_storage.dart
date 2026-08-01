import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/message_template.dart';

class TemplateStorage {
  static const _key = 'message_templates';
  final _storage = const FlutterSecureStorage();

  Future<List<MessageTemplate>> loadTemplates() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => MessageTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveTemplates(List<MessageTemplate> templates) async {
    final raw = jsonEncode(templates.map((t) => t.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  Future<void> addTemplate(MessageTemplate template) async {
    final templates = await loadTemplates();
    templates.add(template);
    await saveTemplates(templates);
  }

  Future<void> removeTemplate(String id) async {
    final templates = await loadTemplates();
    templates.removeWhere((t) => t.id == id);
    await saveTemplates(templates);
  }

  Future<void> updateTemplate(MessageTemplate updated) async {
    final templates = await loadTemplates();
    final index = templates.indexWhere((t) => t.id == updated.id);
    if (index >= 0) {
      templates[index] = updated;
      await saveTemplates(templates);
    }
  }
}
