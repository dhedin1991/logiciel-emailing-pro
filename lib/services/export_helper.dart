import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Écrit `content` dans un fichier choisi par l'utilisateur via la boîte
/// de dialogue système "Enregistrer sous". Fonctionne pour CSV et TXT.
///
/// Retourne `true` si le fichier a bien été écrit, `false` si l'utilisateur
/// a annulé la boîte de dialogue, et lève une exception si l'écriture a
/// échoué (permission refusée, disque plein, etc.) — l'appelant doit
/// afficher un message à l'utilisateur dans les deux cas d'échec, jamais
/// laisser l'export échouer silencieusement.
Future<bool> exportTextFile({
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
  if (path == null) return false;
  final file = File(path);
  if (!await file.exists() || await file.length() == 0) {
    // Sur certaines plateformes (Windows/Linux), saveFile ne write pas
    // lui-même les octets : on l'écrit nous-même et on laisse toute
    // exception remonter à l'appelant plutôt que de l'avaler.
    await file.writeAsBytes(bytes);
  }
  return true;
}

/// Échappe une valeur pour un champ CSV séparé par point-virgule.
String csvField(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
