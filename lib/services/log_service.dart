import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Journal local simple (fichier texte, une ligne par événement) pour
/// diagnostiquer les problèmes de synchronisation et d'envoi. Ne contient
/// jamais de mot de passe ni de secret — uniquement des événements et des
/// compteurs.
class LogService {
  static const _maxLines = 500;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/app_log.txt');
  }

  Future<void> log(String message) async {
    try {
      final file = await _file();
      final line = '${DateTime.now().toIso8601String()}  $message\n';
      await file.writeAsString(line, mode: FileMode.append);
      await _trimIfNeeded(file);
    } catch (_) {
      // Un journal qui échoue à s'écrire ne doit jamais interrompre l'app.
    }
  }

  Future<void> _trimIfNeeded(File file) async {
    final lines = await file.readAsLines();
    if (lines.length <= _maxLines) return;
    final trimmed = lines.sublist(lines.length - _maxLines);
    await file.writeAsString('${trimmed.join('\n')}\n');
  }

  Future<List<String>> readRecent({int count = 100}) async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final lines = await file.readAsLines();
      final recent = lines.length <= count ? lines : lines.sublist(lines.length - count);
      return recent.reversed.toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.writeAsString('');
    } catch (_) {}
  }
}
