import 'package:lilia_app/models/gallery_image.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';
import 'package:lilia_app/utils/availability_window.dart';
import 'package:lilia_app/utils/currency.dart';

/// Libellé de la section fourre-tout d'une carte.
///
/// Le site disait « Autres plats » et l'application « Autres ». Sur une
/// boulangerie ou une boutique de boissons, « plats » est simplement faux : un
/// croissant n'est pas un plat. Un seul mot, juste partout — miroir de
/// `UNCATEGORIZED_LABEL` côté web.
const String kUncategorizedLabel = 'Autres';

/// Cause d'indisponibilité d'un produit, telle que l'interface doit la dire.
///
/// Trois valeurs, parce que ce sont les trois seules qui appellent une conduite
/// différente du client : attendre demain, chercher ailleurs, revenir à l'heure.
enum ProductUnavailability {
  /// Épuisé pour aujourd'hui (`stockRestant == 0`).
  epuise,

  /// Retiré de la vente par le vendeur (`isAvailable == false`).
  retire,

  /// Hors de sa fenêtre horaire (`availableNow == false`).
  horsCreneau;

  /// Libellé court, pour un badge sur une carte produit.
  String get badge => switch (this) {
    ProductUnavailability.epuise => 'Épuisé',
    ProductUnavailability.retire => 'Indisponible',
    ProductUnavailability.horsCreneau => 'Hors créneau',
  };
}

class Product {
  final String id;
  final String name;
  final String description;
  final double prixOriginal;
  final String? imageUrl;
  // Galerie multi-images (ProductImage côté backend). Vide si l'API ne la
  // renvoie pas encore ou si le produit n'a que l'imageUrl legacy.
  final List<GalleryImage> images;
  final String restaurantId;
  // categoryId est nullable côté Prisma (String?) — vrai pour les nouveaux
  // produits HOME_COOK/BAKERY créés sans catégorie via admin web (LIL-117).
  final String? categoryId;
  final Category? category;
  final List<ProductVariant> variants;
  final int? stockRestant;
  /// Décision du vendeur : « ce produit est-il proposé à la vente ? »
  ///
  /// ⚠️ À ne pas confondre avec le stock. « Retiré de la vente » et « épuisé »
  /// sont deux notions distinctes que le backend a séparées en août 2026
  /// (fix M2) — la première est un choix, la seconde une conséquence. Ce champ
  /// était **ignoré** par cette classe, recouvert par un getter `isAvailable`
  /// dérivé du seul stock (fix S-3).
  ///
  /// `true` par défaut : les réponses antérieures au champ ne le portent pas,
  /// et un produit servi sans lui est en vente — sinon il n'aurait pas été
  /// servi.
  final bool isAvailable;
  final int? orderCount;
  final String? restaurantName;
  final String? restaurantImageUrl;
  final bool? restaurantIsOpen;
  final VendorType? restaurantVendorType;

  // Multi-vendeurs (LIL-117)
  final ProductType productType;
  final StockMode stockMode;
  final String? ingredients;
  final int? shelfLifeDays;
  final bool madeToOrder;
  final String? availableFrom; // HH:mm
  final String? availableUntil; // HH:mm

