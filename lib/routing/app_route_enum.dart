/// La table des routes de l'application.
///
/// ⚠️ **Source unique des chemins.** `app_router.dart` déclarait cinq chemins
/// en dur (`restaurant/:id`, `product-detail`, `search`, `menu-detail`,
/// `:orderId`) pendant que cet enum en portait sa propre version. L'une d'elles
/// avait déjà divergé — `orderDetail` valait `'/:orderId'`, un chemin qui
/// n'existe nulle part. Un enum qui prétend faire autorité et ne la fait pas
/// est pire qu'une constante en dur : on lui fait confiance.
///
/// Convention : un chemin de route **racine** commence par `/`, un chemin de
/// **sous-route** ne commence jamais par `/` (il est concaténé à son parent).
enum AppRoutes {
  splash,
  onboarding,
  home,
  signIn,
  signUp,
  commandes,
  favoris,
  favoriteDetail,
  profile,
  editProfile,
  about,
  address,
  changePassword,
  restaurantDetail,
  productDetail,
  menuDetail,
  orderDetail,
  orderTracking,
  notifications,
  cart,
  deliveryOptions,
  checkout,
  paymentPending,
  orderSuccess,
  reviews,
  writeReview,
  search,
  draftOrders,
}

extension AppRoutesExtension on AppRoutes {
  /// Chemin déclaré dans `GoRoute.path`.
  String get path {
    switch (this) {
      case AppRoutes.splash:
        return '/splash';
      case AppRoutes.onboarding:
        return '/onboarding';
      case AppRoutes.home:
        return '/';
      case AppRoutes.signIn:
        return '/signin';
      case AppRoutes.signUp:
        return '/signup';
      case AppRoutes.commandes:
        return '/commandes';
      case AppRoutes.favoris:
        // Sous-route de `/profile` : pas de `/` initial.
        return 'favoris';
      case AppRoutes.favoriteDetail:
        // Adressable, comme `productDetail` : la fiche ne dépend plus d'un
        // objet passé en `extra`, qui ne survit pas à une mort de processus.
        return 'details/:productId';
      case AppRoutes.profile:
        return '/profile';
      case AppRoutes.editProfile:
        return 'edit';
      case AppRoutes.about:
        return 'about';
      case AppRoutes.address:
        return 'address';
      case AppRoutes.changePassword:
        return 'change-password';
      case AppRoutes.restaurantDetail:
        return 'restaurant/:id';
      case AppRoutes.productDetail:
        // Adressable : la fiche ne dépend plus d'un objet passé en `extra`,
        // qui ne survit pas à une mort de processus.
        return 'product/:productId';
      case AppRoutes.menuDetail:
        return 'menu/:menuId';
      case AppRoutes.orderDetail:
        // Sous-route de `/commandes`. Valait `'/:orderId'` : faux, et mort
        // puisque le routeur déclarait le chemin en dur à côté (R-02).
        return ':orderId';
      case AppRoutes.orderTracking:
        return 'tracking';
      case AppRoutes.notifications:
        return 'notifications';
      case AppRoutes.cart:
        return '/cart';
      case AppRoutes.deliveryOptions:
        return 'delivery-options';
      case AppRoutes.checkout:
        return 'checkout';
      case AppRoutes.paymentPending:
        // Sous `/commandes` : le retour arrière tombe alors sur la liste des
        // commandes, et non sur un panier qui vient d'être vidé.
        return 'paiement/:paymentId';
      case AppRoutes.orderSuccess:
        return '/order-success';
      case AppRoutes.reviews:
        // Le nom du vendeur était transporté en `extra` à côté de son
        // identifiant : purement cosmétique, et suffisant pour faire échouer
        // la route. Il est désormais lu depuis la fiche vendeur.
        return '/reviews/:restaurantId';
      case AppRoutes.writeReview:
        return 'write';
      case AppRoutes.search:
        return 'search';
      case AppRoutes.draftOrders:
        return 'draft-orders';
    }
  }

  String get routeName {
    switch (this) {
      case AppRoutes.splash:
        return 'Splash';
      case AppRoutes.onboarding:
        return 'Onboarding';
      case AppRoutes.home:
        return 'Home';
      case AppRoutes.signIn:
        return 'SignIn';
      case AppRoutes.signUp:
        return 'SignUp';
      case AppRoutes.commandes:
        return 'Commandes';
      case AppRoutes.favoris:
        return 'Favoris';
      case AppRoutes.favoriteDetail:
        return 'FavoriteDetail';
      case AppRoutes.profile:
        return 'Profile';
      case AppRoutes.editProfile:
        return 'EditProfile';
      case AppRoutes.about:
        return 'About';
      case AppRoutes.address:
        return 'Address';
      case AppRoutes.changePassword:
        return 'ChangePassword';
      case AppRoutes.restaurantDetail:
        return 'RestaurantDetail';
      case AppRoutes.productDetail:
        return 'Product-Details';
      case AppRoutes.menuDetail:
        return 'Menu-Details';
      case AppRoutes.orderDetail:
        return 'OrderId';
      case AppRoutes.orderTracking:
        return 'OrderTracking';
      case AppRoutes.notifications:
        return 'Notifications';
      case AppRoutes.cart:
        return 'Cart';
      case AppRoutes.deliveryOptions:
        return 'DeliveryOptions';
      case AppRoutes.checkout:
        return 'Checkout';
      case AppRoutes.paymentPending:
        return 'PaymentPending';
      case AppRoutes.orderSuccess:
        return 'OrderSuccess';
      case AppRoutes.reviews:
        return 'Reviews';
      case AppRoutes.writeReview:
        return 'WriteReview';
      case AppRoutes.search:
        return 'Search';
      case AppRoutes.draftOrders:
        return 'DraftOrders';
    }
  }
}
