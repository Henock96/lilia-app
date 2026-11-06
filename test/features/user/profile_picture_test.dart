// La photo de profil : un échec se dit.
//
// Audit du 05/11/2026 : `updateProfilePicture` finissait en `AsyncError` que
// personne n'affichait sur la page profil, et ignorait le message rendu par
// `updateUser`. Le client choisissait une photo, et rien ne se passait.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/features/user/data/cloudinary_service.dart';
import 'package:lilia_app/features/user/data/user_repository.dart';

class _Galerie extends Fake implements ImagePicker {
  _Galerie(this.image, {this.panne, this.barriere});

  final XFile? image;
  final Object? panne;
  final Completer<void>? barriere;
  int appels = 0;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    appels++;
    await barriere?.future;
    if (panne != null) throw panne!;
    return image;
  }
}

class _Cloudinary extends CloudinaryService {
  _Cloudinary(this._envoi);

  final Future<String?> Function() _envoi;

  @override
  Future<String?> uploadImage(XFile image) => _envoi();
}

class _Depot extends Fake implements UserRepository {
  final recus = <Map<String, dynamic>>[];
  Object? refus;

  @override
  Future<AppUser> updateUserProfile(Map<String, dynamic> data) async {
    if (refus != null) throw refus!;
    recus.add(data);
    return const AppUser(uid: 'uid-a');
  }
}

void main() {
  late _Depot depot;

  ProfileController monter(
    _Galerie galerie, {
    Future<String?> Function()? envoi,
  }) {
    final container = ProviderContainer(
      overrides: [
        imagePickerProvider.overrideWithValue(galerie),
        cloudinaryServiceProvider.overrideWithValue(
          _Cloudinary(envoi ?? () async => null),
        ),
        userRepositoryProvider.overrideWithValue(depot),
      ],
    );
    addTearDown(container.dispose);
    return container.read(profileControllerProvider.notifier);
  }

  Future<String?> changerLaPhoto({
    XFile? choisie,
    required Future<String?> Function() envoi,
  }) => monter(_Galerie(choisie), envoi: envoi).updateProfilePicture();

  final photo = XFile('photo.jpg');

  setUp(() => depot = _Depot());

  test('envoi refusé par Cloudinary : un message à montrer', () async {
    final message = await changerLaPhoto(
      choisie: photo,
      envoi: () async => null,
    );

    expect(message, isNotNull);
    expect(depot.recus, isEmpty);
  });

  test('réseau coupé pendant l’envoi : un message à montrer', () async {
    final message = await changerLaPhoto(
      choisie: photo,
      envoi: () async => throw Exception('coupure'),
    );

    expect(message, isNotNull);
    expect(message, isNot(contains('Exception')));
  });

  test('profil refusé par le serveur : son message est rendu', () async {
    depot.refus = const ApiException('Image refusée.', statusCode: 400);

    final message = await changerLaPhoto(
      choisie: photo,
      envoi: () async => 'https://img.test/a.jpg',
    );

    expect(message, 'Image refusée.');
  });

  test('sélecteur en échec : un message, pas une exception', () async {
    final message = await monter(
      _Galerie(null, panne: PlatformException(code: 'invalid_image')),
    ).updateProfilePicture();

    expect(message, isNotNull);
  });

  test('deux appuis rapides : un seul sélecteur', () async {
    final barriere = Completer<void>();
    final galerie = _Galerie(null, barriere: barriere);
    final profil = monter(galerie);

    final premier = profil.updateProfilePicture();
    final second = await profil.updateProfilePicture();
    barriere.complete();
    await premier;

    expect(galerie.appels, 1, reason: 'le second lèverait `already_active`');
    expect(second, isNull);
  });

  test('sélection annulée : rien à dire', () async {
    final message = await changerLaPhoto(envoi: () async => 'inutile');

    expect(message, isNull);
    expect(depot.recus, isEmpty);
  });

  test('succès : rien à dire, et l’adresse de l’image part au serveur',
      () async {
    final message = await changerLaPhoto(
      choisie: photo,
      envoi: () async => 'https://img.test/a.jpg',
    );

    expect(message, isNull);
    expect(depot.recus.single['imageUrl'], 'https://img.test/a.jpg');
  });
}
