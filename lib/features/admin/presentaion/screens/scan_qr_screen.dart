import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  MobileScannerController? _controller;
  bool _resolved = false;
  bool _torch = false;
  Map<String, dynamic>? _bookingData;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _resolved = true;
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_resolved) return;
    final barcodes = capture.barcodes;
    for (final b in barcodes) {
      final raw = b.rawValue;
      if (raw == null || raw.isEmpty) continue;
      _resolved = true;
      _lookup(raw);
      return;
    }
  }

  Future<void> _lookup(String qrToken) async {
    final result = await ref.read(adminRepositoryProvider).getBookingByQrToken(qrToken);
    if (!mounted) return;
    result.when(
      success: (data) => setState(() {
        _bookingData = data;
        _errorMsg = null;
      }),
      failure: (e) => setState(() {
        _errorMsg = translateError(e);
        _bookingData = null;
      }),
    );
  }

  void _reset() {
    _controller?.stop();
    setState(() {
      _bookingData = null;
      _errorMsg = null;
      _resolved = false;
      _torch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
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
      body: _bookingData != null ? _buildResult(scheme) : _buildCamera(scheme),
    );
  }

  Widget _buildCamera(ColorScheme scheme) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Text(
            'وجه الكاميرا نحو رمز QR',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ),
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
                _controller?.toggleTorch();
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

    return Container(
      color: scheme.surface,
      child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
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
          if (b['created_at'] != null) ...[
            _row('تم الإنشاء', '${_fmtDate(b['created_at'] as String)} - ${_fmtTime(b['created_at'] as String)}'),
            const SizedBox(height: 8),
          ],
          if (paidAmount > 0) ...[
            _row('المدفوع', '${paidAmount.toStringAsFixed(0)} ر.ي'),
            if (paidAmount < totalPrice)
              _row('المتبقي', '${(totalPrice - paidAmount).toStringAsFixed(0)} ر.ي'),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('مسح جديد'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
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
