/// Contrat Analytics Lilia Food — source unique des noms d'événements.
///
/// Ce fichier est le **jumeau Dart** de `lilia-food-web/apps/web/lib/analytics/
/// contract.ts`. Les deux déclarent exactement les mêmes noms d'événements et
/// les mêmes clés de paramètres. Toute modification ici doit être répercutée
/// là-bas dans le même changement — sans quoi les chiffres d'Android, d'iOS et
/// du web cessent d'être comparables, ce qui est le seul problème que ce
/// contrat existe pour empêcher.
///
/// Android et iOS partagent ce fichier : ce sont deux compilations du même
/// code. L'égalité des noms entre les deux plateformes mobiles n'est donc pas
/// une convention qu'on respecte, c'est une propriété de la structure.
///
/// La documentation de référence — signification et règle de déclenchement de
/// chaque événement — vit dans `docs/analytics.md` du dépôt web.
library;

/// Les neuf événements du tunnel officiel, dans l'ordre.
///
/// On n'ajoute pas de variante : ni `restaurant_opened`, ni `view_restaurant`,
/// ni `restaurant_viewed`. Une seule graphie par événement métier.
abstract final class AnalyticsEvents {
  static const pageView = 'page_view';
  static const restaurantView = 'restaurant_view';
  static const productView = 'product_view';
  static const addToCart = 'add_to_cart';
  static const viewCart = 'view_cart';
  static const beginCheckout = 'begin_checkout';
  static const paymentStarted = 'payment_started';
  static const paymentSuccess = 'payment_success';
  static const orderCreated = 'order_created';

  /// Événements secondaires, propres à l'application.
  ///
  /// Ils ne font pas partie du tunnel et ne sont **pas** comparés au web.
  /// `login` et `sign_up` sont les noms standards de GA4 ; les autres décrivent
  /// des gestes qui n'existent que dans l'application.
  static const login = 'login';
  static const signUp = 'sign_up';
  static const addFavorite = 'add_favorite';
  static const removeFavorite = 'remove_favorite';
  static const orderCancelled = 'order_cancelled';
  static const orderFailed = 'order_failed';
  static const paymentFailed = 'payment_failed';

  /// Le tunnel dans l'ordre — sert aux tests et à la documentation.
  static const funnel = <String>[
    pageView,
    restaurantView,
    productView,
    addToCart,
    viewCart,
    beginCheckout,
    paymentStarted,
    paymentSuccess,
    orderCreated,
  ];
}

/// Clés de paramètres. Écrites une fois, jamais en littéral dans les écrans.
abstract final class AnalyticsParams {
  static const restaurantId = 'restaurant_id';
  static const restaurantName = 'restaurant_name';
  static const productId = 'product_id';
  static const productName = 'product_name';
  static const price = 'price';
  static const quantity = 'quantity';
  static const itemCount = 'item_count';
  static const cartTotal = 'cart_total';
  static const orderId = 'order_id';
  static const paymentMethod = 'payment_method';
  static const amount = 'amount';
  static const currency = 'currency';
  static const screenName = 'screen_name';
  static const method = 'method';
  static const failureKind = 'failure_kind';
  static const pagePath = 'page_path';
  static const pageTitle = 'page_title';
}

