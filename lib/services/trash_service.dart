import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/trash_item.dart';

typedef TrashRestorer = Future<void> Function(List<Map<String, dynamic>> payloads);

/// Corbeille commune à tout le logiciel : tout ce qui est supprimé
/// (brouillons, contacts, listes, modèles, signatures, textes courts,
/// envois programmés, entrées d'historique) y est conservé et peut être
/// restauré. Les comptes d'envoi n'y passent JAMAIS (mots de passe).
class TrashService {
  TrashService._();
  static final TrashService instance = TrashService._();

  static const defaultRetentionDays = 30;
  static const _fileName = 'trash.json';

  /// Nombre d'éléments (pour la pastille du menu).
  final ValueNotifier<int> count = ValueNotifier<int>(0);

  /// Associe chaque type à la fonction qui remet l'élément à sa place.
  final Map<String, TrashRestorer> restorers = {};

  Future<void> _queue = Future.value();

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

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<Map<String, dynamic>> _read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {'retentionDays': defaultRetentionDays, 'items': []};
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data;
    } catch (_) {
      return {'retentionDays': defaultRetentionDays, 'items': []};
    }
  }

  Future<void> _write(int retentionDays, List<TrashItem> items) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode({'retentionDays': retentionDays, 'items': items.map((e) => e.toJson()).toList()}),
      flush: true,
    );
    count.value = items.length;
  }

  List<TrashItem> _items(Map<String, dynamic> data) => ((data['items'] as List<dynamic>?) ?? [])
      .map((e) => TrashItem.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  int _retention(Map<String, dynamic> data) => (data['retentionDays'] as int?) ?? defaultRetentionDays;

  /// À appeler au démarrage : purge les éléments trop anciens et met la
  /// pastille à jour.
  Future<void> refresh() => _locked(() async {
        final data = await _read();
        final days = _retention(data);
        final all = _items(data);
        final limit = DateTime.now().subtract(Duration(days: days));
        final kept = all.where((i) => i.deletedAt.isAfter(limit)).toList();
        if (kept.length != all.length) {
          await _write(days, kept);
        } else {
          count.value = all.length;
        }
      });

  Future<List<TrashItem>> loadAll() async {
    await refresh();
    final items = _items(await _read());
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return items;
  }

  Future<int> retentionDays() async => _retention(await _read());

  Future<void> setRetentionDays(int days) => _locked(() async {
        final data = await _read();
        await _write(days, _items(data));
      });

  /// Ne lève jamais d'erreur : un souci de corbeille ne doit pas empêcher la suppression.
  Future<void> add({
    required String type,
    required String label,
    required List<Map<String, dynamic>> payloads,
  }) =>
      _locked(() async {
        try {
          if (payloads.isEmpty) return;
          final data = await _read();
          final items = _items(data);
          items.add(TrashItem(
            id: const Uuid().v4(),
            type: type,
            label: label,
            payloads: payloads,
            deletedAt: DateTime.now(),
          ));
          await _write(_retention(data), items);
        } catch (_) {}
      });

  /// Remet l'élément à sa place d'origine puis le retire de la corbeille.
  Future<void> restore(String id) async {
    final data = await _read();
    final item = _items(data).where((i) => i.id == id).firstOrNull;
    if (item == null) return;
    final restorer = restorers[item.type];
    if (restorer == null) throw StateError('Type non géré : ${item.type}');
    await restorer(item.payloads);
    await _locked(() async {
      final fresh = await _read();
      await _write(_retention(fresh), _items(fresh).where((i) => i.id != id).toList());
    });
  }

  Future<void> restoreAll() async {
    final items = await loadAll();
    for (final item in items) {
      await restore(item.id);
    }
  }

  Future<void> deleteForever(String id) => _locked(() async {
        final data = await _read();
        await _write(_retention(data), _items(data).where((i) => i.id != id).toList());
      });

  Future<void> emptyAll() => _locked(() async {
        final data = await _read();
        await _write(_retention(data), []);
      });
}
