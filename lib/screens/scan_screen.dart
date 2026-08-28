import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';

/// Scan tab — real camera QR / barcode scanner on native, coming-soon
/// placeholder on Flutter web.
///
/// IMPORTANT: `MobileScannerController` MUST NOT be instantiated on web.
/// `AppShell` uses IndexedStack which mounts every tab eagerly, so a
/// controller created at field-init time would spin up a <video> element
/// the moment Home first renders — producing "video already playing" spam
/// and a grey full-viewport overlay from the empty stream. That's what
/// caused the grey-out crash you saw.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _torch = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Only touch mobile_scanner on native platforms.
    if (!kIsWeb) {
      _controller = MobileScannerController(
        formats: const [BarcodeFormat.qrCode, BarcodeFormat.ean13],
        detectionSpeed: DetectionSpeed.normal,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // Pause / resume the camera with the app lifecycle so we don't hold the
  // camera resource while backgrounded. Web has no controller — skip.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        c.start();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        c.stop();
        break;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    _controller?.stop();
    _showResult(value);
  }

  void _showResult(String value) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QR detected',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface)),
            const SizedBox(height: 8),
            SelectableText(value,
                style: GoogleFonts.robotoMono(fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handled = false;
                      _controller?.start();
                    },
                    child: const Text('Scan again'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handled = false;
                      _controller?.start();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Pay'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF140025),
      child: SafeArea(
        child: Column(
          children: [
            _topBar(),
            const SizedBox(height: 8),
            Expanded(child: _viewfinder()),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                kIsWeb
                    ? 'Live QR scanning is available on the mobile app. '
                        'Open the ACN Bank app on your phone to try it.'
                    : "Point your camera at a merchant's QR code to pay "
                        'from your ACN card.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.white70, fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SmallAction(icon: Icons.qr_code_2, label: 'My QR', onTap: () {}),
                  _SmallAction(
                    icon: Icons.image,
                    label: 'Gallery',
                    onTap: () {},
                  ),
                  _SmallAction(
                    icon: Icons.history,
                    label: 'History',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Scan & Pay',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          if (!kIsWeb)
            Row(
              children: [
                IconButton(
                  onPressed: () => _controller?.switchCamera(),
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                ),
                IconButton(
                  onPressed: () async {
                    await _controller?.toggleTorch();
                    if (mounted) setState(() => _torch = !_torch);
                  },
                  icon: Icon(_torch ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _viewfinder() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary, width: 2),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: (kIsWeb || _controller == null)
              // No mobile_scanner on web — render the visual placeholder.
              // On native, this branch also runs briefly during first-frame
              // before initState finishes, then _controller becomes non-null.
              ? const Center(
                  child: Icon(Icons.qr_code_scanner,
                      color: Colors.white38, size: 96),
                )
              : MobileScanner(
                  controller: _controller!,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Camera unavailable: ${error.errorCode.name}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 11.5)),
        ],
      ),
    );
  }
}
