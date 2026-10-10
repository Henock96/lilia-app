/// Pages légales **canoniques** : celles du site, `www.liliafood.com`.
///
/// C-10 (audit du 09/10/2026) : l'app embarquait sa propre politique de
/// confidentialité, générique et inexacte — aucun sous-traitant nommé, une
/// promesse de désinscription des offres qui n'existe pas, des données « de
/// paiement » que l'app ne détient pas. Une copie compilée dans le binaire ne
/// peut être corrigée que par une release, et diverge du site. On ouvre donc
/// la version publiée, la même que celle déclarée aux stores.
abstract final class LegalLinks {
  static final termsOfUse = Uri.parse('https://www.liliafood.com/conditions');
  static final privacyPolicy = Uri.parse(
    'https://www.liliafood.com/confidentialite',
  );
}
