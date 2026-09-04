# Refonte `restaurant_detail` (app client) — design

Date : 2026-06-12 · Périmètre : `lilia-backend` (vendors) + `lilia-app` (home/detail vendeur)

## Problème

L'écran de détail vendeur (`restaurant_detail_screen.dart`) :
1. Déclenche une **2ᵉ requête DB** (`GET /menus/active?restaurantId=...` via `MenusSection`)
   en plus de `GET /vendors/:id`, à chaque ouverture — redondant.
2. Empile trop de sections verticales (statut, spécialités, menus, story) avant
   que les produits soient visibles.

## Changements

### 1. Menus actifs embarqués dans `/vendors/:id`
- **Backend** (`vendors.service.ts`) : `VENDOR_DETAIL_INCLUDE` (const) devient une
  fonction `vendorDetailInclude(now = new Date())` qui ajoute la relation
  `menuDuJour` filtrée `{ isActive: true, dateDebut: { lte: now }, dateFin: { gte: now } }`,
  avec le même `include` imbriqué que `MenuQueryService.getActiveMenus`
  (`products.product.category/variants`, `restaurant` select id/nom/imageUrl, `images`)
  et `orderBy: { dateDebut: 'desc' }`. `findOne` appelle `vendorDetailInclude()`.
- **Frontend** (`models/restaurant.dart`) : nouveau champ `List<MenuDuJour> menus`
  (défaut `const []`) parsé depuis `json['menuDuJour']`.
- Résultat : 0 requête supplémentaire.

### 2. Toggle Ouvert/Fermé fusionné avec les spécialités
- `_VendorIdentityCard` : `Row[ Expanded(Wrap[ chip Ouvert/Fermé, ...chips spécialités ]), rating ]`.
- La section `_SpecialtyChipsSection` (sliver dédié) est supprimée.

### 3. Menus dans l'AppBar (bottom sheet)
- Sliver `MenusSection` retiré ; `menus_section.dart` supprimé (plus utilisé).
- `_VendorHeroAppBar` reçoit `hasMenus` + `onMenus` → icône `restaurant_menu` dans
  `actions` **seulement si `restaurant.menus.isNotEmpty`**.
- Tap → `showModalBottomSheet` « Menus du Jour » + liste horizontale de `MenuCard`
  (réutilisé), lisant `restaurant.menus` (déjà en mémoire). `onTap` → route `menuDetail`.
- `activeMenus` provider + `menu_repo.getActiveMenus` conservés (couche data réutilisable,
  plus consommés par cet écran).

### 4. Story « À propos » pliable
- `_VendorProfileSection` → `StatefulWidget`. Si `profile.story` existe : header
  « À propos » + chevron, replié par défaut (aperçu 2 lignes), tap pour déplier.
  Certifications / spécialités profil / note de production inchangés.

## Notes
- `build_runner` non requis (aucun `@riverpod` modifié).
- `VENDOR_DETAIL_INCLUDE` n'a qu'un seul appelant (`findOne`) — vérifié.
- `MenuDuJour.fromJson` exige `json['restaurant']` → l'include embarqué le fournit.
