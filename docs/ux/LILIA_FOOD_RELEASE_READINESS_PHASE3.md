# Lilia Food — Release readiness (Phase 3)

**Date :** 29/09/2026 · **App :** `lilia-app` `1.3.5+39` · **Branche :** `hmipoka/uiux-phase3-impl` (non commitée, non poussée)
**Aucune soumission, aucun build de release, aucune publication n'a été effectué.**

## 1. Version

| Élément | Valeur | Vérification |
|---|---|---|
| `pubspec.yaml` | `1.3.5+39` | lu |
| Page « À propos » | lit `PackageInfo` → « Version 1.3.5 (39) » | `about_page_test.dart` ; **en build installé** : visible au prochain build (non vérifié à l'œil sur l'iPhone) |
| Build de release | **non lancé** | `tool/release.sh` exige `SENTRY_DSN` et la clé Maps : à lancer sur le poste de release |

## 2. Permissions

| Plateforme | Permission | Usage réel | État |
|---|---|---|---|
| iOS | `NSLocationWhenInUseUsageDescription` | placer l'adresse de livraison sur la carte | ✅ corrigé (P3-27) : « Votre position sert à placer votre adresse de livraison sur la carte, lorsque vous le demandez. » — il promettait « les restaurants proches », que l'accueil n'affiche pas (Guideline 5.1.1) ; garde dans `ios_release_config_test` |
| iOS | `NSLocationAlwaysAndWhenInUseUsageDescription` | requis par ITMS-90683 (geolocator SwiftPM) | ✅ texte sans promesse d'arrière-plan (test `ios_release_config_test`) — non régressé |
| iOS/Android | notifications | suivi de commande | ⚠️ demandées **au premier lancement**, par-dessus l'onboarding (P3-17, non traité) |
| Android | `ACCESS_FINE/COARSE_LOCATION`, `POST_NOTIFICATIONS`, `INTERNET`, `VIBRATE` | idem | ✅ pas de permission superflue ; `<queries>` VIEW `tel`/`https`/`geo`/`market` présents |
| iOS | photothèque | `image_picker` (PHPicker) | à confirmer dans les e-mails ITMS de la dernière soumission |

Sentry `9.30.1` (stable) : non régressé.

## 3. Paiement

- Encaissement **pawaPay** (MTN/Airtel), montant = `order.total` du serveur, instructions issues du serveur.
- Phase 3 : le dialogue d'échec de commande distingue désormais **l'issue inconnue** (délai dépassé : « votre commande a peut-être été enregistrée… ») de l'échec ; la clé d'idempotence est conservée, un nouvel essai ne crée pas de doublon (`order_error_presentation_test.dart`). Aucune fausse confirmation, aucun paiement présenté comme réussi ou échoué sans verdict serveur.
- **Aucun paiement réel n'a été effectué** dans cette phase.

### Proposition de notes App Review (à compléter par l'équipe)

1. Compte de démonstration : **à créer par l'équipe** (non créé ici — aucun faux compte).
2. Parcours : Accueil → une boutique ouverte → « + » → Panier (sous-total, frais de service, livraison annoncés) → « Passer la commande » → mode de réception → Checkout.
3. Paiement : Mobile Money (MTN / Airtel Congo) via pawaPay ; le reviewer ne peut pas payer depuis l'étranger. Indiquer soit une commande de démonstration déjà payée sur le compte démo (suivi, détail, reçu PDF visibles), soit le mode sandbox si l'équipe en ouvre un. **Ne pas** simuler de paiement réussi.
4. Support : « Profil → À propos → Nous contacter / Assistance téléphonique » et « Besoin d'aide ? » sur chaque commande — désormais fonctionnels.
5. Suppression de compte : Profil → Supprimer mon compte.

## 4. Validation appareils

| Appareil | Fait dans cette phase |
|---|---|
| iPhone 12 Pro (iOS 26.5), USB, **profile** | harnais de perf exécuté 7 fois (le 8ᵉ interrompu : iPhone déconnecté) (voir `LILIA_FOOD_PERFORMANCE_REPORT.md`) ; ⚠️ l'app installée a été **remplacée par un build profile** : réinstaller depuis TestFlight / App Store |
| Android physique | **aucun disponible** — NON TESTÉ |
| Émulateur Android | non lancé dans cette phase |
| Texte 1.5× / 2×, sombre, TalkBack / VoiceOver, mode avion | **non refaits sur appareil** après correctifs (couverts par tests widget) |

## 5. Qualité (exécuté)

| Dépôt | `flutter analyze` | `dart analyze` | Tests |
|---|---|---|---|
| lilia-app | 0 | 0 | **1019/1019** (911 à la baseline) ; `cart_optimistic_test` instable sous charge (préexistant, vérifié sur `origin/master`) |
| lilia-food-admin | 0 | 0 | 333/333 |
| lilia_food_delivery | 0 | — | 104/104 |
| lilia-food-web / lilia-backend | non modifiés — non exécutés | | |

## 6. Actions restantes avant soumission

1. Commit + PR des trois branches, CI verte (dont « Code généré à jour » : deux `.g.dart` régénérés).
2. `tool/release.sh android|ios` sur le poste de release ; `boot-smoke.sh` backend si déploiement associé.
3. Parcours connecté complet (checkout → paiement réel de faible montant → suivi → livraison / retrait → historique) avec un compte de test : **non fait**.
4. TalkBack + VoiceOver (checklist du rapport d'accessibilité).
5. Confirmer le numéro de support `+242 06 745 46 10` (publié uniquement dans l'app).
6. Remplacer ou ré-uploader les **2 photos vendeur supprimées de Cloudinary** (servies par le cache CDN seulement) : `lilia-food/restaurants/vbtu1ptyvrkjnvuh1tap`, `…/opetsoa6ij5owdauvf6y`.
7. Catalogue : un vendeur public « Le Cyprien Bar à Vin » alors que le lancement exclut l'alcool (constat Discovery, non réexaminé) — classification d'âge.
8. Décider du moment de la demande de permission notifications (P3-17).
