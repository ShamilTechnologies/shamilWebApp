/// File: lib/core/services/sound_service.dart
/// Robust sound service with Windows compatibility and fallback mechanisms
library;

import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

/// Sound service that handles audio playback with robust error handling
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _soundEnabled = true;

  /// Initialize the sound service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Test audio capability
      await _testAudioCapability();
      _isInitialized = true;
      print('SoundService: Initialized successfully');
    } catch (e) {
      print('SoundService: Initialization failed, disabling sound: $e');
      _soundEnabled = false;
      _isInitialized = true;
    }
  }

  /// Test if audio playback is working
  Future<void> _testAudioCapability() async {
    try {
      // Try to play a very short silent audio to test capability
      if (Platform.isWindows) {
        // On Windows, test with a simple beep
        await _playSystemBeep();
      }
    } catch (e) {
      throw Exception('Audio capability test failed: $e');
    }
  }

  /// Play access granted sound
  Future<void> playAccessGranted() async {
    if (!_soundEnabled) {
      await _fallbackHaptic();
      return;
    }

    try {
      await _playSound('granted');
    } catch (e) {
      print('SoundService: Failed to play granted sound: $e');
      await _fallbackHaptic();
    }
  }

  /// Play access denied sound
  Future<void> playAccessDenied() async {
    if (!_soundEnabled) {
      await _fallbackHaptic();
      return;
    }

    try {
      await _playSound('denied');
    } catch (e) {
      print('SoundService: Failed to play denied sound: $e');
      await _fallbackHaptic();
    }
  }

  /// Play error sound
  Future<void> playError() async {
    if (!_soundEnabled) {
      await _fallbackHaptic();
      return;
    }

    try {
      await _playSound('error');
    } catch (e) {
      print('SoundService: Failed to play error sound: $e');
      await _fallbackHaptic();
    }
  }

  /// Internal method to play sounds with multiple format fallbacks
  Future<void> _playSound(String soundName) async {
    final formats = ['wav', 'mp3', 'ogg'];

    for (final format in formats) {
      try {
        final assetPath = 'sounds/$soundName.$format';
        print('SoundService: Attempting to play $assetPath');

        await _audioPlayer.play(AssetSource(assetPath));
        print('SoundService: Successfully played $assetPath');
        return;
      } catch (e) {
        print('SoundService: Failed to play $soundName.$format: $e');
        continue;
      }
    }

    // If all formats fail, try system sounds
    await _playSystemSound(soundName);
  }

  /// Play system sounds as fallback
  Future<void> _playSystemSound(String soundName) async {
    try {
      if (Platform.isWindows) {
        switch (soundName) {
          case 'granted':
            await _playSystemBeep(frequency: 800, duration: 200);
            break;
          case 'denied':
            await _playSystemBeep(frequency: 400, duration: 500);
            break;
          case 'error':
            await _playSystemBeep(frequency: 200, duration: 300);
            break;
        }
      } else {
        // For other platforms, use haptic feedback
        await _fallbackHaptic();
      }
    } catch (e) {
      print('SoundService: System sound fallback failed: $e');
      await _fallbackHaptic();
    }
  }

  /// Play system beep (Windows)
  Future<void> _playSystemBeep({
    int frequency = 800,
    int duration = 200,
  }) async {
    try {
      if (Platform.isWindows) {
        // Use Windows API to play beep
        await Process.run('powershell', [
          '-Command',
          '[console]::beep($frequency, $duration)',
        ]);
      }
    } catch (e) {
      print('SoundService: System beep failed: $e');
      throw e;
    }
  }

  /// Fallback to haptic feedback
  Future<void> _fallbackHaptic() async {
    try {
      await HapticFeedback.mediumImpact();
      print('SoundService: Using haptic feedback fallback');
    } catch (e) {
      print('SoundService: Haptic feedback also failed: $e');
    }
  }

  /// Enable or disable sound
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    print('SoundService: Sound ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if sound is enabled
  bool get isSoundEnabled => _soundEnabled;

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}
