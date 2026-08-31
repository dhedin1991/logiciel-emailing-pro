import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Écrit `content` dans un fichier choisi par l'utilisateur via la boîte
/// de dialogue système "Enregistrer sous". Fonctionne pour CSV et TXT.
Future<void> exportTextFile({
  required String content,
  required String suggestedFileName,
  required String extension,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final path = await FilePicker.platform.saveFile(
    fileName: '$suggestedFileName.$extension',
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: [extension],
  );
  if (path == null) return;
  try {
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes);
    }
  } catch (_) {}
}

/// Échappe une valeur pour un champ CSV séparé par point-virgule.
String csvField(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
