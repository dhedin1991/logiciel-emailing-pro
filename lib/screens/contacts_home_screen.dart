import 'package:flutter/material.dart';
import 'contacts_screen.dart';
import 'contact_lists_screen.dart';

class ContactsHomeScreen extends StatelessWidget {
  const ContactsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Contacts'),
              Tab(text: 'Listes'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ContactsScreen(),
                ContactListsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
