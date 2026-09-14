import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/banking_models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// "My QR" — the receive side of ACN QR Pay.
///
/// Renders a QR whose payload is base64(JSON) of:
///   { type: "ACN_QR_PAY", v: "1", customer_id, display_name }
///
/// The payer's scanner (see [ScanScreen]) detects `type == ACN_QR_PAY`,
/// parses this envelope, then routes into `QrPaySheet` for amount entry.
/// Non-ACN QRs continue to the generic bottom sheet unchanged.
class MyQrScreen extends StatefulWidget {
  final String customerId;
  const MyQrScreen({super.key, required this.customerId});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  final _api = ApiService();
  late Future<HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getHomeData(widget.customerId);
  }

  /// Build the base64(JSON) payload the scanner will decode. Keep this format
  /// in lockstep with `ScanScreen._tryParseAcnQr` — bump `v` on any breaking
  /// change so old scanners fall through to the generic path.
  String _buildQrPayload(CustomerProfile c) {
    final json = jsonEncode({
      'type': 'ACN_QR_PAY',
      'v': '1',
      'customer_id': c.customerId,
      'display_name': c.displayName,
    });
    return base64Encode(utf8.encode(json));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('My QR',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<HomeData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Couldn't load your QR. Try again shortly.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
              ),
            );
          }
          // qr_enabled: false → single opt-out switch for the receive side.
          // Show a friendly "off" state instead of a QR the payer's app would
          // still scan. Kept inline (not a separate screen) so toggling the
          // Firestore flag flips the UI on the next screen open with no
          // routing changes.
          if (snap.data!.customer.qrEnabled == false) {
            return _disabledBody();
          }
          return _body(snap.data!);
        },
      ),
    );
  }

  Widget _disabledBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, color: Colors.white38, size: 80),
            const SizedBox(height: 16),
            Text(
              'QR receiving is off',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Turn on ACN QR Pay in Settings to let others '
              'scan and pay you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(HomeData home) {
    final c = home.customer;
    final payload = _buildQrPayload(c);
    final accountRef = c.accountNumber ?? '—';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text('Scan to pay me',
                style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Recipient header — name + account, over the QR.
                      Text(c.displayName,
                          style: GoogleFonts.inter(
                              color: AppColors.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('ACN Bank • $accountRef',
                          style: GoogleFonts.inter(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 12)),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: payload,
                        version: QrVersions.auto,
                        size: 240,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.primary,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.primary,
                        ),
                        // Center brand chip — nothing security-critical, just
                        // demo polish.
                        embeddedImage: null,
                      ),
                      const SizedBox(height: 12),
                      Text('ACN QR Pay',
                          style: GoogleFonts.inter(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: payload));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('QR payload copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.copy_all, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Share/Download hook — not wired in the demo. Left as
                      // an ElevatedButton so the layout matches DuitNow QR.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Share is coming soon on the demo build'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
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
