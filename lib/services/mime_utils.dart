import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Outils partagés pour fabriquer des e-mails corrects (MIME) et sûrs.
class MimeUtils {
  static final _addressRegex = RegExp(r'^[^\s@<>,;"]+@[^\s@<>,;"]+\.[^\s@<>,;"]{2,}$');

  /// Retire tout retour à la ligne : empêche l'injection d'en-têtes
  /// (ex. un contact dont l'adresse contient "\r\nBcc: ...").
  static String cleanHeader(String value) =>
      value.replaceAll(RegExp(r'[\r\n\u0000]+'), ' ').trim();

  static bool isValidAddress(String address) => _addressRegex.hasMatch(address.trim());

  /// Découpe "a@x.fr, b@y.fr" en adresses nettoyées ; lève une erreur claire
  /// si l'une d'elles est invalide.
  static List<String> parseAddresses(String? raw, {String field = 'Destinataire'}) {
    if (raw == null || raw.trim().isEmpty) return [];
    final parts = raw
        .split(RegExp(r'[,;]'))
        .map(cleanHeader)
        .where((e) => e.isNotEmpty)
        .toList();
    for (final p in parts) {
      if (!isValidAddress(p)) {
        throw FormatException('$field invalide : $p');
      }
    }
    return parts;
  }

  /// Encode un texte d'en-tête (objet, nom) en UTF-8 si nécessaire.
  static String encodeHeaderText(String value) {
    final clean = cleanHeader(value);
    if (RegExp(r'^[\x20-\x7E]*$').hasMatch(clean)) return clean;
    return '=?UTF-8?B?${base64.encode(utf8.encode(clean))}?=';
  }

  /// Adresse d'expéditeur avec nom d'affichage : "Nom" <adresse>.
  static String fromHeader(String email, String? displayName) {
    final cleanEmail = cleanHeader(email);
    final name = displayName == null ? '' : cleanHeader(displayName);
    if (name.isEmpty || name == cleanEmail) return cleanEmail;
    if (RegExp(r'^[\x20-\x7E]*$').hasMatch(name)) {
      final escaped = name.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      return '"$escaped" <$cleanEmail>';
    }
    return '${encodeHeaderText(name)} <$cleanEmail>';
  }

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static String rfc2822Date([DateTime? when]) {
    final d = (when ?? DateTime.now()).toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${_days[d.weekday - 1]}, ${two(d.day)} ${_months[d.month - 1]} ${d.year} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)} +0000';
  }

  static String messageId(String fromEmail) {
    final domain = fromEmail.contains('@') ? fromEmail.split('@').last : 'localhost';
    final rnd = Random.secure();
    final token = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return '<$token.${DateTime.now().microsecondsSinceEpoch}@$domain>';
  }

  /// Base64 découpé en lignes de 76 caractères (norme MIME), fins de ligne CRLF.
  static String base64Lines(List<int> bytes) {
    final encoded = base64.encode(bytes);
    final out = StringBuffer();
    for (var i = 0; i < encoded.length; i += 76) {
      out.write(encoded.substring(i, min(i + 76, encoded.length)));
      out.write('\r\n');
    }
    return out.toString();
  }

  /// Nom de fichier de pièce jointe : version ASCII + version UTF-8 (RFC 2231).
  static String attachmentFileName(String name) {
    final clean = cleanHeader(name).replaceAll('"', '');
    final ascii = clean.replaceAll(RegExp(r'[^\x20-\x7E]'), '_');
    if (ascii == clean) return 'filename="$clean"';
    return 'filename="$ascii"; filename*=UTF-8\'\'${Uri.encodeComponent(clean)}';
  }

  /// Assemble un e-mail complet (texte brut, avec pièces jointes éventuelles).
  /// [attachments] : liste de (nom, octets déjà lus). Lecture faite par l'appelant,
  /// pour ne lire/encoder chaque fichier qu'une seule fois par campagne.
  static String buildMessage({
    required String from,
    required String fromEmail,
    required List<String> to,
    List<String> cc = const [],
    List<String> bcc = const [],
    required String subject,
    required String textBody,
    String? htmlBody,
    List<MimeAttachment> attachments = const [],
    Map<String, String> extraHeaders = const {},
  }) {
    final b = StringBuffer();
    void h(String line) => b.write('$line\r\n');

    h('Date: ${rfc2822Date()}');
    h('Message-ID: ${messageId(fromEmail)}');
    h('From: $from');
    h('To: ${to.join(', ')}');
    if (cc.isNotEmpty) h('Cc: ${cc.join(', ')}');
    if (bcc.isNotEmpty) h('Bcc: ${bcc.join(', ')}');
    h('Subject: ${encodeHeaderText(subject)}');
    h('MIME-Version: 1.0');
    extraHeaders.forEach((k, v) => h('$k: ${cleanHeader(v)}'));

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final mixed = 'emailingpro-mixed-$stamp';
    final alt = 'emailingpro-alt-$stamp';

    String bodyPart() {
      final p = StringBuffer();
      if (htmlBody == null) {
        p.write('Content-Type: text/plain; charset="UTF-8"\r\n');
        p.write('Content-Transfer-Encoding: base64\r\n\r\n');
        p.write(base64Lines(utf8.encode(textBody)));
      } else {
        p.write('Content-Type: multipart/alternative; boundary="$alt"\r\n\r\n');
        p.write('--$alt\r\n');
        p.write('Content-Type: text/plain; charset="UTF-8"\r\n');
        p.write('Content-Transfer-Encoding: base64\r\n\r\n');
        p.write(base64Lines(utf8.encode(textBody)));
        p.write('--$alt\r\n');
        p.write('Content-Type: text/html; charset="UTF-8"\r\n');
        p.write('Content-Transfer-Encoding: base64\r\n\r\n');
        p.write(base64Lines(utf8.encode(htmlBody)));
        p.write('--$alt--\r\n');
      }
      return p.toString();
    }

    if (attachments.isEmpty) {
      b.write(bodyPart());
      return b.toString();
    }

    h('Content-Type: multipart/mixed; boundary="$mixed"');
    b.write('\r\n');
    b.write('--$mixed\r\n');
    b.write(bodyPart());
    for (final a in attachments) {
      b.write('--$mixed\r\n');
      b.write('Content-Type: ${a.mimeType}; name="${a.asciiName}"\r\n');
      b.write('Content-Disposition: attachment; ${attachmentFileName(a.name)}\r\n');
      b.write('Content-Transfer-Encoding: base64\r\n\r\n');
      b.write(a.base64Content);
    }
    b.write('--$mixed--\r\n');
    return b.toString();
  }

  /// Lit les pièces jointes une seule fois (à appeler une fois par campagne).
  static Future<List<MimeAttachment>> loadAttachments(List<String> paths) async {
    final result = <MimeAttachment>[];
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) {
        throw FileSystemException('Pièce jointe introuvable', path);
      }
      final name = path.split(Platform.pathSeparator).last;
      result.add(MimeAttachment(
        name: name,
        mimeType: _guessMime(name),
        base64Content: base64Lines(await file.readAsBytes()),
      ));
    }
    return result;
  }

  static String _guessMime(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    const map = {
      'pdf': 'application/pdf',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'txt': 'text/plain',
      'csv': 'text/csv',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'zip': 'application/zip',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}

class MimeAttachment {
  final String name;
  final String mimeType;
  final String base64Content;
  MimeAttachment({required this.name, required this.mimeType, required this.base64Content});

  String get asciiName =>
      name.replaceAll(RegExp(r'[^\x20-\x7E]'), '_').replaceAll('"', '');
}
