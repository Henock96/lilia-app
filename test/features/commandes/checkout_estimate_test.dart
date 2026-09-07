// Couverture de la logique monétaire du checkout — la plus proche de l'argent
// et la seule qui n'était pas testée.
//
// Les trois divergences avec le backend documentées dans l'audit du 27/08/2026
// sont chacune verrouillées par un test : taux de commission en dur, arrondi
// des points de fidélité, et minimum de rachat.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/domain/checkout_estimate.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';

const _settings = PlatformSettings.fallback;

void main() {
  group('CheckoutEstimate — frais de service', () {
    test('applique le taux servi par le backend, pas une constante', () {
      const custom = PlatformSettings(
        serviceFeePercent: 10,
        loyaltyPointsPerOrder: 1,
        referrerBonusPoints: 1,
        loyaltyPointValueXaf: 5,
        loyaltyMinRedemption: 100,
      );

      final e = CheckoutEstimate.compute(
        subTotal: 10000,
        deliveryFee: 1000,
        promoDiscount: 0,
        loyaltyPoints: 0,
        useLoyaltyPoints: false,
        settings: custom,
      );

      // Le client affichait 800 (8 % en dur) là où le serveur facturait 1000.
      expect(e.serviceFee, 1000);
      expect(e.total, 12000);
    });

    test('arrondit la commission comme le serveur', () {
      final e = CheckoutEstimate.compute(
        subTotal: 3333,
        deliveryFee: 0,
        promoDiscount: 0,
        loyaltyPoints: 0,
        useLoyaltyPoints: false,
        settings: _settings,
      );

      // 3333 × 0.08 = 266.64 → 267
      expect(e.serviceFee, 267);
    });
  });

  group('CheckoutEstimate — points de fidélité', () {
    test('convertit en points entiers, comme le backend', () {
      // Cas exact de l'audit : montant dû 703 FCFA, solde largement suffisant.
      // Le client affichait une réduction de 703 (total 0) ; le serveur
      // applique 140 pts × 5 = 700, laissant 3 FCFA dus.
      final e = CheckoutEstimate.compute(
        subTotal: 703,
        deliveryFee: 0,
        promoDiscount: 0,
        loyaltyPoints: 1000,
        useLoyaltyPoints: true,
        settings: const PlatformSettings(
          serviceFeePercent: 0,
          loyaltyPointsPerOrder: 1,
        referrerBonusPoints: 1,
          loyaltyPointValueXaf: 5,
          loyaltyMinRedemption: 100,
        ),
      );

      expect(e.loyaltyPointsUsed, 140);
      expect(e.loyaltyDiscount, 700);
      expect(e.total, 3);
    });

    test('ne consomme jamais plus de points que nécessaire', () {
      final e = CheckoutEstimate.compute(
        subTotal: 500,
        deliveryFee: 0,
        promoDiscount: 0,
        loyaltyPoints: 10000, // 50 000 FCFA de valeur théorique
        useLoyaltyPoints: true,
        settings: const PlatformSettings(
          serviceFeePercent: 0,
          loyaltyPointsPerOrder: 1,
        referrerBonusPoints: 1,
          loyaltyPointValueXaf: 5,
          loyaltyMinRedemption: 100,
        ),
      );

      expect(e.loyaltyPointsUsed, 100);
      expect(e.loyaltyDiscount, 500);
      expect(e.total, 0);
    });

    test('plafonné au solde réel du client', () {
      final e = CheckoutEstimate.compute(
        subTotal: 10000,
        deliveryFee: 0,
        promoDiscount: 0,
        loyaltyPoints: 120,
        useLoyaltyPoints: true,
        settings: const PlatformSettings(
          serviceFeePercent: 0,
          loyaltyPointsPerOrder: 1,
        referrerBonusPoints: 1,
          loyaltyPointValueXaf: 5,
          loyaltyMinRedemption: 100,
        ),
      );

      expect(e.loyaltyPointsUsed, 120);
      expect(e.loyaltyDiscount, 600);
      expect(e.total, 9400);
    });

    test('aucun point utilisé sous le minimum de rachat', () {
      // Le seuil par défaut est passé de 100 à 1 point : avec un forfait de
      // 1 point par commande, exiger 100 points aurait imposé 100 commandes
      // avant le premier usage. On force donc un seuil pour tester la règle
      // elle-même, pas sa valeur du moment.
      const strict = PlatformSettings(
        serviceFeePercent: 8,
        loyaltyPointsPerOrder: 1,
        loyaltyPointValueXaf: 50,
        loyaltyMinRedemption: 10,
        referrerBonusPoints: 1,
      );

      final e = CheckoutEstimate.compute(
        subTotal: 10000,
        deliveryFee: 0,
        promoDiscount: 0,
        loyaltyPoints: 9, // minimum = 10
        useLoyaltyPoints: true,
        settings: strict,
      );

      expect(e.loyaltyPointsUsed, 0);
      expect(e.loyaltyDiscount, 0);
    });

    test('aucun point utilisé si le client n’a pas activé le switch', () {
      final e = CheckoutEstimate.compute(
        subTotal: 10000,
        deliveryFee: 0,
        promoDiscount: 0,
        loyaltyPoints: 5000,
        useLoyaltyPoints: false,
        settings: _settings,
      );

      expect(e.loyaltyDiscount, 0);
    });
  });

  group('CheckoutEstimate — promo et bornes', () {
    test('la promo est déduite avant le calcul de la fidélité', () {
      final e = CheckoutEstimate.compute(
        subTotal: 10000,
        deliveryFee: 1000,
        promoDiscount: 2000,
        loyaltyPoints: 100,
        useLoyaltyPoints: true,
        settings: const PlatformSettings(
          serviceFeePercent: 0,
          loyaltyPointsPerOrder: 1,
        referrerBonusPoints: 1,
          loyaltyPointValueXaf: 5,
          loyaltyMinRedemption: 100,
        ),
      );

      // 10000 + 1000 - 2000 = 9000 dus, puis 100 pts × 5 = 500 de réduction.
      expect(e.loyaltyDiscount, 500);
      expect(e.total, 8500);
    });

    test('le total ne descend jamais sous zéro', () {
      final e = CheckoutEstimate.compute(
        subTotal: 1000,
        deliveryFee: 0,
        promoDiscount: 5000, // promo supérieure au montant
        loyaltyPoints: 0,
        useLoyaltyPoints: false,
        settings: _settings,
      );

      expect(e.total, 0);
      expect(e.total, isNonNegative);
    });

    test('une promo « livraison offerte » se traduit par deliveryFee à 0', () {
      final e = CheckoutEstimate.compute(
        subTotal: 5000,
        deliveryFee: 0, // le repo promo renvoie newDeliveryFee = 0
        promoDiscount: 0,
        loyaltyPoints: 0,
        useLoyaltyPoints: false,
        settings: _settings,
      );

      expect(e.deliveryFee, 0);
      expect(e.total, 5400); // 5000 + 8 %
    });
  });

  group('PlatformSettings', () {
    test('serviceFeeRate convertit le pourcentage en taux', () {
      expect(_settings.serviceFeeRate, closeTo(0.08, 1e-9));
      expect(
        const PlatformSettings(
          serviceFeePercent: 12.5,
          loyaltyPointsPerOrder: 1,
        referrerBonusPoints: 1,
          loyaltyPointValueXaf: 5,
          loyaltyMinRedemption: 100,
        ).serviceFeeRate,
        closeTo(0.125, 1e-9),
      );
    });

    test('le parsing retombe sur les défauts Prisma si un champ manque', () {
      final s = PlatformSettings.fromJson(<String, dynamic>{});

      expect(s.serviceFeePercent, 8);
      expect(s.loyaltyPointValueXaf, 50);
      expect(s.loyaltyMinRedemption, 1);
      expect(s.loyaltyPointsPerOrder, 1);
      expect(s.referrerBonusPoints, 1);
      expect(s.maintenanceMode, isFalse);
    });

    test('le parsing lit les valeurs servies par le backend', () {
      final s = PlatformSettings.fromJson(<String, dynamic>{
        'serviceFeePercent': 10,
        'loyaltyPointValueXaf': 10,
        'loyaltyMinRedemption': 200,
        'maintenanceMode': true,
        'maintenanceMessage': 'Maintenance en cours',
      });

      expect(s.serviceFeePercent, 10);
      expect(s.loyaltyPointValueXaf, 10);
      expect(s.loyaltyMinRedemption, 200);
      expect(s.maintenanceMode, isTrue);
      expect(s.maintenanceMessage, 'Maintenance en cours');
    });
  });

  group('CheckoutEstimate — assiette des points (septembre 2026)', () {
    // Les points s'imputaient sur `subTotal + livraison + frais de service`.
    // Ils finançaient donc la course du livreur et le fonctionnement de la
    // plateforme, deux postes réellement décaissés que le reversement vendeur
    // ne compense pas. Ils ne réduisent plus que la nourriture.
    test('les points ne paient PAS la livraison ni les frais de service', () {
      final e = CheckoutEstimate.compute(
        subTotal: 1000,
        deliveryFee: 1000,
        promoDiscount: 0,
        loyaltyPoints: 100, // largement de quoi tout couvrir
        useLoyaltyPoints: true,
        settings: _settings, // 1 pt = 50 FCFA
      );

      // Assiette = 1000 FCFA de nourriture → 20 points au maximum.
      expect(e.loyaltyPointsUsed, 20);
      expect(e.loyaltyDiscount, 1000);
      // Restent dus : livraison 1000 + frais de service 80.
      expect(e.total, 1080);
    });

    test('la promo réduit l’assiette avant les points', () {
      final e = CheckoutEstimate.compute(
        subTotal: 1000,
        deliveryFee: 0,
        promoDiscount: 400,
        loyaltyPoints: 100,
        useLoyaltyPoints: true,
        settings: _settings,
      );

      // Assiette = 1000 - 400 = 600 → 12 points.
      expect(e.loyaltyPointsUsed, 12);
      expect(e.loyaltyDiscount, 600);
    });

    test('le seuil de rachat vaut 1 point', () {
      final e = CheckoutEstimate.compute(
        subTotal: 1000,
        deliveryFee: 0,
        promoDiscount: 0,
        loyaltyPoints: 1,
        useLoyaltyPoints: true,
        settings: _settings,
      );

      expect(e.loyaltyPointsUsed, 1);
      expect(e.loyaltyDiscount, 50);
    });

    test('un solde nul n’ouvre aucune remise', () {
      final e = CheckoutEstimate.compute(
        subTotal: 1000,
        deliveryFee: 0,
        promoDiscount: 0,
        loyaltyPoints: 0,
        useLoyaltyPoints: true,
        settings: _settings,
      );

      expect(e.loyaltyPointsUsed, 0);
      expect(e.loyaltyDiscount, 0);
    });

    test('ne consomme jamais plus de points que l’assiette n’en absorbe', () {
      final e = CheckoutEstimate.compute(
        subTotal: 120, // 2 points absorbables (100 FCFA), pas 3
        deliveryFee: 0,
        promoDiscount: 0,
        loyaltyPoints: 50,
        useLoyaltyPoints: true,
        settings: _settings,
      );

      expect(e.loyaltyPointsUsed, 2);
      expect(e.loyaltyDiscount, 100);
    });
  });

  group('PlatformSettings — conversion unique', () {
    test('pointsToXaf suit le barème serveur, pas une constante', () {
      const custom = PlatformSettings(
        serviceFeePercent: 8,
        loyaltyPointsPerOrder: 1,
        loyaltyPointValueXaf: 75,
        loyaltyMinRedemption: 1,
        referrerBonusPoints: 1,
      );

      expect(custom.pointsToXaf(4), 300);
      expect(_settings.pointsToXaf(4), 200);
    });
  });
}
