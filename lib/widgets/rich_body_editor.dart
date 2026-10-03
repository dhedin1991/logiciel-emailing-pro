import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Éditeur de texte riche (Windows uniquement) : police, taille, gras,
/// italique, souligné, couleur, alignement, listes, liens — avec la barre
/// d'outils collée au-dessus de la zone de message.
class RichBodyEditor extends StatelessWidget {
  final QuillController controller;
  final double height;

  const RichBodyEditor({super.key, required this.controller, this.height = 420});

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: Theme.of(context).dividerColor);
    return Container(
      decoration: BoxDecoration(
        border: Border.fromBorderSide(border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(border: Border(bottom: border)),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: QuillSimpleToolbar(
              controller: controller,
              config: const QuillSimpleToolbarConfig(
                showSubscript: false,
                showSuperscript: false,
                showInlineCode: false,
                showCodeBlock: false,
                showQuote: false,
                showSearchButton: false,
                showListCheck: false,
                showIndent: false,
              ),
            ),
          ),
          SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: QuillEditor.basic(
                controller: controller,
                config: const QuillEditorConfig(
                  placeholder: 'Écrivez votre message…',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
