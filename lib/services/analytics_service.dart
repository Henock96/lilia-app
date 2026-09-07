import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lilia_app/analytics/analytics_dedupe.dart';
import 'package:lilia_app/analytics/analytics_events.dart';
import 'package:lilia_app/analytics/analytics_observer.dart';
import 'package:lilia_app/analytics/analytics_sink.dart';
import 'package:lilia_app/analytics/lilia_analytics.dart';

/// Façade typée de la mesure — **le seul point d'entrée du code métier**.
///
/// Les écrans appellent `AnalyticsService.trackRestaurantView(...)`, jamais
/// `FirebaseAnalytics.instance.logEvent(...)`. Cette indirection n'est pas une
/// politesse d'architecture : c'est elle qui garantit que le nom de l'événement
/// vient du contrat, que les paramètres passent par la liste blanche et le
/// désinfecteur, et que la déduplication s'applique. Un appel direct au SDK
/// contournerait les trois.
///
/// Android et iOS exécutent ce fichier à l'identique. La cohérence entre les
/// deux plateformes mobiles n'est donc pas une convention : c'est le même code.
///
/// ### Ce que cette façade n'expose délibérément pas
///
/// Les variantes de noms ont disparu avec la refonte :
/// `restaurant_viewed`, `add_to_cart_from_home`, `popular_dish_tap`,
/// `popular_restaurant_tap`, `recommendation_tap` ont été retirées. Les trois
/// dernières mesuraient un geste qui **ouvre un écran** déjà mesuré par
/// `product_view` ou `restaurant_view` : elles comptaient donc deux fois la
/// même consultation, sous deux noms différents et sans équivalent web.
abstract final class AnalyticsService {
  static LiliaAnalytics? _analytics;

  /// Instance active. Avant `init()`, elle n'envoie rien mais reste appelable :
  /// aucun écran n'a de condition à écrire.
  static LiliaAnalytics get instance =>
      _analytics ??= LiliaAnalytics(sinks: const []);

  /// Observateur de navigation — à brancher sur le `GoRouter`.
  static LiliaAnalyticsObserver get observer =>
      _observer ??= LiliaAnalyticsObserver(
        analytics: instance,
        firebase: FirebaseAnalytics.instance,
      );
  static LiliaAnalyticsObserver? _observer;

