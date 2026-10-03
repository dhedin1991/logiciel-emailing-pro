import '../models/signature.dart';

/// Champs d'une signature structurée, dans l'ordre de saisie.
const signatureFieldLabels = <String, String>{
  'name': 'Nom',
  'function': 'Fonction',
  'company': 'Société',
  'direction': 'Direction / service',
  'city': 'Ville, pays',
  'phone': 'Téléphone',
  'mobile': 'Mobile',
  'email': 'E-mail',
  'website': 'Site web',
  'registration': "Numéro d'enregistrement",
  'confidentiality': 'Mention de confidentialité',
};

enum SigLineKind { name, normal, small }

class SigLine {
  final String text;
  final SigLineKind kind;
  const SigLine(this.text, this.kind);
}

/// Taille imposée à TOUTES les signatures (le message fait 15 px).
const double signatureFontSize = 11;
const double signatureNameFontSize = 12;
const double signatureSmallFontSize = 9;

String _f(Signature s, String key) => (s.fields[key] ?? '').trim();

String _join(List<String> parts, String sep) =>
    parts.where((p) => p.isNotEmpty).join(sep);

/// Lignes de la signature selon son format (les champs vides disparaissent).
List<SigLine> signatureLines(Signature s) {
  final lines = <SigLine>[];
  void add(String text, [SigLineKind kind = SigLineKind.normal]) {
    if (text.trim().isNotEmpty) lines.add(SigLine(text.trim(), kind));
  }

  switch (s.format) {
    case 'classic':
      add(_f(s, 'name'), SigLineKind.name);
      add(_f(s, 'function'));
      add(_f(s, 'company'));
      final phone = _f(s, 'phone');
      add(_join([phone.isEmpty ? '' : 'T : $phone', _f(s, 'email')], ' | '));
      add(_f(s, 'website'));
      break;
    case 'accent':
      add(_f(s, 'name'), SigLineKind.name);
      add(_join([_f(s, 'function'), _f(s, 'company')], ' · '));
      add(_f(s, 'phone'));
      add(_f(s, 'email'));
      add(_f(s, 'website'));
      break;
    case 'corporate':
      add(_f(s, 'name'), SigLineKind.name);
      add(_join([_f(s, 'function'), _f(s, 'direction')], ' | '));
      add(_f(s, 'company').toUpperCase());
      add(_f(s, 'registration'));
      add(_f(s, 'city'));
      final phone = _f(s, 'phone');
      final mobile = _f(s, 'mobile');
      add(_join([phone.isEmpty ? '' : 'T : $phone', mobile.isEmpty ? '' : 'M : $mobile'], ' | '));
      add(_join([_f(s, 'email'), _f(s, 'website')], ' | '));
      add(_f(s, 'confidentiality'), SigLineKind.small);
      break;
    default:
      for (final line in s.content.split(RegExp(r'\r?\n'))) {
        add(line);
      }
  }
  return lines;
}

/// Version texte brut : séparateur "-- " puis les lignes.
String signatureText(Signature s) =>
    '-- \n${signatureLines(s).map((l) => l.text).join('\n')}';

String _esc(String v) => v
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Version HTML : petits caractères gras gris, interligne serré, filet fin au-dessus
/// (ou trait de couleur à gauche pour le format "accent").
String signatureHtml(Signature s) {
  final rows = signatureLines(s).map((l) {
    late final double size;
    late final String color;
    switch (l.kind) {
      case SigLineKind.name:
        size = signatureNameFontSize;
        color = '#374151';
        break;
      case SigLineKind.small:
        size = signatureSmallFontSize;
        color = '#9ca3af';
        break;
      case SigLineKind.normal:
        size = signatureFontSize;
        color = '#6b7280';
    }
    return '<div style="font-size:${size}px;font-weight:bold;color:$color;line-height:1.3;margin:0;">${_esc(l.text)}</div>';
  }).join();
  const font = 'font-family:Arial,Helvetica,sans-serif;';
  if (s.format == 'accent') {
    return '<div style="margin-top:14px;border-left:3px solid ${_hex(s.accentColor)};padding-left:10px;$font">$rows</div>';
  }
  return '<div style="margin-top:14px;border-top:1px solid #d1d5db;padding-top:6px;$font">$rows</div>';
}

class ComposedBody {
  final String text;
  final String? html;
  const ComposedBody(this.text, this.html);
}

/// Assemble message + signature pour les 3 voies d'envoi (simple, programmé,
/// en masse). La signature est ajoutée au moment de l'envoi (jamais écrite
/// dans le texte du message) : changer de signature la REMPLACE, sans empilement.
/// Sans signature : texte seul, comme avant.
///
/// [bodyHtml] : corps mis en forme par l'éditeur riche (Windows) ; s'il est
/// fourni, l'e-mail part en HTML + texte brut (multipart/alternative).
ComposedBody composeBody(String body, Signature? signature, {String? bodyHtml}) {
  if (signature == null && bodyHtml == null) return ComposedBody(body, null);
  final text = signature == null ? body : '$body\n\n${signatureText(signature)}';
  final inner = bodyHtml ?? _esc(body).replaceAll(RegExp(r'\r?\n'), '<br>');
  final html = '<div style="font-family:Arial,Helvetica,sans-serif;font-size:15px;color:#111827;line-height:1.5;">$inner</div>'
      '${signature == null ? '' : signatureHtml(signature)}';
  return ComposedBody(text, html);
}

/// Échappe un texte inséré dans du HTML (noms de contacts dans une campagne).
String escapeHtml(String v) => _esc(v);
