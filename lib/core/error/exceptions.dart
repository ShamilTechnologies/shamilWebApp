// lib/core/error/exceptions.dart

class ServerException implements Exception {
    final String message;
    ServerException({required this.message});
}

class CacheException implements Exception {}

class AuthenticationException implements Exception {
    final String message;
    AuthenticationException({required this.message});
}

class NotFoundException implements Exception {} // Example for Firestore doc not found

// Add other specific exceptions (e.g., ValidationException, DeviceException for NFC/Serial)