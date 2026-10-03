import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sent_email_log.dart';
import 'trash_service.dart';

/// Historique des envois, stocké dans un fichier (une ligne JSON par envoi).
///
/// Avant : tout l'historique (500 entrées) était relu, décodé puis réécrit
/// dans le coffre sécurisé À CHAQUE e-mail, et deux campagnes en parallèle
/// pouvaient s'écraser mutuellement. Maintenant : ajout d'une seule ligne
/// (rapide), file d'attente interne pour que les écritures ne se chevauchent
/// jamais, et capacité largement supérieure (le compteur journalier Gmail
/// reste exact).
class HistoryStorage {
  static const _legacyKey = 'sent_email_history';
  static const _fileName = 'sent_email_history.jsonl';
  static const _maxEntries = 20000;
  static const _compactThreshold = 25000;

  static Future<void> _queue = Future.value();
  static bool _migrated = false;

  final _secure = const FlutterSecureStorage();

  /// Exécute [action] après toutes les opérations précédentes (verrou).
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

  /// Reprend l'ancien historique du coffre sécurisé (une seule fois).
  Future<void> _migrateIfNeeded(File file) async {
    if (_migrated) return;
    _migrated = true;
    try {
      final raw = await _secure.read(key: _legacyKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => SentEmailLog.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed; // ancien format : plus récent en premier
      final existing = await file.exists() ? await file.readAsString() : '';
      final buffer = StringBuffer();
      for (final e in list) {
        buffer.writeln(jsonEncode(e.toJson()));
      }
      await file.writeAsString('$buffer$existing');
      await _secure.delete(key: _legacyKey);
    } catch (_) {
      // Migration impossible : on repart sur un historique vide plutôt que de bloquer les envois.
    }
  }

  List<SentEmailLog> _parse(List<String> lines) {
    final result = <SentEmailLog>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        result.add(SentEmailLog.fromJson(jsonDecode(line) as Map<String, dynamic>));
      } catch (_) {
        // Ligne abîmée (arrêt brutal pendant l'écriture) : ignorée.
      }
    }
    return result;
  }

  /// Toutes les entrées, la plus récente en premier.
  Future<List<SentEmailLog>> loadAll() => _locked(() async {
        final file = await _file();
        await _migrateIfNeeded(file);
        if (!await file.exists()) return <SentEmailLog>[];
        final lines = await file.readAsLines();
        var entries = _parse(lines);
        if (lines.length > _compactThreshold) {
          entries = entries.sublist(entries.length - _maxEntries);
          await _writeAll(file, entries);
        }
        entries.sort((a, b) => b.sentAt.compareTo(a.sentAt));
        return entries;
      });

  Future<void> _writeAll(File file, List<SentEmailLog> oldestFirst) async {
    final buffer = StringBuffer();
    for (final e in oldestFirst) {
      buffer.writeln(jsonEncode(e.toJson()));
    }
    await file.writeAsString(buffer.toString(), flush: true);
  }

  /// Ajoute une entrée. Ne lève jamais d'erreur : un problème d'historique ne
  /// doit JAMAIS faire croire qu'un e-mail n'est pas parti (ni le faire renvoyer).
  Future<void> add(SentEmailLog entry) => _locked(() async {
        try {
          final file = await _file();
          await _migrateIfNeeded(file);
          await file.writeAsString('${jsonEncode(entry.toJson())}\n',
              mode: FileMode.append, flush: true);
        } catch (_) {}
      });

  /// Nombre d'envois réussis aujourd'hui par ce compte (compteur exact,
  /// non limité aux dernières entrées affichées).
  Future<int> countSuccessToday(String accountEmail) async {
    final today = DateTime.now();
    final all = await loadAll();
    return all
        .where((e) =>
            e.success &&
            e.accountEmail == accountEmail &&
            e.sentAt.year == today.year &&
            e.sentAt.month == today.month &&
            e.sentAt.day == today.day)
        .length;
  }

  Future<void> clearAll() => _locked(() async {
        final file = await _file();
        if (await file.exists()) {
          // Les 1 000 entrées les plus récentes vont dans la corbeille.
          final entries = _parse(await file.readAsLines());
          final recent = entries.length > 1000 ? entries.sublist(entries.length - 1000) : entries;
          if (recent.isNotEmpty) {
            await TrashService.instance.add(
              type: 'history',
              label: '${recent.length} entrées d\'historique',
              payloads: recent.map((e) => e.toJson()).toList(),
            );
          }
          await file.delete();
        }
        await _secure.delete(key: _legacyKey);
      });

  Future<void> removeEntries(Set<String> ids) => _locked(() async {
        final file = await _file();
        await _migrateIfNeeded(file);
        if (!await file.exists()) return;
        final entries = _parse(await file.readAsLines());
        final removed = entries.where((e) => ids.contains(e.id)).toList();
        entries.removeWhere((e) => ids.contains(e.id));
        await _writeAll(file, entries);
        if (removed.isNotEmpty) {
          await TrashService.instance.add(
            type: 'history',
            label: removed.length == 1
                ? 'Envoi à ${removed.first.to}'
                : '${removed.length} entrées d\'historique',
            payloads: removed.map((e) => e.toJson()).toList(),
          );
        }
      });
}
