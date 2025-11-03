import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'patient' or 'pharmacy'
  final String profileImageUrl;
  final String bio;
  final String location;
  final String phoneNumber;
  final String? pharmacyName;    // <-- NEW: For pharmacy role
  final String? pharmacyAddress; // <-- NEW: For pharmacy role
  final String? pharmacyContact; // <-- NEW: For pharmacy role (e.g., landline or secondary number)


  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.profileImageUrl = '',
    this.bio = '',
    this.location = '',
    this.phoneNumber = '',
    this.pharmacyName,      // <-- NEW
    this.pharmacyAddress,   // <-- NEW
    this.pharmacyContact,   // <-- NEW
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      bio: data['bio'] ?? '',
      location: data['location'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      pharmacyName: data['pharmacyName'],    // <-- NEW
      pharmacyAddress: data['pharmacyAddress'], // <-- NEW
      pharmacyContact: data['pharmacyContact'], // <-- NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'location': location,
      'phoneNumber': phoneNumber,
      'pharmacyName': pharmacyName,    // <-- NEW
      'pharmacyAddress': pharmacyAddress, // <-- NEW
      'pharmacyContact': pharmacyContact, // <-- NEW
    };
  }

  // Method to create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? profileImageUrl,
    String? bio,
    String? location,
    String? phoneNumber,
    String? pharmacyName,
    String? pharmacyAddress,
    String? pharmacyContact,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      pharmacyAddress: pharmacyAddress ?? this.pharmacyAddress,
      pharmacyContact: pharmacyContact ?? this.pharmacyContact,
    );
  }
}
