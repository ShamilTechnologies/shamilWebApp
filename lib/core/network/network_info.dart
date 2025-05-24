import 'package:connectivity_plus/connectivity_plus.dart';

/// Interface for checking network connectivity status
abstract class NetworkInfo {
  /// Checks if the device is connected to the internet
  Future<bool> get isConnected;
}

/// Implementation of NetworkInfo using connectivity_plus package
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;

  /// Creates a NetworkInfo implementation with the given connectivity instance
  NetworkInfoImpl(this._connectivity);

  @override
  Future<bool> get isConnected async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }
}
