import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  const AppUser({
    required this.uid, // Firebase UID
    this.id, // Database ID
    this.email,
    this.emailVerified = false,
    this.displayName,
    this.nom,
    this.phone,
  });

  // Firebase data
  final String uid;
  final String? email;
  final bool emailVerified;
  final String? displayName;

  // Local database data
  final String? id;
  final String? nom;
  final String? phone;

  // Mapper un User Firebase vers AppUser
  static AppUser? fromFirebaseUser(User? user) {
    if (user == null) {
      return null;
    }
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      emailVerified: user.emailVerified,
    );
  }

  // Mapper un JSON de votre backend vers AppUser
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      uid: json['firebaseUid'],
      email: json['email'],
      nom: json['nom'],
      phone: json['phone'],
      displayName: json['nom'], // On peut utiliser le nom de la bdd comme displayName
    );
  }

  // Copier l'objet avec de nouvelles valeurs
  AppUser copyWith({
    String? id,
    String? uid,
    String? email,
    bool? emailVerified,
    String? displayName,
    String? nom,
    String? phone,
  }) {
    return AppUser(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      displayName: displayName ?? this.displayName,
      nom: nom ?? this.nom,
      phone: phone ?? this.phone,
    );
  }
}
