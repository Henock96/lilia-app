# Lilia Food — Rapport d'accessibilité (Phase 3)

**Date :** 29/09/2026 · **App :** `lilia-app` (client) + tokens admin/livreur · **Branche :** `hmipoka/uiux-phase3-impl`

## 1. Ce qui a été réellement vérifié, et comment

| Méthode | Portée | Statut |
|---|---|---|
| Tests widget avec **vraies polices** (`test/helpers/real_fonts.dart`), écran 360 × 780 dp, facteurs 1.0 / 1.3 / 1.5 / 2.0 | 10 composants (voir §2) | ✅ exécuté, 40 cas verts |
| Calcul WCAG 2.x des ratios (fonction `contrastRatio`, bornes 21:1 et 1:1 testées) sur les couleurs **effectives** des thèmes | client clair/sombre, admin, livreur | ✅ exécuté |
| `flutter_test` guidelines (tap targets Android/iOS, contraste, libellés) | tests préexistants `accessibility_guidelines_test.dart` | ✅ verts |
| TalkBack (Android) / VoiceOver (iOS) | — | ❌ **NON EXÉCUTÉ** — aucun pilotage du lecteur d'écran dans cette session |
| Captures appareil à 1.5× / 2× après correctif | — | ❌ **NON REFAIT** (les captures de la Discovery sont antérieures aux correctifs) |

## 2. Texte agrandi

### Le test existant ne mesurait rien sur les composants animés

`test/a11y/text_scaling_test.dart` pompait **deux** frames. Les cartes « Plats populaires » entrent avec `flutter_animate` (`fadeIn` à opacité 0) : un enfant à opacité 0 n'est pas peint, et un `RenderFlex` ne signale son débordement **qu'à la peinture**. Le test était vert pendant que l'appareil affichait « BOTTOM OVERFLOWED BY 7 PIXELS » à 1.5× et masquait prix et « + » à 2×.

Correctif du test : `pumpUntilAnimationsPainted` (40 frames de 50 ms). Il échoue alors à 1.5× et 2× sur l'ancien code — **exactement le constat appareil** — puis passe après correctif.

Deuxième angle mort : un `Row` ne signale pas le débordement sur l'axe transversal. Les puces du filtre vendeur (40 px fixes) coupaient le texte à 2× (ligne plafonnée à 24 px pour un corps de 26 px) **sans aucune erreur**. `filter_bar_scaling_test.dart` compare la hauteur rendue du texte à sa taille de police ; vérifié rouge avant correctif, vert après.

### Composants couverts (1.0 / 1.3 / 1.5 / 2.0)

Plats populaires · carte produit vendeur · sélecteur de formats · récapitulatif checkout · carte fidélité · **filtre par type de vendeur** · **pied de panier (prix)** · **timeline de commande** (nouveaux dans cette phase).

### Corrections

| Composant | Avant | Après |
|---|---|---|
| Cartes « Plats populaires » | hauteur 220 fixe, nom sur 1 ligne | hauteur dérivée du `TextScaler` (jamais < 220), nom sur 2 lignes |
| Puces filtre vendeur | 40 px fixes | `max(40, scale(14)×1.4 + 16)` |
| Timeline de commande | 4 libellés 11 px côte à côte | liste verticale, 14 px |
| Barre de progression de la liste | 4 libellés 9 px en vert | une ligne 12,5 px `onSurfaceVariant` |
| Pied de panier | `Row` libellé/total/bouton | lignes en `Wrap`, bouton pleine largeur |

Aucune réduction de taille de police n'a été utilisée pour résoudre un débordement.

## 3. Contrastes (calculés)

