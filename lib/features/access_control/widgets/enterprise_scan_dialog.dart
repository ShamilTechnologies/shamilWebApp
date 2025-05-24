import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Enterprise-level scan dialog for access control
/// This is used to scan QR codes, enter credentials, or scan NFC
class EnterpriseScanDialog extends StatelessWidget {
  final bool isScanning;
  final Animation<double> scanAnimation;
  final List<dynamic>? connectedDevices;
  final Function(String) onSubmit;
  final VoidCallback onCancel;

  const EnterpriseScanDialog({
    super.key,
    required this.isScanning,
    required this.scanAnimation,
    this.connectedDevices,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.indigo.shade50],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated scanner icon
            AnimatedBuilder(
              animation: scanAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: scanAnimation.value * 2 * math.pi,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.indigo.shade600],
                      ),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Enterprise Access Scanner',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Validate enterprise user credentials with advanced authorization',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'User ID / Employee ID / Card ID',
                hintText: 'Enter credentials or use hardware scanner',
                prefixIcon: const Icon(Icons.badge_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              autofocus: true,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  onSubmit(value.trim());
                }
              },
            ),
            const SizedBox(height: 16),
            // Device status
            if (connectedDevices != null && connectedDevices!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.devices_rounded,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${connectedDevices!.length} enterprise device(s) active',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onCancel();
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final userId = controller.text.trim();
                      if (userId.isNotEmpty) {
                        Navigator.of(context).pop();
                        onSubmit(userId);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Validate Access'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
