import 'dart:convert';
import 'package:http/http.dart' as http;

class LanguageToolMatch {
  final String message;
  final String shortMessage;
  final int offset;
  final int length;
  final List<String> suggestions;

  LanguageToolMatch({
    required this.message,
    required this.shortMessage,
    required this.offset,
    required this.length,
    required this.suggestions,
  });
}

/// Utilise l'API publique et gratuite de LanguageTool (languagetool.org)
/// pour détecter les fautes d'orthographe et de grammaire.
/// Limite d'usage : environ 20 requêtes/minute, texte de 20 000 caractères
/// max — largement suffisant pour un e-mail.
class LanguageToolService {
  static const _endpoint = 'https://api.languagetool.org/v2/check';

  Future<List<LanguageToolMatch>> checkText(String text, {String language = 'fr'}) async {
    if (text.trim().isEmpty) return [];

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'text': text, 'language': language},
    );

    if (response.statusCode != 200) {
      throw Exception('Service de correction indisponible pour le moment.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final matches = (data['matches'] as List<dynamic>? ?? []);

    return matches.map((m) {
      final replacements = (m['replacements'] as List<dynamic>? ?? [])
          .map((r) => r['value'] as String)
          .take(3)
          .toList();
      return LanguageToolMatch(
        message: m['message'] as String,
        shortMessage: (m['shortMessage'] as String?)?.isNotEmpty == true
            ? m['shortMessage'] as String
            : m['message'] as String,
        offset: m['offset'] as int,
        length: m['length'] as int,
        suggestions: replacements,
      );
    }).toList();
  }
}
