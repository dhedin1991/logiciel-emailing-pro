import 'package:flutter/material.dart';
import 'dart:io';
import '../services/sync_service.dart';
import '../services/local_backup_service.dart';
import '../services/local_wifi_sync_service.dart';

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
  final _localBackupService = LocalBackupService();
  bool _creatingBackup = false;

  // Synchro Wi-Fi locale.
  final _wifiHostController = TextEditingController();
  final _wifiCodeController = TextEditingController();
  List<String> _wifiLocalAddresses = [];
  bool _wifiBusy = false;
  String? _wifiStatusMessage;
  bool _wifiStatusIsError = false;
  bool _wifiScanning = false;
  List<DiscoveredDevice> _discoveredDevices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeInputController.dispose();
    _wifiHostController.dispose();
    _wifiCodeController.dispose();
    LocalWifiSyncServer.instance.stop();
    super.dispose();
  }

  Future<void> _toggleWifiServer() async {
    setState(() => _wifiBusy = true);
    try {
      if (LocalWifiSyncServer.instance.isRunning) {
        await LocalWifiSyncServer.instance.stop();
        if (!mounted) return;
        setState(() {
          _wifiStatusMessage = 'Serveur arrêté.';
          _wifiStatusIsError = false;
        });
      } else {
        await LocalWifiSyncServer.instance.start();
        final addresses = await LocalWifiSyncServer.localAddresses();
        if (!mounted) return;
        setState(() {
          _wifiLocalAddresses = addresses;
          _wifiStatusMessage = addresses.isEmpty
              ? 'Serveur démarré, mais aucune adresse réseau locale détectée — vérifiez que le Wi-Fi est actif.'
              : null;
          _wifiStatusIsError = addresses.isEmpty;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wifiStatusMessage = friendlyWifiSyncError(e);
        _wifiStatusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _wifiBusy = false);
    }
  }

  Future<void> _scanForDevices() async {
    setState(() {
      _wifiScanning = true;
      _discoveredDevices = [];
    });
    final devices = await LocalWifiSyncServer.discoverDevices();
    if (!mounted) return;
    setState(() {
      _discoveredDevices = devices;
      _wifiScanning = false;
      if (devices.isEmpty) {
        _wifiStatusMessage = 'Aucun appareil trouvé. Vérifiez que l\'autre appareil a bien démarré le serveur '
            'et que les deux sont sur le même Wi-Fi (pas de VPN actif).';
        _wifiStatusIsError = true;
      }
    });
  }

  ({String host, int port})? _parseHostPort() {
    final raw = _wifiHostController.text.trim();
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final port = int.tryParse(parts[1]);
    if (port == null) return null;
    return (host: parts[0], port: port);
  }

  Future<void> _wifiPush() async {
    final parsed = _parseHostPort();
    final code = _wifiCodeController.text.trim();
    if (parsed == null || code.isEmpty) {
      setState(() {
        _wifiStatusMessage = 'Renseignez l\'adresse (ex : 192.168.1.12:54321) et le code affiché sur l\'autre appareil.';
        _wifiStatusIsError = true;
      });
      return;
    }
    setState(() {
      _wifiBusy = true;
      _wifiStatusMessage = null;
    });
    try {
      await LocalWifiSyncClient().pushTo(parsed.host, parsed.port, code);
      if (!mounted) return;
      setState(() {
        _wifiStatusMessage = 'Données envoyées avec succès vers l\'autre appareil.';
        _wifiStatusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wifiStatusMessage = friendlyWifiSyncError(e);
        _wifiStatusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _wifiBusy = false);
    }
  }

  Future<void> _wifiPull() async {
    final parsed = _parseHostPort();
    final code = _wifiCodeController.text.trim();
    if (parsed == null || code.isEmpty) {
      setState(() {
        _wifiStatusMessage = 'Renseignez l\'adresse (ex : 192.168.1.12:54321) et le code affiché sur l\'autre appareil.';
        _wifiStatusIsError = true;
      });
      return;
    }
    setState(() {
      _wifiBusy = true;
      _wifiStatusMessage = null;
    });
    try {
      await LocalWifiSyncClient().pullFrom(parsed.host, parsed.port, code);
      if (!mounted) return;
      setState(() {
        _wifiStatusMessage = 'Données récupérées avec succès depuis l\'autre appareil.';
        _wifiStatusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wifiStatusMessage = friendlyWifiSyncError(e);
        _wifiStatusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _wifiBusy = false);
    }
  }

  Future<void> _load() async {
    final code = await _syncService.getOrCreateSyncCode();
    final lastBackup = await _syncService.lastBackupAt();
    final reminderDays = await _syncService.reminderFrequencyDays();
    if (!mounted) return;
    setState(() {
      _syncCode = code;
      _lastBackupAt = lastBackup;
      _reminderDays = reminderDays;
      _loading = false;
    });
  }

  Future<void> _push() async {
    // Détection de conflit : si le cloud a été modifié depuis la dernière
    // fois qu'on l'a récupéré ici, prévenir avant d'écraser silencieusement
    // les changements faits sur l'autre appareil.
    final remoteUpdatedAt = await _syncService.remoteUpdatedAt();
    final lastPulled = await _syncService.lastPulledAt();
    if (!mounted) return;
    if (remoteUpdatedAt != null && (lastPulled == null || remoteUpdatedAt.isAfter(lastPulled))) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Le cloud a changé'),
          content: const Text(
            'Le cloud contient des modifications plus récentes que la dernière fois que vous avez récupéré '
            'des données ici (probablement faites sur votre autre appareil). '
            'Envoyer maintenant écrasera ces modifications. '
            'Il est recommandé de d\'abord cliquer "Récupérer depuis le cloud" pour ne rien perdre.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Envoyer quand même'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await _syncService.pushAll();
      final lastBackup = await _syncService.lastBackupAt();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Contacts, modèles et signatures envoyés vers le cloud.';
        _statusIsError = false;
        _lastBackupAt = lastBackup;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = friendlySyncError(e);
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pull() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await _syncService.pullAll();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Contacts, modèles et signatures récupérés depuis le cloud.';
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = friendlySyncError(e);
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkDevice() async {
    if (_codeInputController.text.trim().isEmpty) return;
    await _syncService.setSyncCode(_codeInputController.text);
    await _load();
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Appareil lié. Cliquez "Récupérer depuis le cloud" pour importer vos données.';
      _statusIsError = false;
    });
  }

  Future<void> _createLocalBackupNow() async {
    setState(() => _creatingBackup = true);
    try {
      await _localBackupService.createBackupNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sauvegarde locale créée.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec : ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _creatingBackup = false);
    }
  }

  Future<void> _showLocalBackups() async {
    final backups = await _localBackupService.listBackups();
    if (!mounted) return;
    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune sauvegarde locale pour le moment.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sauvegardes locales'),
        content: SizedBox(
          width: 450,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: backups.length,
            itemBuilder: (context, index) {
              final file = backups[index];
              final name = file.path.split(Platform.pathSeparator).last;
              return ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(name),
                trailing: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _localBackupService.restoreBackup(file);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sauvegarde restaurée (fusion, rien n\'a été écrasé).')),
                    );
                  },
                  child: const Text('Restaurer'),
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
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
            const Divider(height: 40),
            Text('Synchronisation Wi-Fi (réseau local)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Transférez vos contacts, modèles et signatures directement entre deux appareils sur le même '
              'Wi-Fi, sans passer par Internet. Un appareil démarre le serveur, l\'autre s\'y connecte avec '
              'l\'adresse et le code affichés.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _wifiBusy ? null : _toggleWifiServer,
                  icon: Icon(LocalWifiSyncServer.instance.isRunning ? Icons.stop_circle_outlined : Icons.wifi_tethering),
                  label: Text(LocalWifiSyncServer.instance.isRunning ? 'Arrêter le serveur' : 'Démarrer le serveur ici'),
                ),
              ],
            ),
            if (LocalWifiSyncServer.instance.isRunning) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sur l\'autre appareil, saisissez :', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (_wifiLocalAddresses.isEmpty)
                      const Text('Adresse réseau introuvable — vérifiez que le Wi-Fi est bien actif.')
                    else
                      ..._wifiLocalAddresses.map(
                        (addr) => SelectableText(
                          'Adresse : $addr:${LocalWifiSyncServer.instance.port}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                        ),
                      ),
                    const SizedBox(height: 4),
                    SelectableText(
                      'Code : ${LocalWifiSyncServer.instance.pairingCode}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 2),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Se connecter à un autre appareil', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _wifiScanning ? null : _scanForDevices,
              icon: _wifiScanning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_find),
              label: Text(_wifiScanning ? 'Recherche en cours...' : 'Rechercher les appareils sur le Wi-Fi'),
            ),
            if (_discoveredDevices.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._discoveredDevices.map(
                (d) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: const Icon(Icons.devices_other),
                    title: Text(d.deviceLabel),
                    subtitle: Text('${d.host}:${d.port}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _wifiHostController.text = '${d.host}:${d.port}'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _wifiHostController,
              decoration: const InputDecoration(
                labelText: 'Adresse de l\'autre appareil (ex : 192.168.1.12:54321)',
                border: OutlineInputBorder(),
                isDense: true,
                helperText: 'Remplie automatiquement en choisissant un appareil trouvé ci-dessus.',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _wifiCodeController,
              decoration: const InputDecoration(
                labelText: 'Code affiché sur l\'autre appareil',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _wifiBusy ? null : _wifiPush,
                  icon: const Icon(Icons.upload),
                  label: const Text('Envoyer vers cet appareil'),
                ),
                OutlinedButton.icon(
                  onPressed: _wifiBusy ? null : _wifiPull,
                  icon: const Icon(Icons.download),
                  label: const Text('Récupérer depuis cet appareil'),
                ),
              ],
            ),
            if (_wifiStatusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_wifiStatusMessage!, style: TextStyle(color: _wifiStatusIsError ? Colors.red : Colors.green)),
              ),
            const Divider(height: 40),
            Text('Sauvegarde locale automatique', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'En plus de la synchro cloud, l\'application crée automatiquement une copie locale de vos contacts, '
              'modèles et signatures une fois par jour (les 5 plus récentes sont conservées, sur cet appareil uniquement).',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _creatingBackup ? null : _createLocalBackupNow,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_creatingBackup ? 'Création...' : 'Créer une sauvegarde maintenant'),
                ),
                OutlinedButton.icon(
                  onPressed: _showLocalBackups,
                  icon: const Icon(Icons.history),
                  label: const Text('Voir les sauvegardes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
