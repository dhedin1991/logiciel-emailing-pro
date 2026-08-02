import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import '../models/contact.dart';

/// Lit un fichier .csv ou .xlsx et en extrait une liste de contacts.
/// Cherche automatiquement les colonnes "nom"/"name" et "email"/"e-mail",
/// peu importe leur ordre ou leur casse dans le fichier.
class ContactImportService {
  final _uuid = const Uuid();

  Future<List<Contact>> importFromFile(String path) async {
    final extension = path.split('.').last.toLowerCase();
    if (extension == 'csv') {
      return _importFromCsv(path);
    } else if (extension == 'xlsx') {
      return _importFromExcel(path);
    } else if (extension == 'txt') {
      return _importFromTxt(path);
    }
    throw Exception('Format non pris en charge. Utilisez un fichier .csv, .xlsx ou .txt.');
  }

  /// Lit un fichier texte (bloc-notes) : une entrée par ligne, au format
  /// "email" seul, ou "Nom, email" / "Nom; email" / "Nom<tab>email".
  Future<List<Contact>> _importFromTxt(String path) async {
    final content = await File(path).readAsString();
    final lines = content.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty);

    final contacts = <Contact>[];
    for (final line in lines) {
      final parts = line.split(RegExp(r'[,;\t]')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) continue;

      String? email;
      String? name;
      for (final part in parts) {
        if (part.contains('@')) {
          email = part;
        } else if (name == null) {
          name = part;
        }
      }
      if (email == null || !email.contains('@')) continue;

      contacts.add(Contact(
        id: _uuid.v4(),
        name: (name == null || name.isEmpty) ? email.split('@').first : name,
        email: email,
      ));
    }
    return contacts;
  }

  Future<List<Contact>> _importFromCsv(String path) async {
    final content = await File(path).readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    return _rowsToContacts(rows);
  }

  Future<List<Contact>> _importFromExcel(String path) async {
    final bytes = await File(path).readAsBytes();
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables[workbook.tables.keys.first];
    if (sheet == null) return [];
    final rows = sheet.rows
        .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
        .toList();
    return _rowsToContacts(rows);
  }

  List<Contact> _rowsToContacts(List<List<dynamic>> rows) {
    if (rows.isEmpty) return [];

    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    final nameIndex = header.indexWhere((h) => h.contains('nom') || h.contains('name'));
    final emailIndex = header.indexWhere((h) => h.contains('mail'));
    final companyIndex = header.indexWhere((h) => h.contains('entreprise') || h.contains('societe') || h.contains('société') || h.contains('company'));
    final phoneIndex = header.indexWhere((h) => h.contains('tel') || h.contains('phone'));

    if (emailIndex == -1) {
      throw Exception('Aucune colonne "email" trouvée dans le fichier.');
    }

    final contacts = <Contact>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= emailIndex) continue;
      final email = row[emailIndex].toString().trim();
      if (email.isEmpty || !email.contains('@')) continue;

      final name = nameIndex != -1 && row.length > nameIndex
          ? row[nameIndex].toString().trim()
          : email.split('@').first;
      final company = companyIndex != -1 && row.length > companyIndex
          ? row[companyIndex].toString().trim()
          : '';
      final phone = phoneIndex != -1 && row.length > phoneIndex
          ? row[phoneIndex].toString().trim()
          : '';

      contacts.add(Contact(
        id: _uuid.v4(),
        name: name.isEmpty ? email : name,
        email: email,
        company: company,
        phone: phone,
      ));
    }
    return contacts;
  }
}
