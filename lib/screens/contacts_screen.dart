import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/contact.dart';
import '../services/contact_import_service.dart';
import '../services/contact_storage.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/empty_state.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _storage = ContactStorage();
  final _importService = ContactImportService();
  final _uuid = const Uuid();

  List<Contact> _contacts = [];
  bool _loading = true;
  bool _importing = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _storage.loadContacts();
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _importFile() async {
    setState(() {
      _importing = true;
      _statusMessage = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'txt'],
      );
      if (result == null || result.files.single.path == null) {
        setState(() => _importing = false);
        return;
      }
      final imported = await _importService.importFromFile(result.files.single.path!);
      final added = await _storage.addContacts(imported);
      await _loadContacts();
      setState(() {
        _statusMessage = '$added contact(s) ajouté(s) (${imported.length - added} déjà existant(s) ignoré(s)).';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Échec de l'import : ${e.toString()}";
        _statusIsError = true;
      });
    } finally {
      setState(() => _importing = false);
    }
  }

  Future<void> _showAddContactDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final companyController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'E-mail')),
            TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Entreprise (facultatif)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ajouter')),
        ],
      ),
    );

    if (saved == true && emailController.text.trim().isNotEmpty) {
      await _storage.addContact(Contact(
        id: _uuid.v4(),
        name: nameController.text.trim().isEmpty ? emailController.text.trim() : nameController.text.trim(),
        email: emailController.text.trim(),
        company: companyController.text.trim(),
      ));
      await _loadContacts();
    }
  }

  Future<void> _removeContact(String id) async {
    final contact = _contacts.firstWhere((c) => c.id == id);
    if (!await confirmDelete(context, contact.name)) return;
    await _storage.removeContact(id);
    await _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Carnet d\'adresses (${_contacts.length})',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              OutlinedButton.icon(
                onPressed: _importing ? null : _importFile,
                icon: _importing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file),
                label: Text(_importing ? 'Import…' : 'Importer Excel/CSV'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _showAddContactDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_statusMessage!, style: TextStyle(color: _statusIsError ? Colors.red : Colors.green)),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _contacts.isEmpty
                ? const EmptyState(
                    icon: Icons.people_outline,
                    title: 'Aucun contact pour le moment',
                    subtitle: 'Ajoutez un contact ou importez un fichier CSV, Excel ou texte.',
                  )
                : ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(contact.name),
                          subtitle: Text(contact.email + (contact.company.isNotEmpty ? ' • ${contact.company}' : '')),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeContact(contact.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
