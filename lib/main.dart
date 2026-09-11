import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/compose_screen.dart';
import 'screens/contacts_home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_home_screen.dart';
import 'screens/templates_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/bulk_send_progress_panel.dart';
import 'screens/login_gate_screen.dart';
import 'services/scheduler_service.dart';
import 'services/send_jobs_manager.dart';
import 'services/theme_service.dart';

void main() {
  runApp(const EmailingProApp());
}

ThemeData _buildTheme(Brightness brightness, Color seedColor) {
  final base = ThemeData(
    colorSchemeSeed: seedColor,
    useMaterial3: true,
    brightness: brightness,
  );
  final textTheme = GoogleFonts.interTextTheme(base.textTheme);
  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor:
        brightness == Brightness.dark ? base.colorScheme.surface : base.colorScheme.surfaceContainerLowest,
    appBarTheme: AppBarTheme(
      backgroundColor: base.colorScheme.surface,
      foregroundColor: base.colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: base.colorScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: base.colorScheme.shadow.withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.12),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: base.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: base.colorScheme.primary, width: 1.5),
      ),
      filled: true,
      fillColor: base.colorScheme.surfaceContainerLow,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: base.colorScheme.outlineVariant),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: base.colorScheme.surfaceContainerLow,
      indicatorColor: base.colorScheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: base.colorScheme.onPrimaryContainer),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: base.colorScheme.primary,
      unselectedLabelColor: base.colorScheme.onSurfaceVariant,
      indicatorColor: base.colorScheme.primary,
    ),
  );
}

class EmailingProApp extends StatefulWidget {
  const EmailingProApp({super.key});

  @override
  State<EmailingProApp> createState() => _EmailingProAppState();
}

