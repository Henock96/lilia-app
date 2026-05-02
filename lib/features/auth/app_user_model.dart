import 'package:firebase_auth/firebase_auth.dart';

import '../../models/adresse.dart';

class AppUser {
  const AppUser({
    required this.uid,
    this.id,
    this.email,
    this.emailVerified = false,
    this.displayName,
    this.nom,
    this.phone,
    this.adresse,
    this.imageUrl,
    this.referralCode,
    this.loyaltyPoints = 0,
  });

  final String uid;
  final String? email;
  final bool emailVerified;
  final String? displayName;
  final String? id;
  final String? nom;
  final String? phone;
  final String? imageUrl;
  final Adresse? adresse;
  final String? referralCode;
  final int loyaltyPoints;

  static AppUser? fromFirebaseUser(User? user) {
    if (user == null) return null;
    return AppUser(uid: user.uid, email: user.email, displayName: user.displayName, emailVerified: user.emailVerified);
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      uid: json['firebaseUid'],
      email: json['email'],
      nom: json['nom'],
      phone: json['phone'],
      imageUrl: json['imageUrl'],
      referralCode: json['referralCode'],
      loyaltyPoints: (json['loyaltyPoints'] as num?)?.toInt() ?? 0,
    );
  }

  AppUser copyWith({
    String? id,
    String? uid,
    String? email,
    bool? emailVerified,
    String? displayName,
    String? nom,
    String? imageUrl,
    String? phone,
    Adresse? adresse,
    String? referralCode,
    int? loyaltyPoints,
  }) {
    return AppUser(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      displayName: displayName ?? this.displayName,
      nom: nom ?? this.nom,
      phone: phone ?? this.phone,
      adresse: adresse ?? this.adresse,
      imageUrl: imageUrl ?? this.imageUrl,
      referralCode: referralCode ?? this.referralCode,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
    );
  }
}
