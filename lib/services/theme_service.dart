import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Mode d'affichage choisi par l'utilisateur (indépendant du thème système).
enum AppBrightnessMode { system, light, dark }

/// Une palette de couleurs proposée dans "Apparence".
class AppThemePreset {
  final String id;
  final String label;
  final Color seedColor;
  const AppThemePreset({required this.id, required this.label, required this.seedColor});
}

const List<AppThemePreset> appThemePresets = [
  AppThemePreset(id: 'blue', label: 'Bleu professionnel', seedColor: Color(0xFF2563EB)),
  AppThemePreset(id: 'indigo', label: 'Indigo nuit', seedColor: Color(0xFF4F46E5)),
  AppThemePreset(id: 'emerald', label: 'Émeraude', seedColor: Color(0xFF059669)),
  AppThemePreset(id: 'teal', label: 'Sarcelle moderne', seedColor: Color(0xFF0D9488)),
  AppThemePreset(id: 'amber', label: 'Ambre chaleureux', seedColor: Color(0xFFD97706)),
  AppThemePreset(id: 'rose', label: 'Rose élégant', seedColor: Color(0xFFE11D48)),
  AppThemePreset(id: 'violet', label: 'Violet créatif', seedColor: Color(0xFF7C3AED)),
  AppThemePreset(id: 'slate', label: 'Graphite sobre', seedColor: Color(0xFF334155)),
];

/// Service global (singleton) qui gère le thème de couleur choisi et le mode
/// clair/sombre/système. Persisté dans un simple fichier local (même
/// approche que la session, fiable sur Windows/Android).
class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  String _presetId = 'blue';
  AppBrightnessMode _mode = AppBrightnessMode.system;
  bool _loaded = false;

  String get presetId => _presetId;
  AppBrightnessMode get mode => _mode;

  AppThemePreset get preset =>
      appThemePresets.firstWhere((p) => p.id == _presetId, orElse: () => appThemePresets.first);

  ThemeMode get themeMode {
    switch (_mode) {
      case AppBrightnessMode.light:
        return ThemeMode.light;
      case AppBrightnessMode.dark:
        return ThemeMode.dark;
      case AppBrightnessMode.system:
        return ThemeMode.system;
    }
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/theme_prefs.json');
  }

  /// À appeler une fois au démarrage, avant le premier build.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final id = data['presetId'] as String?;
        if (id != null && appThemePresets.any((p) => p.id == id)) {
          _presetId = id;
        }
        _mode = AppBrightnessMode.values.firstWhere(
          (m) => m.name == data['mode'],
          orElse: () => AppBrightnessMode.system,
        );
      }
    } catch (_) {
      // Valeurs par défaut si le fichier est absent ou corrompu.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode({'presetId': _presetId, 'mode': _mode.name}));
    } catch (_) {
      // Non bloquant : le choix reste actif pour la session en cours.
    }
  }

  Future<void> setPreset(String id) async {
    if (_presetId == id) return;
    _presetId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(AppBrightnessMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _save();
  }
}
