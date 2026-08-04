import 'package:flutter/foundation.dart';
import 'bulk_send_queue_service.dart';

class SendJob {
  final String id;
  final String label;
  final BulkSendQueueService queue;
  final DateTime startedAt;

  SendJob({required this.id, required this.label, required this.queue, required this.startedAt});
}

/// Garde la trace de tous les envois en masse en cours, même quand
/// l'utilisateur navigue ailleurs dans l'application. Chaque campagne
/// (par exemple une par compte) tourne indépendamment et reste
/// strictement séquentielle EN SON SEIN — seul le fait d'avoir
/// plusieurs campagnes différentes en parallèle est nouveau ici.
class SendJobsManager extends ChangeNotifier {
  SendJobsManager._();
  static final instance = SendJobsManager._();

  final List<SendJob> jobs = [];

  void addJob(SendJob job) {
    jobs.add(job);
    notifyListeners();
    job.queue.addListener(notifyListeners);
  }

  void removeFinishedJobs() {
    jobs.removeWhere((j) => !j.queue.isRunning);
    notifyListeners();
  }

  int get activeCount => jobs.where((j) => j.queue.isRunning).length;
}
