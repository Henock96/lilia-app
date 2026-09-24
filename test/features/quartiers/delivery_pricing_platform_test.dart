import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/quartiers/domain/delivery_fee_label.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/models/quartier.dart';
import 'package:lilia_app/utils/currency.dart';

/// F3-02 — tarification de livraison plateforme, côté app client.
void main() {
  PlatformSettings settings(Map<String, dynamic> extra) =>
      PlatformSettings.fromJson({'serviceFeePercent': 15, ...extra});

  group('PlatformSettings — mode de tarification', () {
    test('serveur antérieur à F3-02 : mode vendeur', () {
      final s = settings({});
      expect(s.isPlatformDeliveryPricing, isFalse);
      expect(s.deliveryFeeFromXaf, isNull);
    });

    test('mode plateforme et plancher lus', () {
      final s = settings({
        'deliveryPricingMode': 'PLATFORM',
        'deliveryFeeFromXaf': 800,
      });
      expect(s.isPlatformDeliveryPricing, isTrue);
      expect(s.deliveryFeeFromXaf, 800);
    });
  });

  group('deliveryFeeLabel', () {
    test('mode vendeur : le prix du vendeur', () {
      expect(deliveryFeeLabel(1000, settings({})), formatPrice(1000));
    });

    test('mode vendeur à 0 : gratuit', () {
      expect(deliveryFeeLabel(0, settings({})), 'Gratuit');
    });

    test(
      'mode plateforme : le plancher de la grille, jamais le prix vendeur',
      () {
        expect(
          deliveryFeeLabel(
            0,
            settings({
              'deliveryPricingMode': 'PLATFORM',
              'deliveryFeeFromXaf': 800,
            }),
          ),
          'Dès ${formatPrice(800)}',
        );
      },
    );

    test('mode plateforme sans plancher : selon la distance', () {
      expect(
        deliveryFeeLabel(1000, settings({'deliveryPricingMode': 'PLATFORM'})),
        'Selon la distance',
      );
    });

    test('barème pas encore chargé : prix du vendeur', () {
      expect(deliveryFeeLabel(1000, null), formatPrice(1000));
    });
  });

  group('DeliveryFeeResult', () {
    test('devis plateforme : part offerte et seuil', () {
      final q = DeliveryFeeResult.fromJson({
        'mode': 'PLATFORM',
        'fee': 500,
        'baseFee': 800,
        'vendorSubsidy': 300,
        'freeDeliveryThreshold': null,
      });
      expect(q.isPlatform, isTrue);
      expect(q.fee, 500);
      expect(q.baseFee, 800);
      expect(q.vendorSubsidy, 300);
    });

    test('devis vendeur : aucune part offerte', () {
      final q = DeliveryFeeResult.fromJson({'mode': 'FIXED', 'fee': 1000});
      expect(q.vendorSubsidy, 0);
      expect(q.baseFee, isNull);
    });
  });
}
