import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/contact.dart';
import '../models/sent_email_log.dart';
import '../services/contact_import_service.dart';
import '../services/contact_storage.dart';
import '../services/history_storage.dart';
import '../services/export_helper.dart';
import '../services/import_history_storage.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/empty_state.dart';
import '../widgets/sort_menu_button.dart';
import '../widgets/skeleton_loader.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _storage = ContactStorage();
  final _importService = ContactImportService();
  final _uuid = const Uuid();
  final _searchController = TextEditingController();

  List<Contact> _contacts = [];
  bool _loading = true;
  bool _importing = false;
  String? _statusMessage;
  bool _statusIsError = false;

  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  String? _tagFilter;
  String? _statusFilter;
  String? _countryFilter;
  String? _dateFilter;
  String _sortField = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contacts = await _storage.loadContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _selectedIds.removeWhere((id) => !contacts.any((c) => c.id == id));
      _loading = false;
    });
  }

  List<Contact> get _filteredContacts {
    final list = _contacts.where((c) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = c.name.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q) ||
            c.domain.toLowerCase().contains(q) ||
            c.company.toLowerCase().contains(q);
        if (!matches) return false;
      }
      if (_tagFilter != null && !c.tags.contains(_tagFilter)) return false;
      if (_statusFilter != null && c.status != _statusFilter) return false;
      if (_countryFilter != null && c.country != _countryFilter) return false;
      if (_dateFilter != null) {
        final days = int.parse(_dateFilter!);
        if (DateTime.now().difference(c.createdAt).inDays > days) return false;
      }
      return true;
    }).toList();

    int compare(Contact a, Contact b) {
      switch (_sortField) {
        case 'email':
          return a.email.toLowerCase().compareTo(b.email.toLowerCase());
        case 'company':
          return a.company.toLowerCase().compareTo(b.company.toLowerCase());
        case 'status':
          return a.status.toLowerCase().compareTo(b.status.toLowerCase());
        case 'name':
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    }

    list.sort((a, b) => _sortAscending ? compare(a, b) : compare(b, a));
    return list;
  }

  void _setSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
    });
  }

  Future<void> _exportContacts() async {
    final buffer = StringBuffer('Nom;Email;Entreprise;Telephone;Statut;Etiquettes;Note\n');
    for (final c in _filteredContacts) {
      buffer.writeln([
        csvField(c.name),
        csvField(c.email),
        csvField(c.company),
        csvField(c.phone),
        csvField(c.status),
        csvField(c.tags.join(', ')),
        csvField(c.note),
      ].join(';'));
    }
    try {
      final exported = await exportTextFile(content: buffer.toString(), suggestedFileName: 'contacts', extension: 'csv');
      if (!mounted || !exported) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export terminé.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'export : ${e.toString()}')),
      );
    }
  }

  Future<void> _exportContactsExcel() async {
    try {
      final exported = await exportExcelFile(
        headers: const ['Nom', 'Email', 'Entreprise', 'Téléphone', 'Statut', 'Étiquettes', 'Note'],
        rows: _filteredContacts
            .map((c) => [c.name, c.email, c.company, c.phone, c.status, c.tags.join(', '), c.note])
            .toList(),
        suggestedFileName: 'contacts',
      );
      if (!mounted || !exported) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export terminé.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec de l\'export : ${e.toString()}')));
    }
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
        if (mounted) setState(() => _importing = false);
        return;
      }
      final imported = await _importService.importFromFile(result.files.single.path!);
      final added = await _storage.addContacts(imported);
      await ImportHistoryStorage().add(ImportLogEntry(
        id: _uuid.v4(),
        type: 'contact_import',
        timestamp: DateTime.now(),
        summary: 'Import contacts : ${imported.length} lu(s), $added nouveau(x) ajouté(s)'
            ' (${imported.length - added} déjà existant(s))',
      ));
      await _loadContacts();
      if (!mounted) return;
      setState(() {
        _statusMessage = '$added contact(s) ajouté(s) (${imported.length - added} déjà existant(s) ignoré(s)).';
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = "Échec de l'import : ${e.toString()}";
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _showContactDialog({Contact? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final companyController = TextEditingController(text: existing?.company ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    final tagInputController = TextEditingController();
    final selectedTags = <String>{...(existing?.tags ?? [])};
    var status = existing?.status ?? '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Ajouter un contact' : 'Modifier le contact'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom')),
                  const SizedBox(height: 8),
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: 'E-mail')),
                  const SizedBox(height: 8),
                  TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Entreprise (facultatif)')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status.isEmpty ? null : status,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: const [
                      DropdownMenuItem(value: 'Actif', child: Text('Actif')),
                      DropdownMenuItem(value: 'Inactif', child: Text('Inactif')),
                      DropdownMenuItem(value: 'Ne plus contacter', child: Text('Ne plus contacter')),
                    ],
                    onChanged: (value) => setDialogState(() => status = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  const Text('Étiquettes', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: predefinedContactTags
                        .map((tag) => FilterChip(
                              label: Text(tag),
                              selected: selectedTags.contains(tag),
                              onSelected: (sel) => setDialogState(() {
                                if (sel) {
                                  selectedTags.add(tag);
                                } else {
                                  selectedTags.remove(tag);
                                }
                              }),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tagInputController,
                          decoration: const InputDecoration(labelText: 'Étiquette personnalisée'),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              setDialogState(() {
                                selectedTags.add(value.trim());
                                tagInputController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Ajouter l\'étiquette',
                        onPressed: () {
                          if (tagInputController.text.trim().isNotEmpty) {
                            setDialogState(() {
                              selectedTags.add(tagInputController.text.trim());
                              tagInputController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (selectedTags.any((t) => !predefinedContactTags.contains(t)))
                    Wrap(
                      spacing: 6,
                      children: selectedTags
                          .where((t) => !predefinedContactTags.contains(t))
                          .map((t) => Chip(
                                label: Text(t),
                                onDeleted: () => setDialogState(() => selectedTags.remove(t)),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );

    if (saved == true && emailController.text.trim().isNotEmpty) {
      if (existing == null) {
        await _storage.addContact(Contact(
          id: _uuid.v4(),
          name: nameController.text.trim().isEmpty ? emailController.text.trim() : nameController.text.trim(),
          email: emailController.text.trim(),
          company: companyController.text.trim(),
          tags: selectedTags.toList(),
          note: noteController.text.trim(),
          status: status,
        ));
      } else {
        await _storage.updateContact(existing.copyWith(
          name: nameController.text.trim().isEmpty ? emailController.text.trim() : nameController.text.trim(),
          email: emailController.text.trim(),
          company: companyController.text.trim(),
          tags: selectedTags.toList(),
          note: noteController.text.trim(),
          status: status,
        ));
      }
      await _loadContacts();
    }
    nameController.dispose();
    emailController.dispose();
    companyController.dispose();
    noteController.dispose();
    tagInputController.dispose();
  }

  Future<void> _showHistoryFor(Contact contact) async {
    final allHistory = await HistoryStorage().loadAll();
    final related = allHistory.where((e) => e.to.toLowerCase() == contact.email.toLowerCase()).toList();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Historique — ${contact.name}'),
        content: SizedBox(
          width: 450,
          height: 350,
          child: related.isEmpty
              ? const Center(child: Text('Aucun e-mail envoyé à ce contact pour le moment.'))
              : ListView.builder(
                  itemCount: related.length,
                  itemBuilder: (context, index) {
                    final SentEmailLog e = related[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(e.success ? Icons.check_circle : Icons.error,
                          color: e.success ? Colors.green : Colors.red, size: 18),
                      title: Text(e.subject.isEmpty ? '(sans objet)' : e.subject),
                      subtitle: Text('${e.sentAt.day}/${e.sentAt.month}/${e.sentAt.year}'),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  Future<void> _removeContact(String id) async {
    final contact = _contacts.firstWhere((c) => c.id == id);
    await deleteWithUndo(
      context: context,
      itemLabel: contact.name,
      onDelete: () async {
        await _storage.removeContact(id);
        await _loadContacts();
      },
      onUndo: () async {
        await _storage.addContact(contact);
        await _loadContacts();
      },
    );
  }

  void _toggleSelectAll(bool? checked) {
    final visible = _filteredContacts;
    setState(() {
      if (checked == true) {
        _selectedIds.addAll(visible.map((c) => c.id));
      } else {
        _selectedIds.removeWhere((id) => visible.any((c) => c.id == id));
      }
    });
  }

  Future<void> _deleteSelection() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Vous êtes sur le point de supprimer ${_selectedIds.length} contact(s). Voulez-vous continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.removeContacts(_selectedIds);
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    await _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SkeletonListLoader();
    }

    final visible = _filteredContacts;
    final allSelected = visible.isNotEmpty && visible.every((c) => _selectedIds.contains(c.id));
    final allTags = _contacts.expand((c) => c.tags).toSet().toList()..sort();
    final allCountries = _contacts.map((c) => c.country).whereType<String>().toSet().toList()..sort();

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
                onPressed: _contacts.isEmpty ? null : _exportContacts,
                icon: const Icon(Icons.download),
                label: const Text('Exporter CSV'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _contacts.isEmpty ? null : _exportContactsExcel,
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Exporter Excel'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _importing ? null : _importFile,
                icon: _importing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file),
                label: Text(_importing ? 'Import…' : 'Importer Excel/CSV'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showContactDialog(),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Rechercher (nom, e-mail, domaine, entreprise)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String?>(
                hint: const Text('Étiquette'),
                value: _tagFilter,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Toutes les étiquettes')),
                  ...allTags.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                ],
                onChanged: (value) => setState(() => _tagFilter = value),
              ),
              const SizedBox(width: 12),
              DropdownButton<String?>(
                hint: const Text('Statut'),
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tous les statuts')),
                  DropdownMenuItem(value: 'Actif', child: Text('Actif')),
                  DropdownMenuItem(value: 'Inactif', child: Text('Inactif')),
                  DropdownMenuItem(value: 'Ne plus contacter', child: Text('Ne plus contacter')),
                ],
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
              DropdownButton<String?>(
                hint: const Text('Pays'),
                value: _countryFilter,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous les pays')),
                  ...allCountries.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (value) => setState(() => _countryFilter = value),
              ),
              DropdownButton<String?>(
                hint: const Text('Ajoutés'),
                value: _dateFilter,
                items: const [
                  DropdownMenuItem(value: null, child: Text('À tout moment')),
                  DropdownMenuItem(value: '7', child: Text('7 derniers jours')),
                  DropdownMenuItem(value: '30', child: Text('30 derniers jours')),
                  DropdownMenuItem(value: '90', child: Text('90 derniers jours')),
                ],
                onChanged: (value) => setState(() => _dateFilter = value),
              ),
            ],
          ),
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(value: allSelected, onChanged: _toggleSelectAll),
                const Text('Tout sélectionner'),
                const SizedBox(width: 16),
                if (_selectedIds.isNotEmpty) Text('${_selectedIds.length} sélectionné(s)'),
                const Spacer(),
                SortMenuButton(
                  currentField: _sortField,
                  ascending: _sortAscending,
                  options: const {
                    'name': 'Nom',
                    'email': 'E-mail',
                    'company': 'Entreprise',
                    'status': 'Statut',
                  },
                  onSelected: _setSort,
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelection,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Supprimer la sélection'),
                  style: TextButton.styleFrom(foregroundColor: _selectedIds.isEmpty ? null : Colors.red),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: visible.isEmpty
                ? const EmptyState(
                    icon: Icons.people_outline,
                    title: 'Aucun contact',
                    subtitle: 'Ajoutez un contact, importez un fichier, ou changez vos filtres.',
                  )
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final contact = visible[index];
                      final selected = _selectedIds.contains(contact.id);
                      return Card(
                        child: ListTile(
                          leading: Checkbox(
                            value: selected,
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _selectedIds.add(contact.id);
                              } else {
                                _selectedIds.remove(contact.id);
                              }
                            }),
                          ),
                          title: Text(contact.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(contact.email + (contact.company.isNotEmpty ? ' • ${contact.company}' : '')),
                              if (contact.tags.isNotEmpty || contact.status.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Wrap(
                                    spacing: 4,
                                    children: [
                                      if (contact.status.isNotEmpty)
                                        Chip(
                                          label: Text(contact.status, style: const TextStyle(fontSize: 11)),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ...contact.tags.map((t) => Chip(
                                            label: Text(t, style: const TextStyle(fontSize: 11)),
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          )),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: contact.tags.isNotEmpty || contact.status.isNotEmpty,
                          onTap: () => _showContactDialog(existing: contact),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.history),
                                tooltip: 'Historique',
                                onPressed: () => _showHistoryFor(contact),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Supprimer le contact',
                                onPressed: () => _removeContact(contact.id),
                              ),
                            ],
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
