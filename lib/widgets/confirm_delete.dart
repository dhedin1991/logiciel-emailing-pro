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

/// Supprime immédiatement un élément unique et propose de revenir en
/// arrière via un message "Annuler" pendant quelques secondes — à la place
/// d'une boîte de confirmation systématique. À utiliser uniquement pour les
/// suppressions d'un seul élément à la fois (pas les suppressions groupées).
Future<void> deleteWithUndo({
  required BuildContext context,
  required String itemLabel,
  required Future<void> Function() onDelete,
  required Future<void> Function() onUndo,
}) async {
  await onDelete();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('"$itemLabel" supprimé.'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Annuler',
        onPressed: () {
          onUndo();
        },
      ),
    ),
  );
}
