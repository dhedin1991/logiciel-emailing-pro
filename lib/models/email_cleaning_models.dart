enum EmailCategory { valid, invalid, generic, disposable }

class ClassifiedEmail {
  final String original;
  final String normalized;
  final EmailCategory category;
  final String? country; // null = indéterminé
  final String domain;

  ClassifiedEmail({
    required this.original,
    required this.normalized,
    required this.category,
    required this.domain,
    this.country,
  });
}

class CleaningResult {
  final int totalImported;
  final int duplicatesRemoved;
  final List<ClassifiedEmail> valid;
  final List<ClassifiedEmail> invalid;
  final List<ClassifiedEmail> generic;
  final List<ClassifiedEmail> disposable;
  final Map<String, List<ClassifiedEmail>> byCountry; // pays -> adresses valides
  final List<ClassifiedEmail> undeterminedCountry; // valides mais pays inconnu

  CleaningResult({
    required this.totalImported,
    required this.duplicatesRemoved,
    required this.valid,
    required this.invalid,
    required this.generic,
    required this.disposable,
    required this.byCountry,
    required this.undeterminedCountry,
  });
}

/// Paramètres d'entrée pour le traitement (utilisé aussi avec compute()
/// pour ne pas bloquer l'interface sur de grandes listes).
class CleaningInput {
  final String rawText;
  final List<String> genericPrefixes;
  final List<String> disposableDomains;
  CleaningInput({
    required this.rawText,
    required this.genericPrefixes,
    required this.disposableDomains,
  });
}