class _EmailingProAppState extends State<EmailingProApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final stopwatch = Stopwatch()..start();
    await ThemeService.instance.load();
    // Durée minimale d'affichage pour que le logo soit bien visible, même
    // si le chargement est quasi instantané.
    final remaining = const Duration(milliseconds: 900) - stopwatch.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) {
        final seed = ThemeService.instance.preset.seedColor;
        return MaterialApp(
          title: 'Emailing Pro',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light, seed),
          darkTheme: _buildTheme(Brightness.dark, seed),
          themeMode: ThemeService.instance.themeMode,
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _showSplash ? const _SplashScreen(key: ValueKey('splash')) : const LoginGateScreen(key: ValueKey('app'), child: HomeShell()),
          ),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logoPath = ThemeService.instance.customLogoPath;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logoPath != null && File(logoPath).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(File(logoPath), width: 84, height: 84, fit: BoxFit.cover),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: colorScheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.mark_email_read_outlined, size: 44, color: colorScheme.onPrimaryContainer),
              ),
            const SizedBox(height: 20),
            Text(
              'Emailing Pro',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ecran principal : contient la navigation entre les 7 sections.
/// S'adapte automatiquement : rail latéral sur grand écran (Windows),
/// barre en bas sur petit écran (Android).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  final _scheduler = SchedulerService();

  @override
  void initState() {
    super.initState();
    _scheduler.start();
  }

  @override
  void dispose() {
    _scheduler.stop();
    super.dispose();
  }

  static const List<_Section> _sections = [
    _Section('Tableau de bord', Icons.dashboard_outlined, Icons.dashboard),
    _Section('Contacts', Icons.people_outline, Icons.people),
    _Section('Modèles', Icons.description_outlined, Icons.description),
    _Section('Rédaction', Icons.edit_outlined, Icons.edit),
    _Section('Historique', Icons.history_outlined, Icons.history),
    _Section('Statistiques', Icons.bar_chart_outlined, Icons.bar_chart),
    _Section('Paramètres', Icons.settings_outlined, Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    Widget content;
    if (_selectedIndex == 0) {
      content = DashboardScreen(onNavigate: (i) => setState(() => _selectedIndex = i));
    } else if (_selectedIndex == 1) {
      content = const ContactsHomeScreen();
    } else if (_selectedIndex == 2) {
      content = const TemplatesScreen();
    } else if (_selectedIndex == 3) {
      content = const ComposeScreen();
    } else if (_selectedIndex == 4) {
      content = const HistoryHomeScreen();
    } else if (_selectedIndex == 5) {
      content = const StatisticsScreen();
    } else if (_selectedIndex == 6) {
      content = const SettingsScreen();
    } else {
      content = _PlaceholderScreen(title: _sections[_selectedIndex].label);
    }

    // Fondu doux entre les sections plutôt qu'un changement brutal.
    content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(key: ValueKey(_selectedIndex), child: content),
    );

    final onDashboard = _selectedIndex == 0;

    final appBar = AppBar(
      leading: onDashboard
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Retour au tableau de bord',
              onPressed: () => setState(() => _selectedIndex = 0),
            ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onDashboard) ...[
            _BrandMark(size: 22),
            const SizedBox(width: 10),
          ],
          Text(_sections[_selectedIndex].label),
        ],
      ),
      actions: const [_SendJobsIndicator(), SizedBox(width: 8)],
    );

    // Bouton retour physique (Android) : depuis n'importe quelle section,
    // ramène d'abord au tableau de bord au lieu de fermer l'app directement ;
    // depuis le tableau de bord, un appui supplémentaire quitte l'app.
    return PopScope(
      canPop: onDashboard,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _selectedIndex = 0);
      },
      child: _buildScaffold(context, isWide, appBar, content),
    );
  }

  Widget _buildScaffold(BuildContext context, bool isWide, PreferredSizeWidget appBar, Widget content) {

    if (isWide) {
      // Version large écran (Windows) : rail latéral avec en-tête de marque
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.of(context).size.width >= 1100,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: MediaQuery.of(context).size.width >= 1100
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: MediaQuery.of(context).size.width >= 1100
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BrandMark(size: 26),
                          const SizedBox(width: 10),
                          Text(
                            'Emailing Pro',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: -0.2,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      )
                    : _BrandMark(size: 26),
              ),
              destinations: _sections
                  .map((s) => NavigationRailDestination(
                        icon: Icon(s.icon),
                        selectedIcon: Icon(s.selectedIcon),
                        label: Text(s.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    // Version mobile (Android) : menu tiroir latéral au lieu d'une barre du bas surchargée
    return Scaffold(
      appBar: appBar,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _BrandMark(size: 28),
                    const SizedBox(width: 12),
                    Text('Emailing Pro', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: List.generate(_sections.length, (i) {
                    final section = _sections[i];
                    final selected = i == _selectedIndex;
                    return ListTile(
                      leading: Icon(selected ? section.selectedIcon : section.icon,
                          color: selected ? Theme.of(context).colorScheme.primary : null),
                      title: Text(
                        section.label,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      selected: selected,
                      onTap: () {
                        setState(() => _selectedIndex = i);
                        Navigator.pop(context);
                      },
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
      body: content,
    );
  }
}

/// Icône de marque affichée dans la barre du haut, le menu latéral et le
/// tiroir : le logo personnalisé s'il est défini, sinon l'icône par défaut.
class _BrandMark extends StatelessWidget {
  final double size;
  const _BrandMark({required this.size});

  @override
  Widget build(BuildContext context) {
    final path = ThemeService.instance.customLogoPath;
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Icon(Icons.mark_email_read_outlined, color: Theme.of(context).colorScheme.primary, size: size);
  }
}

class _Section {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Section(this.label, this.icon, this.selectedIcon);
}

/// Icône dans la barre du haut montrant combien de campagnes d'envoi
/// tournent actuellement en arrière-plan. Cliquer ouvre la liste, chacune
/// s'ouvre dans son propre panneau de suivi sans bloquer le reste de l'app.
class _SendJobsIndicator extends StatefulWidget {
  const _SendJobsIndicator();

  @override
  State<_SendJobsIndicator> createState() => _SendJobsIndicatorState();
}

class _SendJobsIndicatorState extends State<_SendJobsIndicator> {
  @override
  void initState() {
    super.initState();
    SendJobsManager.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    SendJobsManager.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _openJobsList() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final jobs = SendJobsManager.instance.jobs;
        if (jobs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Aucun envoi en cours ou récent.'),
          );
        }
        return ListView(
          shrinkWrap: true,
          children: jobs.reversed.map((job) {
            return ListTile(
              leading: Icon(job.queue.isRunning ? Icons.sync : Icons.check_circle_outline,
                  color: job.queue.isRunning ? Colors.blue : Colors.green),
              title: Text(job.label),
              subtitle: Text(job.queue.isRunning
                  ? '${job.queue.sentCount}/${job.queue.totalCount} envoyés'
                  : 'Terminé : ${job.queue.sentCount} envoyé(s), ${job.queue.failedCount} échec(s)'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => BulkSendProgressPanel(queue: job.queue),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = SendJobsManager.instance.activeCount;
    return IconButton(
      tooltip: 'Envois en cours',
      onPressed: _openJobsList,
      icon: Badge(
        label: Text('$count'),
        isLabelVisible: count > 0,
        child: const Icon(Icons.mark_email_read_outlined),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
