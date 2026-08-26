import 'package:flutter/foundation.dart';
import '../models/cctld_country_map.dart';
import '../models/email_cleaning_models.dart';

const defaultGenericPrefixes = [
  'noreply',
  'no-reply',
  'donotreply',
  'do-not-reply',
  'mailer-daemon',
  'postmaster',
  'webmaster',
  'admin',
  'abuse',
  'support',
];

const defaultDisposableDomains = [
  'mailinator.com',
  'tempmail.com',
  'temp-mail.org',
  'guerrillamail.com',
  '10minutemail.com',
  'yopmail.com',
  'trashmail.com',
  'throwawaymail.com',
  'getnada.com',
  'fakeinbox.com',
  'dispostable.com',
  'sharklasers.com',
  'maildrop.cc',
];

final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');

/// Fonction top-level (nécessaire pour compute()) qui fait tout le
/// traitement en une fois, sans bloquer l'interface sur de grosses listes.
CleaningResult cleanAndClassify(CleaningInput input) {
  // 1. Séparation (ligne, virgule, point-virgule, espaces multiples)
  final rawTokens = input.rawText.split(RegExp(r'[\n\r,;]+|\s{2,}'));

  // 2. Normalisation
  final normalizedList = <String>[];
  for (final token in rawTokens) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) continue;
    final atIndex = trimmed.lastIndexOf('@');
    if (atIndex == -1) {
      normalizedList.add(trimmed.toLowerCase());
      continue;
    }
    final local = trimmed.substring(0, atIndex);
    final domain = trimmed.substring(atIndex + 1).toLowerCase();
    normalizedList.add('$local@$domain');
  }

  final totalImported = normalizedList.length;

  // 3. Suppression des doublons (insensible à la casse déjà appliquée sur le domaine,
  // on compare en minuscule complet pour la dédup)
  final seen = <String>{};
  final deduped = <String>[];
  for (final e in normalizedList) {
    final key = e.toLowerCase();
    if (seen.add(key)) deduped.add(e);
  }
  final duplicatesRemoved = totalImported - deduped.length;

  final valid = <ClassifiedEmail>[];
  final invalid = <ClassifiedEmail>[];
  final generic = <ClassifiedEmail>[];
  final disposable = <ClassifiedEmail>[];
  final byCountry = <String, List<ClassifiedEmail>>{};
  final undetermined = <ClassifiedEmail>[];

  final genericSet = input.genericPrefixes.map((e) => e.toLowerCase()).toSet();
  final disposableSet = input.disposableDomains.map((e) => e.toLowerCase()).toSet();

  for (final email in deduped) {
    final atIndex = email.lastIndexOf('@');
    final domain = atIndex == -1 ? '' : email.substring(atIndex + 1);
    final localPart = atIndex == -1 ? email : email.substring(0, atIndex);

    if (!_emailRegex.hasMatch(email)) {
      invalid.add(ClassifiedEmail(
        original: email,
        normalized: email,
        category: EmailCategory.invalid,
        domain: domain,
      ));
      continue;
    }

    if (genericSet.any((prefix) => localPart == prefix || localPart.startsWith('$prefix@'))) {
      generic.add(ClassifiedEmail(
        original: email,
        normalized: email,
        category: EmailCategory.generic,
        domain: domain,
      ));
      continue;
    }

    if (disposableSet.contains(domain)) {
      disposable.add(ClassifiedEmail(
        original: email,
        normalized: email,
        category: EmailCategory.disposable,
        domain: domain,
      ));
      continue;
    }

    // Classement par pays : uniquement si le domaine n'est pas dans la
    // liste des domaines internationaux, et que le ccTLD est reconnu.
    String? country;
    if (!internationalDomains.contains(domain)) {
      final parts = domain.split('.');
      if (parts.length >= 2) {
        final tld = parts.last;
        country = ccTldToCountry[tld];
      }
    }

    final classified = ClassifiedEmail(
      original: email,
      normalized: email,
      category: EmailCategory.valid,
      domain: domain,
      country: country,
    );
    valid.add(classified);

    if (country != null) {
      byCountry.putIfAbsent(country, () => []).add(classified);
    } else {
      undetermined.add(classified);
    }
  }

  return CleaningResult(
    totalImported: totalImported,
    duplicatesRemoved: duplicatesRemoved,
    valid: valid,
    invalid: invalid,
    generic: generic,
    disposable: disposable,
    byCountry: byCountry,
    undeterminedCountry: undetermined,
  );
}

class EmailCleaningService {
  /// Traite la liste dans un isolate séparé (compute) pour ne jamais
  /// bloquer l'interface, même avec plusieurs milliers d'adresses.
  Future<CleaningResult> process(CleaningInput input) {
    return compute(cleanAndClassify, input);
  }
}