/// Liste blanche des paramètres, par événement.
///
/// C'est une **liste blanche**, pas une liste noire : tout paramètre non
/// déclaré ici est retiré avant l'envoi. C'est la garantie principale d'absence
/// de données personnelles — elle tient même si quelqu'un passe par mégarde un
/// modèle `Product` ou `Order` entier.
///
/// `page_view` fait exception au caractère commun des paramètres : le web
/// décrit une URL, le mobile décrit un écran. Le **nom** de l'événement reste
/// commun, ce qui est ce que le tunnel exige.
const analyticsEventParams = <String, List<String>>{
  AnalyticsEvents.pageView: [
    AnalyticsParams.screenName,
    AnalyticsParams.pagePath,
    AnalyticsParams.pageTitle,
  ],
  AnalyticsEvents.restaurantView: [
    AnalyticsParams.restaurantId,
    AnalyticsParams.restaurantName,
  ],
  AnalyticsEvents.productView: [
    AnalyticsParams.productId,
    AnalyticsParams.productName,
    AnalyticsParams.restaurantId,
    AnalyticsParams.price,
  ],
  AnalyticsEvents.addToCart: [
    AnalyticsParams.productId,
    AnalyticsParams.productName,
    AnalyticsParams.restaurantId,
    AnalyticsParams.price,
    AnalyticsParams.quantity,
  ],
  AnalyticsEvents.viewCart: [
    AnalyticsParams.itemCount,
    AnalyticsParams.cartTotal,
  ],
  AnalyticsEvents.beginCheckout: [
    AnalyticsParams.itemCount,
    AnalyticsParams.cartTotal,
  ],
  AnalyticsEvents.paymentStarted: [
    AnalyticsParams.orderId,
    AnalyticsParams.paymentMethod,
    AnalyticsParams.amount,
    AnalyticsParams.currency,
  ],
  AnalyticsEvents.paymentSuccess: [
    AnalyticsParams.orderId,
    AnalyticsParams.paymentMethod,
    AnalyticsParams.amount,
    AnalyticsParams.currency,
  ],
  AnalyticsEvents.orderCreated: [
    AnalyticsParams.orderId,
    AnalyticsParams.amount,
    AnalyticsParams.currency,
    AnalyticsParams.itemCount,
  ],

  // ── Secondaires (application seulement) ─────────────────────────────────────
  AnalyticsEvents.login: [AnalyticsParams.method],
  AnalyticsEvents.signUp: [AnalyticsParams.method],
  AnalyticsEvents.addFavorite: [
    AnalyticsParams.restaurantId,
    AnalyticsParams.restaurantName,
  ],
  AnalyticsEvents.removeFavorite: [
    AnalyticsParams.restaurantId,
    AnalyticsParams.restaurantName,
  ],
  AnalyticsEvents.orderCancelled: [AnalyticsParams.orderId],

  // ⚠️ Ni l'un ni l'autre ne transporte de message d'erreur.
  //
  // L'ancien `order_failed` envoyait `error_message`, c'est-à-dire le texte
  // rendu par le serveur ou par l'opérateur — donc du texte libre, susceptible
  // de contenir un numéro de téléphone ou un identifiant de transaction. Seule
  // une **catégorie** d'échec voyage : elle suffit à savoir où le parcours
  // casse, et elle ne peut pas contenir de donnée personnelle.
  AnalyticsEvents.orderFailed: [
    AnalyticsParams.paymentMethod,
    AnalyticsParams.failureKind,
  ],
  AnalyticsEvents.paymentFailed: [
    AnalyticsParams.orderId,
    AnalyticsParams.paymentMethod,
    AnalyticsParams.failureKind,
  ],
};

/// Devise unique de la plateforme. Aucun montant ne voyage sans elle.
const analyticsCurrency = 'XAF';

/// Fragments de noms de clés interdits, quelle que soit leur valeur.
///
/// Second filet derrière la liste blanche : si quelqu'un ajoute demain
/// `customer_phone` à `analyticsEventParams`, la revue de code peut le laisser
/// passer — pas cette liste. Elle est délibérément redondante.
const forbiddenParamFragments = <String>[
  'phone',
  'telephone',
  'tel',
  'msisdn',
  'email',
  'mail',
  'password',
  'motdepasse',
  'token',
  'jwt',
  'secret',
  'credential',
  'lat',
  'latitude',
  'lng',
  'lon',
  'longitude',
  'gps',
  'coord',
  'address',
  'adresse',
  'rue',
  'street',
  'landmark',
  'repere',
  'card',
  'carte',
  'iban',
  'pan',
  'cvv',
  'momo',
  'note',
  'comment',
  'message',
  'query',
  'search',
];

/// Valeurs qui ressemblent à une donnée personnelle, quel que soit le nom de la
/// clé. Le nom peut être innocent (`reference`, `label`), la valeur non.
final analyticsPiiPatterns = <RegExp>[
  /// Numéro congolais — `06 XXX XX XX`, neuf chiffres, séparateurs libres, avec
  /// ou sans indicatif `+242`. Le zéro (ou l'indicatif) est obligatoire : sans
  /// lui, huit chiffres consécutifs feraient rejeter un libellé légitime.
  RegExp(r'(?:\+?242[\s.\-]*0?|0)[456](?:[\s.\-]*\d){7}'),

  /// Jeton JWT — identifiant Firebase, jeton de session.
  RegExp(r'\beyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.'),

  /// Adresse e-mail.
  RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]{2,}'),
];

/// Longueur maximale d'une valeur texte transmise. Au-delà, on tronque.
const analyticsMaxStringLength = 100;
