import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Suit si le tutoriel de bienvenue a déjà été affiché, pour ne le montrer
/// qu'une seule fois (au tout premier lancement de l'application).
class OnboardingService {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/onboarding_seen.flag');
  }

  Future<bool> hasSeenOnboarding() async {
    try {
      return await (await _file()).exists();
    } catch (_) {
      return true; // en cas d'erreur, ne pas embêter l'utilisateur avec le tutoriel
    }
  }

  Future<void> markSeen() async {
    try {
      await (await _file()).writeAsString('1');
    } catch (_) {}
  }
}
