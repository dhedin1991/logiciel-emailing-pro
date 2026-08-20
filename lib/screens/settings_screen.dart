import 'package:flutter/material.dart';
import 'accounts_screen.dart';
import 'signatures_screen.dart';
import 'sync_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Comptes'),
              Tab(text: 'Signatures'),
              Tab(text: 'Synchronisation'),
              Tab(text: 'Sécurité'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AccountsScreen(),
                SignaturesScreen(),
                SyncScreen(),
                SecurityScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
