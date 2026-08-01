import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/signature.dart';
import '../services/signature_storage.dart';

class SignaturesScreen extends StatefulWidget {
  const SignaturesScreen({super.key});

  @override
  State<SignaturesScreen> createState() => _SignaturesScreenState();
}

class _SignaturesScreenState extends State<SignaturesScreen> {
  final _storage = SignatureStorage();
  final _uuid = const Uuid();
  List<Signature> _signatures = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final signatures = await _storage.loadSignatures();
    setState(() {
      _signatures = signatures;
      _loading = false;
    });
  }

  Future<void> _showEditor({Signature? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final contentController = TextEditingController(text: existing?.content ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nouvelle signature' : 'Modifier la signature'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom (ex : Pro, Perso)')),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Contenu de la signature'),
                maxLines: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      if (existing == null) {
        await _storage.addSignature(Signature(
          id: _uuid.v4(),
          name: nameController.text.trim(),
          content: contentController.text,
        ));
      } else {
        await _storage.updateSignature(Signature(
          id: existing.id,
          name: nameController.text.trim(),
          content: contentController.text,
        ));
      }
      await _load();
    }
  }

  Future<void> _remove(String id) async {
    await _storage.removeSignature(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Signatures', style: Theme.of(context).textTheme.headlineSmall)),
              FilledButton.icon(
                onPressed: () => _showEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle signature'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _signatures.isEmpty
                ? const Center(child: Text('Aucune signature pour le moment.'))
                : ListView.builder(
                    itemCount: _signatures.length,
                    itemBuilder: (context, index) {
                      final signature = _signatures[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.edit_note),
                          title: Text(signature.name),
                          subtitle: Text(signature.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _showEditor(existing: signature),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _remove(signature.id),
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
