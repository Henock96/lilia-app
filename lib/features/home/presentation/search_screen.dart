import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';
import 'package:lilia_app/utils/async_value_ui.dart';

import '../application/recent_searches_provider.dart';
import '../data/remote/home_controller.dart';
import '../domain/search_sections.dart';
import 'widgets/search_result_cards.dart';

/// Recherche de plats et de boutiques.
///
/// Trois états, dans cet ordre :
/// 1. champ vide — **Suggestions** : recherches récentes (sur cet appareil),
///    catégories et plats commandables maintenant (serveur) ;
/// 2. une seule lettre — on attend la suivante ;
/// 3. résultats — boutiques, puis plats commandables maintenant, puis plats
///    qui ne le sont pas, avec leur raison (cf. [SearchSections]).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    // Reconstruit tout de suite pour la croix d'effacement ; la requête
    // serveur, elle, attend la fin de la frappe.
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  /// Remplit le champ et lance la recherche sans attendre (suggestion,
  /// recherche récente).
  void _searchFor(String value) {
    _debounce?.cancel();
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() => _query = value.trim());
    _remember();
    _focus.unfocus();
  }

  /// Mémorise la recherche courante : à la validation du clavier, ou quand le
  /// client ouvre un résultat — c'est là qu'elle a servi.
  void _remember() => ref.read(recentSearchesProvider.notifier).add(_query);

  void _clear() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Garde l'historique en vie tant que l'écran est ouvert : sans abonné
    // pendant l'affichage des résultats, le provider était libéré et
    // l'écriture qui suit `await future` tombait sur un `Ref` détruit.
    // Il reste auto-libéré ensuite — la clé par compte est relue à la
    // prochaine ouverture.
    ref.watch(recentSearchesProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: LiliaSpacing.sm),
          child: TextField(
            controller: _searchController,
            focusNode: _focus,
            autofocus: true,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) {
              _debounce?.cancel();
              setState(() => _query = v.trim());
              _remember();
            },
            style: TextStyle(fontSize: 16, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Plat, boutique, spécialité…',
              hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              tooltip: 'Effacer la recherche',
              onPressed: _clear,
              icon: Icon(Icons.close, color: cs.onSurfaceVariant),
            ),
        ],
      ),
      body: switch (_query.length) {
        0 => _SuggestionsView(onPick: _searchFor),
        < kSearchMinLength => const _Hint(
          icon: Icons.keyboard_outlined,
          text: 'Continuez à taper : au moins 2 lettres.',
        ),
        _ => _buildSearchResults(),
      },
    );
  }

  Widget _buildSearchResults() {
    final resultsAsync = ref.watch(searchResultsProvider(_query));

    return resultsAsync.whenUi(
      data: (results) {
        // ⚠️ Aucun événement de recherche ici, et pour deux raisons.
        //
        // L'appel précédent envoyait `query` — le texte saisi par le client,
        // que le contrat interdit d'envoyer (contenu libre : il contient
        // régulièrement un nom, parfois un numéro).
        //
        // Il était de surcroît placé dans un `build` : chaque reconstruction de
        // l'écran — clavier, thème, arrivée d'une réponse — le renvoyait.
        final sections = SearchSections.from(results);
        if (sections.isEmpty) {
          return _Hint(
            icon: Icons.search_off,
            text: 'Aucun résultat pour « $_query »',
            detail:
                'Vérifiez l’orthographe, ou essayez un mot plus court : '
                '« poulet », « gâteau », le nom d’une boutique…',
          );
        }

        final orderable = sections.orderableProducts;
        final unavailable = sections.unavailableProducts;
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            LiliaSpacing.md,
            0,
            LiliaSpacing.md,
            LiliaSpacing.xl,
          ),
          children: [
            _ResultsSummary(total: sections.total, orderable: orderable.length),
            if (sections.vendors.isNotEmpty) ...[
              SearchSectionHeader(
                'Boutiques',
                subtitle:
                    '${sections.vendors.length} '
                    '${sections.vendors.length > 1 ? 'boutiques' : 'boutique'}',
              ),
              for (final v in sections.vendors)
                SearchVendorCard(vendor: v, onOpen: _remember),
            ],
            if (orderable.isNotEmpty) ...[
              const SearchSectionHeader(
                'Commandable maintenant',
                subtitle: 'Boutique ouverte, plat au menu et en stock',
              ),
              for (final p in orderable)
                SearchProductCard(product: p, onOpen: _remember),
            ],
            if (unavailable.isNotEmpty) ...[
              const SearchSectionHeader(
                'Pas commandable pour l’instant',
                subtitle:
                    'Boutique fermée, épuisé ou hors créneau : '
                    'la fiche reste consultable',
              ),
              for (final p in unavailable)
                SearchProductCard(product: p, onOpen: _remember),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => BuildErrorState(
        err,
        onRetry: () => ref.invalidate(searchResultsProvider(_query)),
      ),
    );
  }
}

/// « 12 résultats · 5 commandables maintenant ».
class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({required this.total, required this.orderable});

  final int total;
  final int orderable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = [
      '$total ${total > 1 ? 'résultats' : 'résultat'}',
      if (orderable > 0)
        '$orderable ${orderable > 1 ? 'plats commandables' : 'plat commandable'} maintenant',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: LiliaSpacing.sp3),
      child: Semantics(
        liveRegion: true,
        child: Text(
          parts.join(' · '),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Champ vide : recherches récentes, puis suggestions tirées de ce qui est
/// réellement commandable maintenant.
class _SuggestionsView extends ConsumerWidget {
  const _SuggestionsView({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider).value ?? const [];
    // Même source que le rail de l'accueil (et même filtre de type de
    // vendeur) : rien n'est proposé que le serveur ne déclare commandable.
    final availableNow = ref.watch(availableNowProvider);
    final products = availableNow.value?.products ?? const [];
    final suggestions = searchSuggestionsFrom(products);

    if (recent.isEmpty && products.isEmpty) {
      if (availableNow.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      // Réponse reçue et vide : le serveur dit que rien n'est commandable
      // maintenant (le soir, tout est souvent fermé). On le dit, sans rien
      // inventer — la recherche reste ouverte.
      final allClosed = availableNow.hasValue && !availableNow.hasError;
      return _Hint(
        icon: allClosed ? Icons.nightlight_outlined : Icons.search,
        text: 'Recherchez un plat ou une boutique',
        detail: allClosed
            ? 'Aucune boutique ne prend de commande en ce moment. '
                  'Vous pouvez quand même chercher et consulter les cartes.'
            : null,
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        LiliaSpacing.md,
        0,
        LiliaSpacing.md,
        LiliaSpacing.xl,
      ),
      children: [
        if (recent.isNotEmpty) ...[
          SearchSectionHeader(
            'Recherches récentes',
            trailing: TextButton(
              onPressed: () =>
                  ref.read(recentSearchesProvider.notifier).clear(),
              child: const Text('Effacer'),
            ),
          ),
          Wrap(
            spacing: LiliaSpacing.sm,
            runSpacing: LiliaSpacing.sm,
            children: [
              for (final q in recent)
                InputChip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: Text(q),
                  onPressed: () => onPick(q),
                  onDeleted: () =>
                      ref.read(recentSearchesProvider.notifier).remove(q),
                  deleteButtonTooltipMessage: 'Retirer « $q »',
                ),
            ],
          ),
        ],
        if (suggestions.isNotEmpty) ...[
          const SearchSectionHeader(
            'Suggestions',
            subtitle: 'Catégories commandables en ce moment',
          ),
          Wrap(
            spacing: LiliaSpacing.sm,
            runSpacing: LiliaSpacing.sm,
            children: [
              for (final s in suggestions)
                ActionChip(
                  avatar: const Icon(Icons.local_dining_outlined, size: 18),
                  label: Text(s),
                  onPressed: () => onPick(s),
                ),
            ],
          ),
        ],
        if (products.isNotEmpty) ...[
          const SearchSectionHeader(
            'Disponible maintenant',
            subtitle: 'Boutiques ouvertes, plats en stock',
          ),
          for (final p in products) SearchProductCard(product: p),
        ],
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, this.detail});

  final IconData icon;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(LiliaSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: LiliaSpacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(color: cs.onSurface),
            ),
            if (detail != null) ...[
              const SizedBox(height: LiliaSpacing.sm),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