  /// Branche les collecteurs réels.
  ///
  /// Appelé depuis `main()` après `Firebase.initializeApp()`. Le stockage
  /// persistant sert la déduplication des événements uniques (`order_created`,
  /// `payment_success`) : sans lui, un redémarrage de l'application les ferait
  /// repartir. Son chargement peut échouer sans conséquence — on retombe alors
  /// sur une déduplication valable pour la session en cours.
  static Future<void> init() async {
    AnalyticsKeyStore store = InMemoryKeyStore();
    try {
      store = SharedPrefsKeyStore(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('📊 [analytics] stockage indisponible : $e');
    }

    _analytics = LiliaAnalytics(
      sinks: [
        FirebaseAnalyticsSink(FirebaseAnalytics.instance),
        if (kDebugMode) const DebugAnalyticsSink(),
      ],
      store: store,
    );
    _observer = null; // réattaché à la prochaine lecture, sur la bonne instance
  }

  /// Remplace l'instance — réservé aux tests.
  @visibleForTesting
  static void setInstanceForTest(LiliaAnalytics analytics) {
    _analytics = analytics;
    _observer = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Tunnel officiel — les neuf événements communs aux trois plateformes
  // ══════════════════════════════════════════════════════════════════════════

  /// Le client a ouvert la **fiche** d'un vendeur.
  ///
  /// ⚠️ Jamais depuis une carte de liste : `restaurant_view` signifie « la fiche
  /// a été ouverte », pas « la fiche est apparue ». Une liste de vingt vendeurs
  /// en émettrait vingt, et le deuxième étage du tunnel dépasserait le premier.
  static void trackRestaurantView({
    required String restaurantId,
    required String restaurantName,
  }) {
    instance.track(AnalyticsEvents.restaurantView, {
      AnalyticsParams.restaurantId: restaurantId,
      AnalyticsParams.restaurantName: restaurantName,
    });
  }

  /// Le client a ouvert la fiche d'un produit.
  static void trackProductView({
    required String productId,
    required String productName,
    required String restaurantId,
    required num price,
  }) {
    instance.track(AnalyticsEvents.productView, {
      AnalyticsParams.productId: productId,
      AnalyticsParams.productName: productName,
      AnalyticsParams.restaurantId: restaurantId,
      AnalyticsParams.price: price,
    });
  }

  /// Un article a été ajouté au panier — **après** acceptation par le serveur.
  ///
  /// Le backend refuse un produit épuisé, un vendeur fermé ou un mélange de
  /// modes dans un même panier. Compter le geste plutôt que son résultat ferait
  /// apparaître des ajouts qui n'ont jamais eu lieu, et le tunnel décrocherait
  /// sans raison visible entre `add_to_cart` et `view_cart`.
  static void trackAddToCart({
    required String productId,
    required String productName,
    required String restaurantId,
    required num price,
    required int quantity,
  }) {
    instance.track(AnalyticsEvents.addToCart, {
      AnalyticsParams.productId: productId,
      AnalyticsParams.productName: productName,
      AnalyticsParams.restaurantId: restaurantId,
      AnalyticsParams.price: price,
      AnalyticsParams.quantity: quantity,
    });
  }

  /// Le panier a été affiché avec au moins un article.
  ///
  /// Un panier vide n'est pas une étape du tunnel : le compter ferait
  /// apparaître des consultations de panier sans aucun `add_to_cart` avant elles.
  static void trackViewCart({required int itemCount, required num cartTotal}) {
    if (itemCount <= 0) return;
    instance.track(AnalyticsEvents.viewCart, {
      AnalyticsParams.itemCount: itemCount,
      AnalyticsParams.cartTotal: cartTotal,
    });
  }

  /// Le client a engagé sa commande depuis le panier.
  ///
  /// Émis sur l'action délibérée — le bouton « Passer la commande » —, et non à
  /// l'affichage d'un écran. C'est la définition qui rend l'étape comparable au
  /// web, où le panier et la saisie de commande vivent sur la même page : la
  /// déclencher à l'affichage la rendrait égale à `view_cart` d'un côté et pas
  /// de l'autre.
  static void trackBeginCheckout({
    required int itemCount,
    required num cartTotal,
  }) {
    instance.track(AnalyticsEvents.beginCheckout, {
      AnalyticsParams.itemCount: itemCount,
      AnalyticsParams.cartTotal: cartTotal,
    });
  }

  /// La commande **existe** côté serveur.
  ///
  /// Émis après la réponse de `POST /orders/checkout`, jamais au clic. Unique
  /// par `orderId` : la clé d'idempotence fait qu'un rejeu rend la **même**
  /// commande, et une commande n'est créée qu'une fois.
  static void trackOrderCreated({
    required String orderId,
    required num amount,
    required int itemCount,
  }) {
    instance.trackOnce(
      AnalyticsOnceKey.orderCreated(orderId),
      AnalyticsEvents.orderCreated,
      {
        AnalyticsParams.orderId: orderId,
        AnalyticsParams.amount: amount,
        AnalyticsParams.currency: analyticsCurrency,
        AnalyticsParams.itemCount: itemCount,
      },
    );
  }

  /// Une tentative d'encaissement a été ouverte côté serveur.
  ///
  /// Unique par `paymentId`, jamais par commande : l'appel `POST /payments` est
  /// sûr à rejouer et le serveur réutilise alors la tentative `PENDING`
  /// existante, avec le même identifiant. Deux tentatives distinctes sur une
  /// même commande sont en revanche deux paiements lancés — c'est exactement
  /// l'écart entre `payment_started` et `payment_success` qu'on cherche à voir.
  static void trackPaymentStarted({
    required String paymentId,
    required String orderId,
    required String paymentMethod,
    required num amount,
  }) {
    instance.trackOnce(
      AnalyticsOnceKey.paymentStarted(paymentId),
      AnalyticsEvents.paymentStarted,
      {
        AnalyticsParams.orderId: orderId,
        AnalyticsParams.paymentMethod: paymentMethod,
        AnalyticsParams.amount: amount,
        AnalyticsParams.currency: analyticsCurrency,
      },
    );
  }

  /// Le paiement est **confirmé par la source de vérité**.
  ///
  /// ⚠️ À n'appeler que sur un statut `SUCCESS` rendu par le serveur — celui
  /// que `PaymentStatusController` obtient de `GET /payments/:id/status`, et
  /// qui provient du webhook du prestataire, de l'interrogation ou du cron de
  /// réconciliation. **Jamais** parce qu'un écran de confirmation s'affiche :
  /// c'est la même autorité qui fait passer la commande en `PAYER`, aucune
  /// autre n'a le droit de compter un paiement réussi.
  ///
  /// Unique par `paymentId` : l'écran d'attente, le détail de la commande et
  /// une notification peuvent observer le même paiement.
  static void trackPaymentSuccess({
    required String paymentId,
    required String orderId,
    required String paymentMethod,
    required num amount,
  }) {
    instance.trackOnce(
      AnalyticsOnceKey.paymentSuccess(paymentId),
      AnalyticsEvents.paymentSuccess,
      {
        AnalyticsParams.orderId: orderId,
        AnalyticsParams.paymentMethod: paymentMethod,
        AnalyticsParams.amount: amount,
        AnalyticsParams.currency: analyticsCurrency,
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Secondaires — propres à l'application, hors tunnel
  // ══════════════════════════════════════════════════════════════════════════

  static void trackLogin({required String method}) {
    instance.track(AnalyticsEvents.login, {AnalyticsParams.method: method});
  }

  static void trackSignUp({required String method}) {
    instance.track(AnalyticsEvents.signUp, {AnalyticsParams.method: method});
  }

  static void trackFavoriteToggle({
    required String restaurantId,
    required String restaurantName,
    required bool isFavorite,
  }) {
    instance.track(
      isFavorite ? AnalyticsEvents.addFavorite : AnalyticsEvents.removeFavorite,
      {
        AnalyticsParams.restaurantId: restaurantId,
        AnalyticsParams.restaurantName: restaurantName,
      },
    );
  }

  static void trackOrderCancelled({required String orderId}) {
    instance.track(AnalyticsEvents.orderCancelled, {
      AnalyticsParams.orderId: orderId,
    });
  }

  /// Échec de création de commande.
  ///
  /// ⚠️ [failureKind] est une **catégorie**, jamais un message. L'ancienne
  /// version envoyait le texte du serveur, c'est-à-dire du contenu libre
  /// pouvant contenir un numéro ou une référence de transaction.
  static void trackOrderFailed({
    required String paymentMethod,
    required String failureKind,
  }) {
    instance.track(AnalyticsEvents.orderFailed, {
      AnalyticsParams.paymentMethod: paymentMethod,
      AnalyticsParams.failureKind: failureKind,
    });
  }

  /// Échec d'encaissement confirmé par le serveur.
  static void trackPaymentFailed({
    required String orderId,
    required String paymentMethod,
    required String failureKind,
  }) {
    instance.track(AnalyticsEvents.paymentFailed, {
      AnalyticsParams.orderId: orderId,
      AnalyticsParams.paymentMethod: paymentMethod,
      AnalyticsParams.failureKind: failureKind,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Identification
  // ══════════════════════════════════════════════════════════════════════════

  /// Attache l'identifiant applicatif du client aux envois suivants.
  ///
  /// ⚠️ **`userId` est le CUID de la base (`AppUser.id`)**, jamais le numéro de
  /// téléphone, l'e-mail ou l'UID Firebase. Il est stable, il recolle les
  /// parcours web et mobile d'un même client, et il ne désigne personne pour
  /// qui n'a pas déjà accès à la base.
  ///
  /// `null` **délie** le compte : appelé à la déconnexion, sinon la session du
  /// visiteur suivant sur le même téléphone resterait attribuée au précédent.
  /// Un client non connecté reste suivi — Firebase lui attribue un identifiant
  /// d'installation anonyme.
  static void identify(String? userId) => instance.identify(userId);

  /// Propriétés d'audience — pays et devise, aucune donnée personnelle.
  static Future<void> setUserProperties({String? city}) async {
    final analytics = FirebaseAnalytics.instance;
    try {
      await analytics.setUserProperty(name: 'country', value: 'CG');
      await analytics.setUserProperty(name: 'currency', value: analyticsCurrency);
      if (city != null) {
        await analytics.setUserProperty(name: 'city', value: city);
      }
    } catch (e) {
      debugPrint('📊 [analytics] propriétés non posées : $e');
    }
  }
}
