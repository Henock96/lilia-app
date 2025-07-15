// lib/controllers/user_addresses_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/user/data/adresse_repository.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'adresse_controller.g.dart';

@riverpod
Future<List<Adresse>> userAdresses(Ref ref) async {
  final repository = ref.watch(adresseRepositoryProvider.notifier);
  return repository.getUserAdresses();
}
