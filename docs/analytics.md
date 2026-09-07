# Analytics — application client

> **La référence n'est pas ici.** Le contrat Analytics Lilia Food est unique
> pour les trois plateformes et vit dans le dépôt web :
>
> **`lilia-food-web/docs/analytics.md`**
>
> Ce fichier n'est qu'un point d'entrée. Le dupliquer ferait exactement ce que
> le contrat existe pour empêcher : deux versions qui divergent sans que
> personne ne s'en aperçoive.

## Ce qu'il faut savoir avant de toucher à la mesure

1. **N'appelez jamais `FirebaseAnalytics.instance` depuis un écran.** Passez par
   `AnalyticsService` (`lib/services/analytics_service.dart`). C'est cette
   indirection qui applique la liste blanche des paramètres, la désinfection des
   données personnelles et la déduplication — un appel direct au SDK contourne
   les trois.

2. **N'inventez pas de nom d'événement.** Les neuf événements du tunnel sont
   déclarés dans `lib/analytics/analytics_events.dart`. Un événement absent de
   ce fichier ne transmet aucun paramètre, et un test le rejette.

3. **`analytics_events.dart` a un jumeau** :
   `lilia-food-web/apps/web/lib/analytics/contract.ts`. Rien ne les
   compile ensemble. Toute modification de l'un doit être répercutée sur l'autre
   dans le même changement.

4. **Android et iOS partagent ce code.** Il n'y a pas d'instrumentation « iOS »
   à tenir en phase avec une instrumentation « Android » : ce sont deux
   compilations du même fichier.

5. **Jamais dans un `build()`.** Un `build` est rejoué à chaque changement
   d'état — clavier, thème, réponse réseau, notification. Un événement posé là
   part dix fois pour une consultation. Les vues s'émettent dans `initState` ou
   depuis l'observateur de navigation ; les faits métier, après la réponse du
   serveur.

## Fichiers

```
lib/analytics/
├── analytics_events.dart      Contrat : noms, liste blanche, garde-fous PII
├── analytics_sanitizer.dart   Application du contrat à une charge utile
├── analytics_dedupe.dart      Fenêtre courte + clés uniques persistantes
├── lilia_analytics.dart       Le cœur, sans dépendance à Firebase
├── analytics_sink.dart        Collecteurs : Firebase, debug, enregistreur
└── analytics_observer.dart    page_view + screen_view sur navigation

lib/services/analytics_service.dart   Façade typée — le point d'entrée des écrans
test/analytics/                       Miroir Dart des tests web
```

```bash
flutter test test/analytics/
```
