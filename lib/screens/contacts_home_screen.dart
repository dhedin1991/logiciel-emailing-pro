import 'package:flutter/material.dart';
import 'contacts_screen.dart';
import 'contact_lists_screen.dart';
import 'email_cleaning_screen.dart';

class ContactsHomeScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigate;
  const ContactsHomeScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Contacts'),
              Tab(text: 'Listes'),
              Tab(text: 'Nettoyage e-mails'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ContactsScreen(onNavigate: onNavigate),
                const ContactListsScreen(),
                const EmailCleaningScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
