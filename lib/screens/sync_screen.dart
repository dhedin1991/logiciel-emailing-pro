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
  DateTime? _lastBackupAt;
  int _reminderDays = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final code = await _syncService.getOrCreateSyncCode();
    final lastBackup = await _syncService.lastBackupAt();
    final reminderDays = await _syncService.reminderFrequencyDays();
    setState(() {
      _syncCode = code;
      _lastBackupAt = lastBackup;
      _reminderDays = reminderDays;
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
      final lastBackup = await _syncService.lastBackupAt();
      setState(() {
        _statusMessage = 'Contacts, modèles et signatures envoyés vers le cloud.';
        _statusIsError = false;
        _lastBackupAt = lastBackup;
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
            Builder(builder: (context) {
              final daysSince = _lastBackupAt == null ? null : DateTime.now().difference(_lastBackupAt!).inDays;
              final isOld = daysSince == null || daysSince >= _reminderDays;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isOld ? Colors.orange : Colors.green).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(isOld ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: isOld ? Colors.orange : Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastBackupAt == null
                            ? 'Aucune sauvegarde vers le cloud n\'a encore été faite.'
                            : daysSince == 0
                                ? 'Dernière sauvegarde : aujourd\'hui.'
                                : 'Dernière sauvegarde : il y a $daysSince jour(s).'
                                    '${isOld ? ' Pensez à sauvegarder vos données.' : ''}',
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Me rappeler si aucune sauvegarde depuis : '),
                DropdownButton<int>(
                  value: _reminderDays,
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('3 jours')),
                    DropdownMenuItem(value: 7, child: Text('7 jours')),
                    DropdownMenuItem(value: 14, child: Text('14 jours')),
                    DropdownMenuItem(value: 30, child: Text('30 jours')),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    await _syncService.setReminderFrequencyDays(value);
                    setState(() => _reminderDays = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
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
