// models/ad_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AdModel {
  final String id;
  final String imageUrl;
  final String title;
  final String description;
  final String pharmacyId;
  final String pharmacyName;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String type; // 'banner', 'offer', 'poster'
  final String? offerCode;
  final double? discountPercentage;
  final DateTime createdAt;

  AdModel({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.type,
    this.offerCode,
    this.discountPercentage,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'description': description,
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'type': type,
      'offerCode': offerCode,
      'discountPercentage': discountPercentage,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Add this method
  factory AdModel.fromMap(Map<String, dynamic> data, String id) {
    return AdModel(
      id: id,
      imageUrl: data['imageUrl'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      pharmacyId: data['pharmacyId'] ?? '',
      pharmacyName: data['pharmacyName'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      type: data['type'] ?? 'banner',
      offerCode: data['offerCode'],
      discountPercentage: data['discountPercentage']?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory AdModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdModel(
      id: doc.id,
      imageUrl: data['imageUrl'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      pharmacyId: data['pharmacyId'] ?? '',
      pharmacyName: data['pharmacyName'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      type: data['type'] ?? 'banner',
      offerCode: data['offerCode'],
      discountPercentage: data['discountPercentage']?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}