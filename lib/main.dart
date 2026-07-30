import 'package:flutter/material.dart';
import 'screens/accounts_screen.dart';

void main() {
  runApp(const EmailingProApp());
}

class EmailingProApp extends StatelessWidget {
  const EmailingProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emailing Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2563EB),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2563EB),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
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

    // Section "Paramètres" (index 6) affiche déjà la gestion des comptes.
    // Les autres sections restent à construire dans les prochaines étapes.
    final content = _selectedIndex == 6
        ? const AccountsScreen()
        : _PlaceholderScreen(title: _sections[_selectedIndex].label);

    if (isWide) {
      // Version large écran (Windows) : rail latéral
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.of(context).size.width >= 1100,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: MediaQuery.of(context).size.width >= 1100
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
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

    // Version mobile (Android) : barre de navigation en bas
    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: _sections
            .map((s) => NavigationDestination(
                  icon: Icon(s.icon),
                  selectedIcon: Icon(s.selectedIcon),
                  label: s.label,
                ))
            .toList(),
      ),
    );
  }
}

class _Section {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Section(this.label, this.icon, this.selectedIcon);
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