  /// **Verdict horaire du serveur** — « ce produit est-il vendable à cette
  /// heure ? », calculé par `isWithinAvailabilityWindow` côté backend, celle-là
  /// même qu'applique le checkout pour accepter ou refuser.
  ///
  /// `null` quand la réponse est antérieure au champ : on retombe alors sur le
  /// calcul local, qui applique **la même règle** (voir
  /// [AvailabilityWindow.contains]).
  ///
  /// ⚠️ Périssable : une réponse en cache plus de quelques minutes annoncera
  /// « disponible » après la fermeture de la fenêtre. C'est la raison du TTL
  /// posé sur le cache de la carte.
  final bool? availableNow;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.prixOriginal,
    this.imageUrl,
    this.images = const [],
    required this.restaurantId,
    this.categoryId,
    this.category,
    required this.variants,
    this.stockRestant,
    this.isAvailable = true,
    this.orderCount,
    this.restaurantName,
    this.restaurantImageUrl,
    this.restaurantIsOpen,
    this.restaurantVendorType,
    this.productType = ProductType.FOOD,
    this.stockMode = StockMode.DAILY,
    this.ingredients,
    this.shelfLifeDays,
    this.madeToOrder = false,
    this.availableFrom,
    this.availableUntil,
    this.availableNow,
  });

  /// Reste-t-il des unités ? `null` = illimité, `0` = épuisé.
  ///
  /// Ce getter s'appelait `isAvailable` et **masquait le champ du serveur** du
  /// même nom : la disponibilité déclarée par le vendeur n'était jamais lue.
  /// Sans conséquence visible sur cette app — `GET /products` filtre déjà
  /// `isAvailable: true`, donc le client ne voit jamais un produit retiré —
  /// mais c'était un piège : le jour où une route servirait le contraire,
  /// l'écran aurait affiché « disponible » sur un produit retiré de la vente.
  bool get isInStock => stockRestant == null || stockRestant! > 0;

  /// Commandable **maintenant** : en vente, en stock, **et dans son créneau**.
  ///
  /// C'est la question que posent les écrans. La poser en un seul endroit évite
  /// que chacun en recompose sa propre version — et en oublie la moitié : la
  /// fenêtre horaire manquait ici, si bien qu'une viennoiserie « 06:00 → 11:00 »
  /// restait proposée à 15 h, jusqu'au refus du serveur au checkout.
  bool get isOrderable =>
      isAvailable && isInStock && isWithinAvailabilityWindow;

  /// Pourquoi ce produit n'est-il pas commandable ? `null` s'il l'est.
  ///
  /// Miroir de `unavailabilityReason` côté serveur, réduit à ce que l'interface
  /// a besoin de distinguer. Les causes ne sont pas interchangeables : « épuisé »
  /// est une conséquence des ventes du jour, « retiré » une décision du vendeur,
  /// « hors créneau » un horaire. Un même mot pour les trois tromperait le
  /// client sur ce qu'il peut faire.
  ProductUnavailability? get unavailability {
    if (!isAvailable) return ProductUnavailability.retire;
    if (!isInStock) return ProductUnavailability.epuise;
    if (!isWithinAvailabilityWindow) return ProductUnavailability.horsCreneau;
    return null;
  }

  /// URLs à afficher dans le carrousel : la galerie si disponible, sinon
  /// l'`imageUrl` legacy en fallback. Vide si aucune image.
  List<String> get galleryUrls {
    if (images.isNotEmpty) return [for (final img in images) img.url];
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) return [imageUrl!];
    return const [];
  }

  /// Vignette pour les cartes de liste : cover de la galerie si disponible,
  /// sinon l'`imageUrl` legacy. `null` si aucune image (→ placeholder).
  String? get thumbnailUrl => galleryUrls.isNotEmpty ? galleryUrls.first : null;

  /// Le produit est-il dans sa fenêtre de vente **maintenant** ?
  ///
  /// ## Le serveur décide, ce getter ne fait que le relayer
  ///
  /// `availableNow` est calculé par le backend avec `isWithinAvailabilityWindow`
  /// — la fonction même qu'applique le checkout pour accepter ou refuser une
  /// commande. Quand le champ est présent, on le lit et on s'arrête là.
  ///
  /// ## Le repli, et pourquoi l'ancien était faux
  ///
  /// La version précédente **recalculait toujours** la règle, avec deux erreurs :
  ///
  /// ```dart
  /// final now = DateTime.now();                        // fuseau de l'appareil
  /// return current.compareTo(availableFrom!) >= 0 &&
  ///        current.compareTo(availableUntil!) <= 0;    // ✗ minuit
  /// ```
  ///
  /// 1. une fenêtre « 22:00 → 02:00 » était **toujours fausse** : à 23:00,
  ///    `"23:00" <= "02:00"` ne tient pas. Un bar de nuit n'était jamais
  ///    commandable ;
  /// 2. l'heure venait de l'appareil, quand le serveur raisonne en heure de
  ///    Brazzaville (UTC+1).
  ///
  /// C'est exactement la divergence corrigée côté serveur en août — 17
  /// combinaisons sur 49 — réapparue côté client. Le repli existe encore, pour
  /// les réponses antérieures au champ, mais il applique désormais **la même
  /// règle**, testée sur le même tableau de cas que le backend
  /// (`test/models/availability_window_test.dart`).
  bool get isWithinAvailabilityWindow {
    if (availableNow != null) return availableNow!;
    return AvailabilityWindow.contains(
      from: availableFrom,
      until: availableUntil,
    );
  }

  /// **Prix d'appel** : le format le moins cher.
  ///
  /// ⚠️ Ce getter rendait `variants.first.prix`. Or l'ordre des variantes
  /// n'était pas garanti — les `include` du backend n'avaient aucun `orderBy`,
  /// et PostgreSQL déplace une ligne mise à jour dans son tas. Le « premier »
  /// format changeait donc tout seul après une édition du produit, et avec lui
  /// le prix affiché. Le serveur trie maintenant par prix croissant, mais on ne
  /// s'y fie pas : on prend explicitement le minimum, pour que la règle reste
  /// vraie servie par un backend antérieur.
  ///
  /// Règle **identique** à `startingPrice` côté web (`@lilia/utils`).
  double get startingPrice {
    final prices = variants.map((v) => v.prix).where((p) => p > 0);
    return prices.isEmpty
        ? prixOriginal
        : prices.reduce((a, b) => a < b ? a : b);
  }

  /// Vrai dès que le produit a plusieurs prix distincts — donc que le prix
  /// affiché doit être annoncé comme un « à partir de ».
  bool get hasPriceRange => variants.map((v) => v.prix).toSet().length > 1;

  /// Libellé du prix au catalogue — miroir de `priceLabel` côté web.
  ///
  /// Annoncer le prix d'un format sans dire lequel est une promesse qu'on ne
  /// tient pas au panier.
  String get priceLabel => hasPriceRange
      ? 'À partir de ${formatPrice(startingPrice)}'
      : formatPrice(startingPrice);

  /// @Deprecated — conservé le temps que les appelants migrent vers
  /// [startingPrice]. Il rendait `variants.first.prix`, c'est-à-dire un prix
  /// non déterministe (voir ci-dessus).
  double get displayPrice => startingPrice;

  factory Product.fromJson(Map<String, dynamic> json) {
    // variants peut être absent ou null pour certains produits — fallback []
    final variantsList = (json['variants'] as List?) ?? const [];
    final variants = variantsList
        .map((i) => ProductVariant.fromJson(i as Map<String, dynamic>))
        .toList();

    return Product(
      id: json['id'] as String,
      name: json['nom'] as String,
      description: (json['description'] as String?) ?? '',
      prixOriginal: (json['prixOriginal'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String?,
      images: GalleryImage.listFrom(json['images']),
      restaurantId: json['restaurantId'] as String,
      categoryId: json['categoryId'] as String?,
      category: json['category'] != null
          ? Category.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      variants: variants,
      stockRestant: json['stockRestant'] as int?,
      isAvailable: (json['isAvailable'] as bool?) ?? true,
      orderCount: json['orderCount'] as int?,
      restaurantName: json['restaurant']?['nom'] as String?,
      restaurantImageUrl: json['restaurant']?['imageUrl'] as String?,
      restaurantIsOpen: json['restaurant']?['isOpen'] as bool?,
      restaurantVendorType: json['restaurant']?['vendorType'] != null
          ? VendorType.fromString(json['restaurant']['vendorType'] as String?)
          : null,
      productType: ProductType.fromString(json['productType'] as String?),
      stockMode: StockMode.fromString(json['stockMode'] as String?),
      ingredients: json['ingredients'] as String?,
      shelfLifeDays: json['shelfLifeDays'] as int?,
      madeToOrder: (json['madeToOrder'] as bool?) ?? false,
      availableFrom: json['availableFrom'] as String?,
      availableUntil: json['availableUntil'] as String?,
      // Absent des réponses antérieures à septembre 2026 : `null` fait
      // retomber `isWithinAvailabilityWindow` sur le calcul local.
      availableNow: json['availableNow'] as bool?,
    );
  }
}

class ProductVariant {
  final String id;
  // label est nullable côté Prisma — fallback "Standard" pour l'affichage.
  final String? label;
  final double prix;

  ProductVariant({required this.id, this.label, required this.prix});

  /// Label affichable — jamais null, fallback "Standard".
  String get displayLabel => label ?? 'Standard';

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      label: json['label'] as String?,
      prix: (json['prix'] as num).toDouble(),
    );
  }
}
