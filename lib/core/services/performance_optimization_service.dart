/// File: lib/core/services/performance_optimization_service.dart
/// Performance optimization service to prevent excessive API calls and improve app performance
library;

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Service to manage performance optimizations and prevent excessive API calls
class PerformanceOptimizationService {
  static final PerformanceOptimizationService _instance =
      PerformanceOptimizationService._internal();
  factory PerformanceOptimizationService() => _instance;
  PerformanceOptimizationService._internal();

  // Request throttling
  final Map<String, DateTime> _lastRequestTimes = {};
  final Map<String, Timer> _pendingRequests = {};
  final Map<String, Completer<dynamic>> _pendingCompleters = {};

  // Cache for recent results
  final Map<String, dynamic> _resultCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Configuration
  static const Duration _defaultThrottleDuration = Duration(seconds: 5);
  static const Duration _defaultCacheDuration = Duration(minutes: 2);
  static const int _maxCacheSize = 100;

  /// Throttle a request to prevent excessive calls
  Future<T> throttleRequest<T>(
    String requestKey,
    Future<T> Function() requestFunction, {
    Duration? throttleDuration,
    Duration? cacheDuration,
    bool useCache = true,
  }) async {
    final throttleDur = throttleDuration ?? _defaultThrottleDuration;
    final cacheDur = cacheDuration ?? _defaultCacheDuration;

    // Check cache first if enabled
    if (useCache && _hasValidCache(requestKey, cacheDur)) {
      print('PerformanceOptimization: Returning cached result for $requestKey');
      return _resultCache[requestKey] as T;
    }

    // Check if request is already pending
    if (_pendingCompleters.containsKey(requestKey)) {
      print('PerformanceOptimization: Request already pending for $requestKey');
      return await _pendingCompleters[requestKey]!.future as T;
    }

    // Check throttling
    final lastRequestTime = _lastRequestTimes[requestKey];
    final now = DateTime.now();

    if (lastRequestTime != null &&
        now.difference(lastRequestTime) < throttleDur) {
      print('PerformanceOptimization: Request throttled for $requestKey');

      // Return cached result if available
      if (useCache && _resultCache.containsKey(requestKey)) {
        return _resultCache[requestKey] as T;
      }

      // Wait for throttle period to end
      final waitTime = throttleDur - now.difference(lastRequestTime);
      await Future.delayed(waitTime);
    }

    // Create completer for this request
    final completer = Completer<T>();
    _pendingCompleters[requestKey] = completer;

    try {
      print('PerformanceOptimization: Executing request for $requestKey');

      // Execute the request
      final result = await requestFunction();

      // Update cache
      if (useCache) {
        _updateCache(requestKey, result, cacheDur);
      }

      // Update last request time
      _lastRequestTimes[requestKey] = DateTime.now();

      // Complete the request
      completer.complete(result);

      return result;
    } catch (error) {
      completer.completeError(error);
      rethrow;
    } finally {
      // Clean up pending request
      _pendingCompleters.remove(requestKey);
    }
  }

  /// Debounce a function call
  void debounce(
    String key,
    VoidCallback function, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    // Cancel existing timer
    _pendingRequests[key]?.cancel();

    // Create new timer
    _pendingRequests[key] = Timer(delay, () {
      function();
      _pendingRequests.remove(key);
    });
  }

  /// Check if cache has valid entry
  bool _hasValidCache(String key, Duration cacheDuration) {
    if (!_resultCache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }

    final cacheTime = _cacheTimestamps[key]!;
    final now = DateTime.now();

    return now.difference(cacheTime) < cacheDuration;
  }

  /// Update cache with new result
  void _updateCache<T>(String key, T result, Duration cacheDuration) {
    // Manage cache size
    if (_resultCache.length >= _maxCacheSize) {
      _evictOldestCacheEntry();
    }

    _resultCache[key] = result;
    _cacheTimestamps[key] = DateTime.now();

    // Schedule cache cleanup
    Timer(cacheDuration, () {
      _resultCache.remove(key);
      _cacheTimestamps.remove(key);
    });
  }

  /// Evict oldest cache entry
  void _evictOldestCacheEntry() {
    if (_cacheTimestamps.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cacheTimestamps.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _resultCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
  }

  /// Clear cache for specific key
  void clearCache(String key) {
    _resultCache.remove(key);
    _cacheTimestamps.remove(key);
  }

  /// Clear all cache
  void clearAllCache() {
    _resultCache.clear();
    _cacheTimestamps.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _resultCache.length,
      'maxCacheSize': _maxCacheSize,
      'pendingRequests': _pendingRequests.length,
      'throttledKeys': _lastRequestTimes.keys.toList(),
    };
  }

  /// Check if request is currently throttled
  bool isThrottled(String key, {Duration? throttleDuration}) {
    final throttleDur = throttleDuration ?? _defaultThrottleDuration;
    final lastRequestTime = _lastRequestTimes[key];

    if (lastRequestTime == null) return false;

    final now = DateTime.now();
    return now.difference(lastRequestTime) < throttleDur;
  }

  /// Force clear throttling for a key
  void clearThrottling(String key) {
    _lastRequestTimes.remove(key);
    _pendingRequests[key]?.cancel();
    _pendingRequests.remove(key);
  }

  /// Dispose and cleanup
  void dispose() {
    // Cancel all pending timers
    for (final timer in _pendingRequests.values) {
      timer.cancel();
    }

    // Complete all pending requests with error
    for (final completer in _pendingCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError('Service disposed');
      }
    }

    // Clear all data
    _pendingRequests.clear();
    _pendingCompleters.clear();
    _lastRequestTimes.clear();
    _resultCache.clear();
    _cacheTimestamps.clear();
  }
}
