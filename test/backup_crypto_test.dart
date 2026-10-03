import 'package:flutter_test/flutter_test.dart';
import 'package:logiciel_emailing_pro/services/backup_crypto.dart';

void main() {
  group('BackupCrypto (mot de passe)', () {
    test('chiffre puis déchiffre avec le bon mot de passe', () async {
      const plain = '{"contacts":[{"name":"Élodie"}]}';
      final encrypted = await BackupCrypto.encrypt(plain, passphrase: 'secret1234');
      expect(encrypted.contains('Élodie'), isFalse);
      expect(BackupCrypto.isEncrypted(encrypted), isTrue);
      expect(BackupCrypto.needsPassphrase(encrypted), isTrue);
      expect(await BackupCrypto.decrypt(encrypted, passphrase: 'secret1234'), plain);
    });

    test('mauvais mot de passe : refusé', () async {
      final encrypted = await BackupCrypto.encrypt('abc', passphrase: 'bon-mot-de-passe');
      expect(() => BackupCrypto.decrypt(encrypted, passphrase: 'mauvais'),
          throwsA(isA<BackupWrongPassphrase>()));
    });

    test('mot de passe manquant : demandé', () async {
      final encrypted = await BackupCrypto.encrypt('abc', passphrase: 'bon-mot-de-passe');
      expect(() => BackupCrypto.decrypt(encrypted), throwsA(isA<BackupPassphraseRequired>()));
    });

    test('ancien fichier non chiffré : accepté tel quel', () async {
      const plain = '{"contacts":[]}';
      expect(BackupCrypto.isEncrypted(plain), isFalse);
      expect(await BackupCrypto.decrypt(plain), plain);
    });
  });
}
