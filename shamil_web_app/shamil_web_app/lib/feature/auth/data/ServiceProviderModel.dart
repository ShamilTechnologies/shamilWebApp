import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceProviderModel {
  final String uid;
  final String name;
  final String email;
  final String businessName;
  final String businessDescription;
  final String phone;
  final String logoUrl;
  final String placePicUrl;
  final List<String> facilitiesPicsUrls;
  final bool isApproved;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  ServiceProviderModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.businessName,
    required this.businessDescription,
    required this.phone,
    this.logoUrl = '',
    this.placePicUrl = '',
    this.facilitiesPicsUrls = const [],
    this.isApproved = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ServiceProviderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceProviderModel(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      businessName: data['businessName'] ?? '',
      businessDescription: data['businessDescription'] ?? '',
      phone: data['phone'] ?? '',
      logoUrl: data['logoUrl'] ?? '',
      placePicUrl: data['placePicUrl'] ?? '',
      facilitiesPicsUrls: List<String>.from(data['facilitiesPicsUrls'] ?? []),
      isApproved: data['isApproved'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'businessName': businessName,
      'businessDescription': businessDescription,
      'phone': phone,
      'logoUrl': logoUrl,
      'placePicUrl': placePicUrl,
      'facilitiesPicsUrls': facilitiesPicsUrls,
      'isApproved': isApproved,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
