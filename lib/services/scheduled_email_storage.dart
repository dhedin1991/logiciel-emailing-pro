import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/scheduled_email.dart';
import 'trash_service.dart';

class ScheduledEmailStorage {
  static const _key = 'scheduled_emails';
  final _storage = const FlutterSecureStorage();
  static Future<void> _queue = Future.value();

  /// Verrou : empêche le planificateur et l'interface de s'écraser mutuellement.
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

  Future<List<ScheduledEmail>> loadAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => ScheduledEmail.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveAll(List<ScheduledEmail> items) async {
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  Future<void> add(ScheduledEmail item) => _locked(() async {
        final items = await loadAll();
        items.add(item);
        await saveAll(items);
      });

  Future<void> remove(String id) => _locked(() async {
        final items = await loadAll();
        final removed = items.where((e) => e.id == id).toList();
        items.removeWhere((e) => e.id == id);
        await saveAll(items);
        if (removed.isNotEmpty) {
          await TrashService.instance.add(
            type: 'scheduled',
            label: removed.first.subject.isEmpty ? removed.first.to : removed.first.subject,
            payloads: removed.map((e) => e.toJson()).toList(),
          );
        }
      });

  Future<void> update(ScheduledEmail updated) => _locked(() async {
        final items = await loadAll();
        final index = items.indexWhere((e) => e.id == updated.id);
        if (index >= 0) {
          items[index] = updated;
          await saveAll(items);
        }
      });
}
