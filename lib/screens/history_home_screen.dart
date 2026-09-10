import 'package:flutter/material.dart';
import 'history_screen.dart';
import 'imports_history_screen.dart';

class HistoryHomeScreen extends StatelessWidget {
  const HistoryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Envoyés'),
              Tab(text: 'Non envoyés / Échecs'),
              Tab(text: 'Imports'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                HistoryScreen(onlySuccess: true),
                HistoryScreen(onlySuccess: false),
                ImportsHistoryScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
