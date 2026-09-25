import 'package:lilia_app/models/modifier.dart';

/// F3-09 — état du sélecteur d'options d'une fiche produit.
///
/// ## De l'ergonomie, pas des règles
///
/// Cet objet ne décide de rien à la place du serveur. Il sert trois gestes
/// d'interface :
///
/// - un groupe à choix unique se comporte en bouton radio (choisir remplace) ;
/// - un groupe à choix multiple refuse d'aller au-delà de `maxSelect` — on
///   n'invite pas le client à composer ce que le serveur refusera ;
/// - le bouton « Ajouter » reste désactivé tant qu'un groupe obligatoire est
///   incomplet, et **dit lequel**.
///
/// La validation qui compte — option en rupture depuis l'ouverture de la
/// fiche, prix, appartenance — est celle du serveur, à l'ajout puis au
/// checkout. Son refus est affiché tel quel.
///
/// Les cardinalités comptent des options **distinctes** (« Œuf ×2 » = un choix),
/// exactement comme le serveur.
class ModifierSelectionState {
  ModifierSelectionState(this.groups);

  final List<ModifierGroup> groups;

  /// optionId → quantité.
  final Map<String, int> _chosen = {};

  bool isSelected(String optionId) => _chosen.containsKey(optionId);

  int quantityOf(String optionId) => _chosen[optionId] ?? 0;

  int _countIn(ModifierGroup group) =>
      group.options.where((o) => _chosen.containsKey(o.id)).length;

  /// Choisit ou retire une option. Rend `false` si le geste est refusé
  /// (option en rupture, plafond du groupe atteint).
  bool toggle(ModifierGroup group, ModifierOption option) {
    if (!option.isAvailable) return false;
    if (_chosen.containsKey(option.id)) {
      // Un choix unique obligatoire ne se « décoche » pas : on change d'avis
      // en choisissant une autre option, comme un bouton radio.
      if (group.isSingleChoice && group.isRequired) return true;
      _chosen.remove(option.id);
      return true;
    }
    if (group.isSingleChoice) {
      for (final other in group.options) {
        _chosen.remove(other.id);
      }
      _chosen[option.id] = 1;
      return true;
    }
    if (_countIn(group) >= group.maxSelect) return false;
    _chosen[option.id] = 1;
    return true;
  }

  /// Change la quantité d'une option déjà choisie, bornée à `1..maxQuantity`.
  void setQuantity(ModifierOption option, int quantity) {
    if (!_chosen.containsKey(option.id)) return;
    _chosen[option.id] = quantity.clamp(1, option.maxQuantity);
  }

  /// Le premier groupe obligatoire incomplet, ou `null` si tout est prêt.
  ModifierGroup? get firstIncompleteGroup {
    for (final group in groups) {
      if (_countIn(group) < group.minSelect) return group;
    }
    return null;
  }

  /// Libellé du bouton quand l'ajout est impossible, `null` sinon.
  String? get blockingReason {
    final group = firstIncompleteGroup;
    if (group == null) return null;
    return group.minSelect > 1
        ? 'Choisissez ${group.minSelect} × « ${group.name} »'
        : 'Choisissez « ${group.name} »';
  }

  /// Les options choisies, dans l'ordre de la carte — ce qu'affichent le
  /// panier optimiste et le panier invité avant la réponse du serveur.
  List<LineOption> get lines => [
    for (final group in groups)
      for (final option in group.options)
        if (_chosen.containsKey(option.id))
          LineOption(
            optionId: option.id,
            groupName: group.name,
            name: option.name,
            priceDeltaXaf: option.priceDeltaXaf,
            quantity: _chosen[option.id]!,
          ),
  ];

  /// Valeur unitaire des suppléments choisis — affichage seulement.
  int get optionsValue =>
      lines.fold(0, (sum, o) => sum + o.priceDeltaXaf * o.quantity);
}
