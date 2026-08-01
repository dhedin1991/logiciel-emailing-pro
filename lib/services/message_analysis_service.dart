/// Résultat d'analyse d'un message : score sur 100, et liste de remarques.
class MessageAnalysisResult {
  final int qualityScore;
  final List<String> qualityRemarks;
  final int spamRiskScore; // 0 = aucun risque détecté, 100 = risque élevé
  final List<String> spamRemarks;

  MessageAnalysisResult({
    required this.qualityScore,
    required this.qualityRemarks,
    required this.spamRiskScore,
    required this.spamRemarks,
  });
}

/// Analyse un message avec des règles simples et documentées (pas d'IA
/// générative, donc gratuit et prévisible). Les remarques signalent des
/// éléments qui PEUVENT augmenter le risque de classement en indésirable,
/// sans jamais garantir où le message arrivera réellement.
class MessageAnalysisService {
  static const _spamTriggerWords = [
    'gratuit', 'urgent', 'félicitations', 'gagné', 'argent facile',
    'cliquez ici', 'offre limitée', 'sans engagement', '100% gratuit',
    'garanti', 'agir maintenant', 'promotion exceptionnelle',
  ];

  MessageAnalysisResult analyze({required String subject, required String body}) {
    final qualityRemarks = <String>[];
    var qualityScore = 100;

    if (subject.trim().isEmpty) {
      qualityRemarks.add('L\'objet est vide.');
      qualityScore -= 20;
    } else if (subject.length > 78) {
      qualityRemarks.add('L\'objet est assez long (${subject.length} caractères), certains clients mail le tronquent.');
      qualityScore -= 5;
    }

    final wordCount = body.trim().isEmpty ? 0 : body.trim().split(RegExp(r'\s+')).length;
    if (wordCount < 10) {
      qualityRemarks.add('Le message est très court ($wordCount mots), pensez à donner plus de contexte.');
      qualityScore -= 10;
    }

    final sentences = body.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).toList();
    final longSentences = sentences.where((s) => s.trim().split(RegExp(r'\s+')).length > 35).length;
    if (longSentences > 0) {
      qualityRemarks.add('$longSentences phrase(s) très longue(s) : envisagez de les raccourcir pour la lisibilité.');
      qualityScore -= longSentences * 5;
    }

    if (!body.contains(RegExp(r'(bonjour|salut|madame|monsieur|cher|chère)', caseSensitive: false))) {
      qualityRemarks.add('Aucune formule de salutation détectée en début de message.');
      qualityScore -= 5;
    }

    qualityScore = qualityScore.clamp(0, 100);
    if (qualityRemarks.isEmpty) {
      qualityRemarks.add('Aucun point d\'amélioration évident détecté.');
    }

    // --- Analyse du risque "indésirable" ---
    final spamRemarks = <String>[];
    var spamScore = 0;
    final fullTextLower = ('$subject $body').toLowerCase();

    final foundTriggers = _spamTriggerWords.where((w) => fullTextLower.contains(w)).toList();
    if (foundTriggers.isNotEmpty) {
      spamRemarks.add('Mots pouvant déclencher les filtres anti-spam : ${foundTriggers.join(', ')}.');
      spamScore += foundTriggers.length * 10;
    }

    final upperLetters = RegExp(r'[A-ZÀ-Ý]').allMatches(subject).length;
    if (subject.isNotEmpty && upperLetters / subject.length > 0.5) {
      spamRemarks.add('L\'objet contient beaucoup de majuscules.');
      spamScore += 15;
    }

    final exclamationCount = '!'.allMatches(subject + body).length;
    if (exclamationCount >= 3) {
      spamRemarks.add('Plusieurs points d\'exclamation ($exclamationCount) détectés.');
      spamScore += 10;
    }

    final linkCount = RegExp(r'https?://').allMatches(body).length;
    if (linkCount >= 3) {
      spamRemarks.add('$linkCount liens détectés dans le message.');
      spamScore += 10;
    }

    spamScore = spamScore.clamp(0, 100);
    if (spamRemarks.isEmpty) {
      spamRemarks.add('Aucun signal habituel de spam détecté (cela ne garantit pas l\'arrivée en boîte de réception principale).');
    }

    return MessageAnalysisResult(
      qualityScore: qualityScore,
      qualityRemarks: qualityRemarks,
      spamRiskScore: spamScore,
      spamRemarks: spamRemarks,
    );
  }
}
