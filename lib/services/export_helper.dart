import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xls;

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

/// Exporte un tableau de données (en-têtes + lignes) au format Excel
/// (.xlsx) via la boîte de dialogue système "Enregistrer sous". Mêmes
/// garanties que [exportTextFile] : retourne false si annulé, lève une
/// exception en cas d'échec réel plutôt que d'échouer silencieusement.
Future<bool> exportExcelFile({
  required List<String> headers,
  required List<List<String>> rows,
  required String suggestedFileName,
}) async {
  final workbook = xls.Excel.createExcel();
  final sheet = workbook[workbook.getDefaultSheet()!];
  sheet.appendRow(headers.map((h) => xls.TextCellValue(h)).toList());
  for (final row in rows) {
    sheet.appendRow(row.map((v) => xls.TextCellValue(v)).toList());
  }
  final bytes = workbook.encode();
  if (bytes == null) throw Exception('Impossible de générer le fichier Excel.');
  final data = Uint8List.fromList(bytes);

  final path = await FilePicker.platform.saveFile(
    fileName: '$suggestedFileName.xlsx',
    bytes: data,
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );
  if (path == null) return false;
  final file = File(path);
  if (!await file.exists() || await file.length() == 0) {
    await file.writeAsBytes(data);
  }
  return true;
}
