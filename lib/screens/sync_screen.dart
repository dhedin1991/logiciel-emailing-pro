import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _syncService = SyncService();
  final _codeInputController = TextEditingController();
  String _syncCode = '';
  bool _loading = true;
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final code = await _syncService.getOrCreateSyncCode();
    setState(() {
      _syncCode = code;
      _loading = false;
    });
  }

  Future<void> _push() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await _syncService.pushAll();
      setState(() {
        _statusMessage = 'Contacts, modèles et signatures envoyés vers le cloud.';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Échec : ${e.toString()}';
        _statusIsError = true;
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _pull() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await _syncService.pullAll();
      setState(() {
        _statusMessage = 'Contacts, modèles et signatures récupérés depuis le cloud.';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Échec : ${e.toString()}';
        _statusIsError = true;
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _linkDevice() async {
    if (_codeInputController.text.trim().isEmpty) return;
    await _syncService.setSyncCode(_codeInputController.text);
    await _load();
    setState(() {
      _statusMessage = 'Appareil lié. Cliquez "Récupérer depuis le cloud" pour importer vos données.';
      _statusIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Synchronisation Windows ↔ Android', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Synchronise contacts, modèles et signatures entre vos appareils. '
              'Les comptes e-mail connectés ne sont jamais synchronisés : reconnectez Gmail séparément sur chaque appareil.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            Text('Code de synchronisation de cet appareil', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(_syncCode, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            Text(
              'Ne le partagez avec personne d\'autre que vous-même : il donne accès à vos données synchronisées.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _push,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Envoyer vers le cloud'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pull,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Récupérer depuis le cloud'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Lier un autre appareil', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Sur votre autre appareil, ouvrez cette page et copiez son code plus haut, '
              'PUIS collez-le ici pour lier CET appareil au même compte de synchronisation.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeInputController,
                    decoration: const InputDecoration(labelText: 'Code de l\'autre appareil', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _linkDevice, child: const Text('Lier')),
              ],
            ),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_statusMessage!, style: TextStyle(color: _statusIsError ? Colors.red : Colors.green)),
              ),
          ],
        ),
      ),
    );
  }
}
