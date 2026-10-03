import 'package:flutter/material.dart';

Future<bool> confirmDelete(BuildContext context, String itemLabel) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmer la suppression'),
      content: Text('Supprimer "$itemLabel" ? Cette action est irréversible.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Supprime immédiatement un élément ; il part dans la corbeille (où il peut
/// être restauré). Plus de barre "Annuler" qui reste affichée en bas : un
/// court message de 2 secondes confirme simplement l'action.
Future<void> deleteWithUndo({
  required BuildContext context,
  required String itemLabel,
  required Future<void> Function() onDelete,
  Future<void> Function()? onUndo,
}) async {
  await onDelete();
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text('"$itemLabel" déplacé dans la corbeille.'),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Double confirmation pour une suppression définitive sans corbeille
/// (comptes d'envoi et leurs mots de passe).
Future<bool> confirmDeleteTwice(BuildContext context, String itemLabel) async {
  final first = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer définitivement ?'),
      content: Text('"$itemLabel" et son mot de passe seront effacés. Ils ne passent pas par la corbeille.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuer')),
      ],
    ),
  );
  if (first != true || !context.mounted) return false;
  final second = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Dernière confirmation'),
      content: Text('Confirmez-vous la suppression DÉFINITIVE de "$itemLabel" ? Cette action est irréversible.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non, garder')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Supprimer définitivement'),
        ),
      ],
    ),
  );
  return second ?? false;
}
