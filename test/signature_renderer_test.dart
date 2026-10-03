import 'package:flutter_test/flutter_test.dart';
import 'package:logiciel_emailing_pro/models/signature.dart';
import 'package:logiciel_emailing_pro/services/signature_renderer.dart';

Signature _corporate() => Signature(
      id: '1',
      name: 'Pro',
      content: '',
      format: 'corporate',
      fields: {
        'name': 'Marie Dupont',
        'function': 'Directrice',
        'direction': 'Commerciale',
        'company': 'Acme',
        'phone': '+229 01 02',
        'email': 'marie@acme.com',
        'confidentiality': 'Message confidentiel.',
      },
    );

void main() {
  group('Signatures', () {
    test('les champs vides ne s\'affichent pas', () {
      final sig = Signature(
        id: '1',
        name: 'x',
        content: '',
        format: 'classic',
        fields: {'name': 'Marie', 'email': 'm@x.fr'},
      );
      final lines = signatureLines(sig).map((l) => l.text).toList();
      expect(lines, ['Marie', 'm@x.fr']);
    });

    test('format grande entreprise : société en majuscules, mentions', () {
      final lines = signatureLines(_corporate()).map((l) => l.text).toList();
      expect(lines, contains('ACME'));
      expect(lines, contains('Directrice | Commerciale'));
      expect(lines, contains('T : +229 01 02'));
    });

    test('version texte commence par le séparateur "-- "', () {
      expect(signatureText(_corporate()).startsWith('-- \n'), isTrue);
    });

    test('HTML : petits caractères gras gris (11 px)', () {
      final html = signatureHtml(_corporate());
      expect(html, contains('font-size:11.0px'));
      expect(html, contains('font-weight:bold'));
      expect(html, contains('#6b7280'));
    });

    test('sans signature ni mise en forme : texte seul', () {
      final c = composeBody('Bonjour', null);
      expect(c.text, 'Bonjour');
      expect(c.html, isNull);
    });

    test('avec signature : texte + HTML, corps échappé', () {
      final c = composeBody('a < b', _corporate());
      expect(c.text, contains('-- \n'));
      expect(c.html, contains('a &lt; b'));
    });

    test('changer de signature remplace, sans empiler', () {
      final a = composeBody('Hello', _corporate());
      final other = Signature(id: '2', name: 'x', content: 'Autre', format: 'text');
      final b = composeBody('Hello', other);
      expect(b.text.contains('ACME'), isFalse);
      expect('-- \n'.allMatches(a.text).length, 1);
    });
  });
}
