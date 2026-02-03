enum AppRoutes {
  onboarding,
  home,
  signIn,
  signUp,
  commandes,
  favoris,
  favoriteDetail,
  profile,
  address,
  changePassword,
  restaurantDetail,
  productDetail,
  menuDetail,
  orderDetail,
  cart,
  deliveryOptions,
  checkout,
  orderSuccess,
  reviews,
  writeReview
}

extension AppRoutesExtension on AppRoutes {
  String get path {
    switch (this) {
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
        return '/favoris';
      case AppRoutes.favoriteDetail:
        return 'details';
      case AppRoutes.profile:
        return '/profile';
      case AppRoutes.address:
        return 'address';
      case AppRoutes.changePassword:
        return 'change-password';
      case AppRoutes.restaurantDetail:
        return 'restaurant/:id';
      case AppRoutes.productDetail:
        return 'product-detail';
      case AppRoutes.menuDetail:
        return 'menu-detail';
      case AppRoutes.orderDetail:
        return '/:orderId';
      case AppRoutes.cart:
        return '/cart';
      case AppRoutes.deliveryOptions:
        return 'delivery-options';
      case AppRoutes.checkout:
        return 'checkout';
      case AppRoutes.orderSuccess:
        return '/order-success';
      case AppRoutes.reviews:
        return '/reviews';
      case AppRoutes.writeReview:
        return 'write';
    }
  }

  String get routeName {
    switch (this) {
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
      case AppRoutes.cart:
        return 'Cart';
      case AppRoutes.deliveryOptions:
        return 'DeliveryOptions';
      case AppRoutes.checkout:
        return 'Checkout';
      case AppRoutes.orderSuccess:
        return 'OrderSuccess';
      case AppRoutes.reviews:
        return 'Reviews';
      case AppRoutes.writeReview:
        return 'WriteReview';
    }
  }
}
