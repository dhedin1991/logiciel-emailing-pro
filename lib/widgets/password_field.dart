import 'package:flutter/material.dart';

/// Champ de mot de passe avec un bouton "œil" pour afficher ou masquer la
/// saisie. À utiliser partout où un mot de passe est demandé dans l'app,
/// pour que l'utilisateur puisse vérifier ce qu'il a tapé avant de valider.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final InputBorder? border;

  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.focusNode,
    this.onSubmitted,
    this.autofocus = false,
    this.border,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      obscureText: !_visible,
      // Sur Android, un champ mot de passe masqué combiné à la correction
      // automatique du clavier provoque un bug connu : la "zone de
      // composition" du clavier se désynchronise du texte réel, ce qui fait
      // qu'effacer une lettre semble ne rien faire ou fait réapparaître la
      // lettre juste effacée. Désactiver la correction/suggestions sur ce
      // type de champ est la correction recommandée par Flutter, pas un
      // contournement approximatif.
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: widget.border,
        suffixIcon: IconButton(
          icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          tooltip: _visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe',
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}
