enum AppRoutes {
  home,
  signIn,
  signUp,
  commandes,
  favoris,
  profile,
  productDetail,
  orderDetail,
  cart,
  checkout,
  orderSuccess
}

extension AppRoutesExtension on AppRoutes {
  String get path {
    switch (this) {
      case AppRoutes.home:
        return '/';
      case AppRoutes.signIn:
        return '/signin';
      case AppRoutes.signUp:
        return '/signup';
      case AppRoutes.commandes:
        return '/commandes';
      case AppRoutes.favoris:
        return '/favoris';
      case AppRoutes.profile:
        return '/profile';
      case AppRoutes.productDetail:
        return '/product-details';
      case AppRoutes.orderDetail:
        return '/order-Id';
      case AppRoutes.cart:
        return '/cart';
      case AppRoutes.checkout:
        return '/checkout';
      case AppRoutes.orderSuccess:
        return '/order-success';
    }
  }

  String get routeName {
    switch (this) {
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
      case AppRoutes.profile:
        return 'Profile';
      case AppRoutes.productDetail:
        return 'Product-Details';
      case AppRoutes.orderDetail:
        return 'Order-Id';
      case AppRoutes.cart:
        return 'Cart';
      case AppRoutes.checkout:
        return 'Checkout';
      case AppRoutes.orderSuccess:
        return 'OrderSuccess';
    }
  }
}
