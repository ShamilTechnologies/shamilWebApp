import 'package:flutter/material.dart';

/// Enterprise action buttons for the access control screen
/// This component provides the floating action buttons for access control operations
class EnterpriseActionButtons extends StatelessWidget {
  final bool isScanning;
  final Animation<double> scanAnimation;
  final VoidCallback onScanPressed;
  final VoidCallback onManualEntryPressed;

  const EnterpriseActionButtons({
    super.key,
    required this.isScanning,
    required this.scanAnimation,
    required this.onScanPressed,
    required this.onManualEntryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Manual entry FAB
        FloatingActionButton(
          heroTag: 'manual_entry',
          onPressed: onManualEntryPressed,
          backgroundColor: Colors.indigo.shade600,
          elevation: 8,
          child: const Icon(Icons.keyboard_rounded, color: Colors.white),
        ),
        const SizedBox(height: 16),
        // Main access scanner FAB
        FloatingActionButton.extended(
          heroTag: 'scan_access',
          onPressed: isScanning ? null : onScanPressed,
          backgroundColor: Colors.blue.shade600,
          elevation: 8,
          icon: AnimatedBuilder(
            animation: scanAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: isScanning ? scanAnimation.value * 2 * 3.14159 : 0,
                child: Icon(
                  isScanning
                      ? Icons.qr_code_scanner_rounded
                      : Icons.security_rounded,
                  color: Colors.white,
                ),
              );
            },
          ),
          label: Text(
            isScanning ? 'Scanning...' : 'Enterprise Access',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
