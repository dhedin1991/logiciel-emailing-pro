import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/theme_service.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  bool _busy = false;

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final dir = await getApplicationSupportDirectory();
      final ext = (result.files.single.extension ?? 'png').toLowerCase();
      final dest = File('${dir.path}/custom_logo.$ext');
      await dest.writeAsBytes(result.files.single.bytes!);
      await ThemeService.instance.setCustomLogoPath(dest.path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeLogo() async {
    await ThemeService.instance.setCustomLogoPath(null);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) {
        final theme = ThemeService.instance;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apparence', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    "Choisissez la palette de couleurs et le mode d'affichage du logiciel.",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 28),
                  Text('Mode d\'affichage', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<AppBrightnessMode>(
                    segments: const [
                      ButtonSegment(
                        value: AppBrightnessMode.system,
                        label: Text('Système'),
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: AppBrightnessMode.light,
                        label: Text('Clair'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: AppBrightnessMode.dark,
                        label: Text('Sombre'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {theme.mode},
                    onSelectionChanged: (selection) => theme.setMode(selection.first),
                  ),
                  const SizedBox(height: 32),
                  Text('Palette de couleurs', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Le thème choisi s\'applique immédiatement à tout le logiciel.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: appThemePresets.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 190,
                      mainAxisExtent: 84,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final p = appThemePresets[index];
                      final selected = p.id == theme.presetId;
                      return _ThemeSwatchCard(
                        preset: p,
                        selected: selected,
                        onTap: () => theme.setPreset(p.id),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Text('Logo personnalisé', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Affiché à la place de l\'icône par défaut, dans la barre du haut et le menu latéral.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (theme.customLogoPath != null && File(theme.customLogoPath!).existsSync())
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(theme.customLogoPath!), width: 48, height: 48, fit: BoxFit.cover),
                        )
                      else
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.mark_email_read_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _pickLogo,
                        icon: const Icon(Icons.upload_outlined),
                        label: Text(_busy ? 'Chargement...' : 'Choisir une image'),
                      ),
                      if (theme.customLogoPath != null) ...[
                        const SizedBox(width: 8),
                        TextButton(onPressed: _removeLogo, child: const Text('Retirer')),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThemeSwatchCard extends StatelessWidget {
  final AppThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSwatchCard({required this.preset, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? preset.seedColor : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected ? preset.seedColor.withValues(alpha: 0.08) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: preset.seedColor,
                  boxShadow: [
                    BoxShadow(color: preset.seedColor.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  preset.label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
