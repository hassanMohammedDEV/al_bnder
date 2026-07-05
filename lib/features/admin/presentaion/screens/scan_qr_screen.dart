import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../repositories/admin_repository_impl.dart';
import '../../../../core/helpers/error_helper.dart';

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  late final MobileScannerController _controller;
  final _picker = ImagePicker();
  int _scannerKey = 0;
  bool _scanning = true;
  bool _torch = false;
  bool _cameraFailed = false;
  bool _analyzing = false;
  Map<String, dynamic>? _bookingData;
  String? _errorMsg;
  int _errorCount = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: false,
      cameraResolution: const Size(640, 480),
    );
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _startCamera());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    if (!mounted) return;
    try {
      await _controller.start();
      if (mounted) {
        _errorCount = 0;
        setState(() => _cameraFailed = false);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('QR Scanner start error: $e');
      final ec = _errorCount;
      if (ec < 3) {
        _errorCount = ec + 1;
        _retryTimer?.cancel();
        _retryTimer = Timer(Duration(seconds: ec == 0 ? 1 : 2), () {
          if (mounted) _startCamera();
        });
      } else {
        setState(() {
          _cameraFailed = true;
          _scanning = false;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_scanning) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _scanning = false;
    _lookup(raw);
  }

  Future<void> _pickAndAnalyze() async {
    if (_analyzing) return;
    setState(() {
      _analyzing = true;
      _errorMsg = null;
    });

    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xfile == null || !mounted) return;

      final result = await _controller.analyzeImage(xfile.path);
      if (!mounted) return;

      if (result != null && result.barcodes.isNotEmpty) {
        final token = result.barcodes.first.rawValue;
        if (token != null && token.isNotEmpty) {
          _lookup(token);
          return;
        }
      }
      setState(() => _errorMsg = 'لم يتم العثور على QR');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'فشل التحليل: $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _lookup(String qrToken) async {
    final result = await ref.read(adminRepositoryProvider).getBookingByQrToken(qrToken);
    if (!mounted) return;
    result.when(
      success: (data) => setState(() {
        _bookingData = data;
        _errorMsg = null;
        _scanning = false;
      }),
      failure: (e) => setState(() {
        _errorMsg = translateError(e);
        _bookingData = null;
      }),
    );
  }

  void _reset() {
    _retryTimer?.cancel();
    setState(() {
      _scannerKey++;
      _bookingData = null;
      _errorMsg = null;
      _scanning = true;
      _torch = false;
      _cameraFailed = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      _errorCount = 0;
      _startCamera();
    });
  }

  void _retry() {
    _retryTimer?.cancel();
    setState(() {
      _scannerKey++;
      _errorMsg = null;
      _scanning = true;
      _cameraFailed = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      _errorCount = 0;
      _startCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح QR'),
        actions: [
          if (_bookingData != null)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _reset,
              tooltip: 'مسح جديد',
            ),
        ],
      ),
      body: _bookingData != null
          ? _buildResult(scheme)
          : _cameraFailed ? _buildFallback(scheme) : _buildCamera(scheme),
    );
  }

  Widget _buildCamera(ColorScheme scheme) {
    return Stack(
      children: [
        MobileScanner(
          key: ValueKey(_scannerKey),
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: scheme.error),
                  const SizedBox(height: 12),
                  Text(error.errorCode.message,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 4),
                  if (error.errorDetails?.message != null)
                    Text('${error.errorDetails!.message}',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _retry,
                    child: const Text('إعادة المحاولة'),
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
        if (_errorMsg != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMsg!, style: TextStyle(color: scheme.error))),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallback(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner, size: 96, color: scheme.primary),
            const SizedBox(height: 24),
            Text('صور رمز QR من الشاشة',
              style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('التقط صورة لرمز QR الموجود على شاشة المستخدم',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _analyzing ? null : _pickAndAnalyze,
                icon: _analyzing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt, size: 28),
                label: Text(
                  _analyzing ? 'جاري التحليل...' : 'تصوير QR',
                  style: const TextStyle(fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMsg!,
                      style: TextStyle(color: scheme.error))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('إعادة محاولة الكاميرا المباشرة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ColorScheme scheme) {
    final b = _bookingData!;
    final startStr = _fmtTime(b['start_at'] as String);
    final endStr = _fmtTime(b['end_at'] as String);
    final totalPrice = (b['total_price'] as num?)?.toDouble() ?? 0;
    final paidAmount = (b['paid_amount'] as num?)?.toDouble() ?? 0;
    final status = b['status'] as String? ?? '';

    final statusColor = switch (status) {
      'confirmed' => Colors.green,
      'pending' => Colors.orange,
      'cancelled' => Colors.red,
      _ => Colors.grey,
    };

    final statusLabel = switch (status) {
      'confirmed' => 'مؤكد',
      'pending' => 'معلق',
      'cancelled' => 'ملغي',
      'completed' => 'منتهي',
      _ => status,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(statusLabel,
                style: TextStyle(fontWeight: FontWeight.w600, color: statusColor, fontSize: 13)),
            ),
            const Spacer(),
            Text('${totalPrice.toStringAsFixed(0)} ر.ي',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        _row('الملعب', b['facility_name'] as String? ?? ''),
        _row('المجموعة', b['group_name'] as String? ?? ''),
        _row('المستخدم', b['user_name'] as String? ?? ''),
        if ((b['user_phone'] as String? ?? '').isNotEmpty)
          _row('الجوال', b['user_phone'] as String),
        const SizedBox(height: 8),
        _row('التاريخ', _fmtDate(b['start_at'] as String)),
        _row('الوقت', '$startStr - $endStr'),
        const SizedBox(height: 8),
        if (paidAmount > 0)
          _row(paidAmount >= totalPrice ? 'مدفوع بالكامل' : 'عربون',
            '${paidAmount.toStringAsFixed(0)} ر.ي'),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('مسح جديد'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.start),
          ),
        ],
      ),
    );
  }

  String _fmtTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour;
    final m = dt.minute;
    final hour12 = h == 0 ? 12 : (h <= 12 ? h : h - 12);
    final period = h < 12 ? 'ص' : 'م';
    return '$hour12:${m.toString().padLeft(2, '0')} $period';
  }

  String _fmtDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('EEEE d MMMM y', 'ar').format(dt);
  }
}
