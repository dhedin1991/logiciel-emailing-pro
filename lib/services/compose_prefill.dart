import '../models/contact.dart';

/// Transporte une sélection de contacts depuis l'écran Contacts vers
/// l'écran Rédaction lorsqu'on clique "Rédiger" après une sélection.
/// Simple relais en mémoire (consommé une seule fois), cohérent avec
/// l'architecture actuelle qui bascule entre sections sans pile de
/// navigation.
class ComposePrefill {
  ComposePrefill._();
  static final ComposePrefill instance = ComposePrefill._();

  List<Contact>? pendingContacts;

  List<Contact>? consume() {
    final value = pendingContacts;
    pendingContacts = null;
    return value;
  }
}
