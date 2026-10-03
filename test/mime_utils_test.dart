import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:logiciel_emailing_pro/services/mime_utils.dart';

void main() {
  group('MimeUtils', () {
    test('cleanHeader supprime les retours à la ligne (anti-injection)', () {
      final cleaned = MimeUtils.cleanHeader('a@b.fr\r\nBcc: pirate@x.fr');
      expect(cleaned.contains('\n'), isFalse);
      expect(cleaned.contains('\r'), isFalse);
    });

    test('parseAddresses accepte plusieurs adresses valides', () {
      expect(MimeUtils.parseAddresses('a@b.fr, c@d.com'), ['a@b.fr', 'c@d.com']);
    });

    test('parseAddresses refuse une adresse invalide', () {
      expect(() => MimeUtils.parseAddresses('pas-une-adresse'), throwsFormatException);
    });

    test('fromHeader ajoute le nom d\'affichage', () {
      expect(MimeUtils.fromHeader('moi@x.fr', 'Marie Dupont'), '"Marie Dupont" <moi@x.fr>');
      expect(MimeUtils.fromHeader('moi@x.fr', null), 'moi@x.fr');
    });

    test('buildMessage contient les en-têtes essentiels et un corps base64', () {
      final msg = MimeUtils.buildMessage(
        from: 'moi@x.fr',
        fromEmail: 'moi@x.fr',
        to: ['a@b.fr'],
        subject: 'Bonjour é',
        textBody: 'Texte accentué',
      );
      expect(msg, contains('Date: '));
      expect(msg, contains('Message-ID: <'));
      expect(msg, contains('To: a@b.fr'));
      expect(msg, contains('Content-Transfer-Encoding: base64'));
      expect(msg, contains(base64.encode(utf8.encode('Texte accentué'))));
    });

    test('buildMessage avec HTML produit un multipart/alternative', () {
      final msg = MimeUtils.buildMessage(
        from: 'moi@x.fr',
        fromEmail: 'moi@x.fr',
        to: ['a@b.fr'],
        subject: 's',
        textBody: 't',
        htmlBody: '<b>t</b>',
      );
      expect(msg, contains('multipart/alternative'));
      expect(msg, contains('text/html'));
    });

    test('en-têtes supplémentaires (List-Unsubscribe) sont inclus', () {
      final msg = MimeUtils.buildMessage(
        from: 'moi@x.fr',
        fromEmail: 'moi@x.fr',
        to: ['a@b.fr'],
        subject: 's',
        textBody: 't',
        extraHeaders: {'List-Unsubscribe': '<mailto:moi@x.fr>'},
      );
      expect(msg, contains('List-Unsubscribe: <mailto:moi@x.fr>'));
    });
  });
}
