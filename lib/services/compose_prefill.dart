import '../models/contact.dart';
import '../models/email_draft.dart';

/// Transporte une sélection de contacts depuis l'écran Contacts vers
/// l'écran Rédaction lorsqu'on clique "Rédiger" après une sélection.
/// Simple relais en mémoire (consommé une seule fois), cohérent avec
/// l'architecture actuelle qui bascule entre sections sans pile de
/// navigation.
class ComposePrefill {
  ComposePrefill._();
  static final ComposePrefill instance = ComposePrefill._();

  List<Contact>? pendingContacts;

  /// Brouillon à rouvrir (depuis la page Brouillons), consommé une seule fois.
  EmailDraft? pendingDraft;

  EmailDraft? consumeDraft() {
    final value = pendingDraft;
    pendingDraft = null;
    return value;
  }

  List<Contact>? consume() {
    final value = pendingContacts;
    pendingContacts = null;
    return value;
  }
}
