import 'package:flutter/material.dart';
import 'accounts_screen.dart';
import 'signatures_screen.dart';
import 'sync_screen.dart';
import 'security_screen.dart';
import 'about_screen.dart';
import 'appearance_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Comptes'),
              Tab(text: 'Apparence'),
              Tab(text: 'Signatures'),
              Tab(text: 'Synchronisation'),
              Tab(text: 'Sécurité'),
              Tab(text: 'À propos'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AccountsScreen(),
                AppearanceScreen(),
                SignaturesScreen(),
                SyncScreen(),
                SecurityScreen(),
                AboutScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
