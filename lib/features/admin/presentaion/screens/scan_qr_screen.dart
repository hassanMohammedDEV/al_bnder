import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../repositories/admin_repository_impl.dart';
import '../../../../core/helpers/error_helper.dart';

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _torch = false;
  bool _scanning = true;
  bool _retrying = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_scanning) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;

    _scanning = false;
    _lookup(raw);
  }

  Future<void> _lookup(String qrToken) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await ref.read(adminRepositoryProvider).getBookingByQrToken(qrToken);

    if (!mounted) return;
    Navigator.pop(context);

    result.when(
      success: (data) {
        final bookingId = data['booking_id'] as String?;
        if (bookingId != null) {
          context.push('/booking/$bookingId');
        }
      },
      failure: (e) => _showError(translateError(e)),
    );

    _scanning = true;
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(msg),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
        ],
      ),
    );
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await _controller.stop();
    await _controller.start();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسح QR')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 12),
                    const Text('تعذر الوصول إلى الكاميرا'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retrying ? null : _retry,
                      child: _retrying
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_scanning)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    _torch ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () {
                    _controller.toggleTorch();
                    setState(() => _torch = !_torch);
                  },
                ),
              ),
            ),
          if (!_scanning)
            Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
