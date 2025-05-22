import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/services/connectivity_service.dart';

/// Displays a colored banner at the top of the app when network is offline
class NetworkConnectionBanner extends StatelessWidget {
  final bool isOffline;
  final VoidCallback? onRetry;
  final bool compact;

  const NetworkConnectionBanner({
    Key? key,
    required this.isOffline,
    this.onRetry,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Material(
      elevation: 2,
      color: Colors.orange.shade700,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: compact ? 4.0 : 8.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              "You're offline",
              style: getSmallStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 16),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: getSmallStyle(fontWeight: FontWeight.w500),
                ),
                child: const Text("Check connection"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A ValueListenableBuilder wrapper for NetworkConnectionBanner that
/// listens to the ConnectivityService for network status changes
class NetworkAwareBanner extends StatelessWidget {
  final VoidCallback? onRetry;
  final bool compact;

  const NetworkAwareBanner({Key? key, this.onRetry, this.compact = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NetworkStatus>(
      valueListenable: ConnectivityService().statusNotifier,
      builder: (context, status, _) {
        return NetworkConnectionBanner(
          isOffline: status == NetworkStatus.offline,
          onRetry: onRetry,
          compact: compact,
        );
      },
    );
  }
}
