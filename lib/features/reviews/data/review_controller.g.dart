// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider pour récupérer les avis d'un restaurant

@ProviderFor(restaurantReviews)
final restaurantReviewsProvider = RestaurantReviewsFamily._();

/// Provider pour récupérer les avis d'un restaurant

final class RestaurantReviewsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Review>>,
          List<Review>,
          FutureOr<List<Review>>
        >
    with $FutureModifier<List<Review>>, $FutureProvider<List<Review>> {
  /// Provider pour récupérer les avis d'un restaurant
  RestaurantReviewsProvider._({
    required RestaurantReviewsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'restaurantReviewsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$restaurantReviewsHash();

  @override
  String toString() {
    return r'restaurantReviewsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Review>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Review>> create(Ref ref) {
    final argument = this.argument as String;
    return restaurantReviews(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantReviewsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$restaurantReviewsHash() => r'e3b00e4fa4c02aeb3e4195caac35422ea7dc4f63';

/// Provider pour récupérer les avis d'un restaurant

final class RestaurantReviewsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Review>>, String> {
  RestaurantReviewsFamily._()
    : super(
        retry: null,
        name: r'restaurantReviewsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider pour récupérer les avis d'un restaurant

  RestaurantReviewsProvider call(String restaurantId) =>
      RestaurantReviewsProvider._(argument: restaurantId, from: this);

  @override
  String toString() => r'restaurantReviewsProvider';
}

/// Provider pour récupérer les statistiques d'un restaurant

@ProviderFor(restaurantStats)
final restaurantStatsProvider = RestaurantStatsFamily._();

/// Provider pour récupérer les statistiques d'un restaurant

final class RestaurantStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReviewStats>,
          ReviewStats,
          FutureOr<ReviewStats>
        >
    with $FutureModifier<ReviewStats>, $FutureProvider<ReviewStats> {
  /// Provider pour récupérer les statistiques d'un restaurant
  RestaurantStatsProvider._({
    required RestaurantStatsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'restaurantStatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$restaurantStatsHash();

  @override
  String toString() {
    return r'restaurantStatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ReviewStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReviewStats> create(Ref ref) {
    final argument = this.argument as String;
    return restaurantStats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantStatsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$restaurantStatsHash() => r'd9685aa3edc133fd9b51ea644625362db54ad929';

/// Provider pour récupérer les statistiques d'un restaurant

final class RestaurantStatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ReviewStats>, String> {
  RestaurantStatsFamily._()
    : super(
        retry: null,
        name: r'restaurantStatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider pour récupérer les statistiques d'un restaurant

  RestaurantStatsProvider call(String restaurantId) =>
      RestaurantStatsProvider._(argument: restaurantId, from: this);

  @override
  String toString() => r'restaurantStatsProvider';
}

/// Provider pour vérifier si l'utilisateur peut laisser un avis

@ProviderFor(canReview)
final canReviewProvider = CanReviewFamily._();

/// Provider pour vérifier si l'utilisateur peut laisser un avis

final class CanReviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<CanReviewResponse>,
          CanReviewResponse,
          FutureOr<CanReviewResponse>
        >
    with
        $FutureModifier<CanReviewResponse>,
        $FutureProvider<CanReviewResponse> {
  /// Provider pour vérifier si l'utilisateur peut laisser un avis
  CanReviewProvider._({
    required CanReviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'canReviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$canReviewHash();

  @override
  String toString() {
    return r'canReviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CanReviewResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CanReviewResponse> create(Ref ref) {
    final argument = this.argument as String;
    return canReview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CanReviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$canReviewHash() => r'ab2a32630fde29e7bd6151e72f6f2a56dee5886a';

/// Provider pour vérifier si l'utilisateur peut laisser un avis

final class CanReviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CanReviewResponse>, String> {
  CanReviewFamily._()
    : super(
        retry: null,
        name: r'canReviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider pour vérifier si l'utilisateur peut laisser un avis

  CanReviewProvider call(String restaurantId) =>
      CanReviewProvider._(argument: restaurantId, from: this);

  @override
  String toString() => r'canReviewProvider';
}

/// Provider pour récupérer mon avis

@ProviderFor(myReview)
final myReviewProvider = MyReviewFamily._();

/// Provider pour récupérer mon avis

final class MyReviewProvider
    extends $FunctionalProvider<AsyncValue<Review?>, Review?, FutureOr<Review?>>
    with $FutureModifier<Review?>, $FutureProvider<Review?> {
  /// Provider pour récupérer mon avis
  MyReviewProvider._({
    required MyReviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'myReviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$myReviewHash();

  @override
  String toString() {
    return r'myReviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Review?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Review?> create(Ref ref) {
    final argument = this.argument as String;
    return myReview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MyReviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$myReviewHash() => r'200ace517e68d88d9aad8d9698a6e7de02a87a30';

/// Provider pour récupérer mon avis

final class MyReviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Review?>, String> {
  MyReviewFamily._()
    : super(
        retry: null,
        name: r'myReviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider pour récupérer mon avis

  MyReviewProvider call(String restaurantId) =>
      MyReviewProvider._(argument: restaurantId, from: this);

  @override
  String toString() => r'myReviewProvider';
}
