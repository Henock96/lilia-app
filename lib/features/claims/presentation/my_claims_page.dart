import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../routing/app_route_enum.dart';
import '../domain/claim.dart';
import 'claims_providers.dart';

/// « Mes demandes » (F3-06) : les réclamations du client et leur issue.
class MyClaimsPage extends ConsumerWidget {
  const MyClaimsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myClaimsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes demandes')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myClaimsProvider.future),
        child: switch (state) {
          // L'erreur d'abord : Riverpod réessaie seul, et un `when` laisserait
          // la roue tourner indéfiniment pendant ces nouvelles tentatives.
          AsyncValue(hasError: true, hasValue: false, :final error?) =>
            ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$error', textAlign: TextAlign.center),
                ),
              ],
            ),
          AsyncValue(:final value?) when value.isEmpty => ListView(
            children: const [
              Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucune demande. Un souci avec une commande livrée ? '
                  'Ouvrez-la depuis « Mes commandes ».',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          AsyncValue(:final value?) => ListView.separated(
            itemCount: value.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = value[i];
              return ListTile(
                key: Key('claim-${c.id}'),
                title: Text(
                  'Commande #${c.orderRef} — ${claimReasonLabel(c.reason)}',
                ),
                subtitle: Text(
                  '${claimStatusLabel(c.status, c.outcome)} · '
                  '${DateFormat('d MMM, HH:mm', 'fr_FR').format(c.createdAt)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(
                  AppRoutes.claimDetail.routeName,
                  pathParameters: {'claimId': c.id},
                ),
              );
            },
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}