| Paire | Avant | Après | Où |
|---|---:|---:|---|
| Blanc sur `primary` sombre (`orange400`) | 2,84:1 | `onPrimary` (`charcoal700`) 6,20:1 | CTA « Valider et payer », « Appliquer », « Continuer », pastille prix produit, « Commander à nouveau », « Voir mes commandes », FAB adresses, stepper quantité, `PrimaryButton`, icône appareil photo du profil |
| `Colors.red` + blanc | 3,68:1 | `error`/`onError` ≥ 4,5:1 (testé) | annulation de commande (liste et détail), suppression d'adresse, « Vider et ajouter » |
| `outline` en icône/texte (clair) | 1,26:1 | `onSurfaceVariant` ≥ 4,5:1 | cœur favori, chevrons, « réglages » de la recherche, textes d'états vides, horloge des commandes, bordure « Enregistrer pour plus tard » |
| Snackbar succès (`green500`) | 4,39:1 | `green700` ≥ 4,5:1 | tous les succès |
| Snackbar erreur (`red400`) | < 4,5:1 | `red500` ≥ 4,5:1 | toutes les erreurs |
| Sous-titres « À propos » (`grey[500]`) | ≈ 2,6:1 | `onSurfaceVariant` | contacts |
| **Admin** fond des boutons (`orange500`) | 3,67:1 | `orange600` 4,94:1 | tous les `ElevatedButton`, FAB |
| **Admin** blanc sur orange sombre | 2,84:1 | `charcoal700` 6,20:1 | idem en sombre |
| **Admin** `textMuted` | 4,36:1 / 3,42:1 | `charcoal450` / `charcoal300` | petits textes |
| **Livreur** boutons (`#FF6B00`) | 2,86:1 | `#C8421A` 4,94:1 | tous les boutons |
| **Livreur** `textLight` (`#9E9E9E`) | 2,68:1 | `#6E6E6E` ≥ 4,5:1 | textes secondaires |
| **Livreur** succès / erreur sous blanc | 2,78 / 3,68:1 | `#2E7D32` / `#C62828` ≥ 4,5:1 | pastilles, boutons |

Gardes de non-régression : `lilia-app/test/theme/contrast_test.dart` (+14 cas), `lilia-food-admin/test/theme/contrast_test.dart`, `lilia_food_delivery/test/utilities/contrast_test.dart`.

Non corrigé et assumé : icônes de remplissage d'image (placeholder `fastfood`/`restaurant`) en `outline` — décoratives ; `--text-muted` du site client (2,47:1) — **token défini mais utilisé nulle part** dans `apps/web` (vérifié par recherche), donc sans effet aujourd'hui.

## 4. Sémantique et interactions

- Cœur favori : zone de tap 36 → **48 px** (dessin inchangé).
- « Suivre le livreur en direct » : `GestureDetector` nu → `Semantics(button: true, label:)`.
- Timeline : chaque étape annoncée « libellé, état, précision » ; l'étape **en cours** est une *live region* (changement de statut annoncé).
- ETA : *live region*.
- Bandeau hors ligne : *live region*.
- Ajout au panier : annoncé par le `SnackBar` Material (déjà *live region*) — aucune annonce en double ajoutée.
- Badge notifications : l'infobulle dit « Notifications, N non lues ».
- Barre de progression de la liste : « Étape X sur N : … ».

## 5. Animations réduites

`fadeSlideIn`, `fadeScaleIn`, `staggeredIn` rendent le widget directement quand `MediaQuery.disableAnimations` est vrai (`reduced_motion_test.dart`). Le carrousel le faisait déjà.

## 6. Validations manuelles encore nécessaires

1. **TalkBack** (Android) et **VoiceOver** (iOS) : Accueil → fiche vendeur → produit → panier → checkout → détail de commande ; vérifier l'ordre de lecture, l'annonce de l'ajout, du changement d'étape, de l'ETA et du bandeau hors ligne.
2. Captures appareil à **1.5× et 2×** (Android + iOS), clair et sombre : accueil, panier, checkout, détail de commande.
3. Contraste perçu en **plein soleil** pour l'app livreur (nouvel orange).
4. Clavier externe / focus : non audité.
