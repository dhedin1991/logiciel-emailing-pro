import 'package:flutter/material.dart';
import 'accounts_screen.dart';
import 'signatures_screen.dart';
import 'sync_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Comptes'),
              Tab(text: 'Signatures'),
              Tab(text: 'Synchronisation'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AccountsScreen(),
                SignaturesScreen(),
                SyncScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
