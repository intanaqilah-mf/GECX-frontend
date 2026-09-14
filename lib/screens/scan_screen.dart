import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zxing2/qrcode.dart' as zxing;

import '../services/chat_overlay_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/qr_pay_sheet.dart';
import 'my_qr_screen.dart';

/// Scan tab — real camera QR / barcode scanner on both native and web.
///
/// IMPORTANT: `AppShell` uses an `IndexedStack` which mounts every tab
/// eagerly, so if the camera controller were created at initState (before
/// the tab is visible) the browser would open a <video> element behind the
/// Home tab — producing "video already playing" errors and a grey overlay.
/// We fix that by only creating the controller once `isVisible` becomes
/// true, and starting/stopping it as the tab is shown/hidden.
class ScanScreen extends StatefulWidget {
  /// Signed-in customer id — needed so the "My QR" action can fetch the
  /// current user's details and render their receive-QR. Optional so the tab
  /// can still be rendered outside AppShell in previews / tests.
  final String? customerId;

  /// True when this tab is the currently selected tab in the bottom nav.
  /// AppShell flips this on tab changes so the camera stops when the user
  /// navigates away from Scan and resumes when they come back. Default true
  /// so previews / tests still see a working scanner.
  final bool isVisible;

  const ScanScreen({super.key, this.customerId, this.isVisible = true});

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
    // Lazy: only spin up the camera if the tab is actually visible right now.
    // Otherwise wait for AppShell to flip `isVisible` in didUpdateWidget.
    if (widget.isVisible) _ensureController();
  }

  @override
  void didUpdateWidget(covariant ScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      // Tab just became visible — spin up + start.
      _ensureController();
      _controller?.start();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      // Tab hidden — pause the camera but keep the controller around so we
      // start fast next time. On web that also releases the <video> element
      // frame pump.
      _controller?.stop();
    }
  }

  /// Creates the controller on first use. Called from initState + on the
  /// first visibility flip. Safe to call more than once — it's a no-op if
  /// the controller already exists.
  void _ensureController() {
    if (_controller != null) return;
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode, BarcodeFormat.ean13],
      detectionSpeed: DetectionSpeed.normal,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // Pause / resume the camera with the app lifecycle so we don't hold the
  // camera resource while backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (widget.isVisible) c.start();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        c.stop();
        break;
    }
  }

  /// Fire a chat utterance asking the CES agent for the customer's ACN QR
  /// Pay history. Web/Android both surface this through the persistent chat
  /// overlay — same pattern as the Home quick actions. The Daily Banking
  /// Accounts & Insights agent picks up the utterance and filters
  /// transactions to category="qr_transfer".
  void _openQrHistory() {
    final cid = widget.customerId;
    if (cid == null || cid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to view your QR history')),
      );
      return;
    }
    final chat = ChatOverlayController.instance;
    chat.open(cid);
    chat.pendingUtterance = 'Show my ACN QR Pay history';
  }

  /// Pick an image from the device gallery and scan it for QR codes.
  ///
  /// Uses `image` to decode the file bytes and `zxing2` (a pure-Dart port of
  /// Google ZXing) to detect the QR. We can't use mobile_scanner's
  /// `analyzeImage(path)` here because that's a native-only API — it throws
  /// "Unsupported operation" on Flutter web. zxing2 works uniformly on
  /// Android, iOS, and web, so we get one code path.
  ///
  /// The decoded string is routed through the same handlers as the live
  /// camera so an ACN QR envelope pops the payment sheet and a non-ACN QR
  /// falls into the generic bottom sheet.
  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return; // user cancelled

      // Pause live scanning while we analyze the still image so we don't
      // race a live QR detection against the gallery one.
      _controller?.stop();
      _handled = true;

      // Read the picked file (works cross-platform: on web `path` is a blob
      // URL and readAsBytes is the only portable way to get the bytes).
      final bytes = await picked.readAsBytes();
      final value = _decodeQrFromBytes(bytes);

      if (value == null || value.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR code found in that image')),
        );
        _handled = false;
        _controller?.start();
        return;
      }

      // Route through the same detection path as the live camera so the
      // ACN parser + generic bottom sheet behave identically.
      final acn = _tryParseAcnQr(value);
      if (acn != null) {
        _handleAcnQr(acn);
      } else {
        _showResult(value);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
      _handled = false;
      _controller?.start();
    }
  }

  /// Decode any QR code found in a still image's byte buffer. Returns the
  /// raw text of the first QR detected, or null if nothing decodes.
  ///
  /// Two failures shape the try/catch below: decodeImage returns null when
  /// the file isn't a supported image format, and zxing2 throws
  /// `NotFoundException` when no QR is present in the bitmap.
  String? _decodeQrFromBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // Build the ARGB int32 buffer zxing2 wants. Per-pixel loop is slow but
    // fine for the ~500x500 QRs we care about, and it's platform-portable
    // (no reliance on package:image's internal byte ordering, which differs
    // between v3 and v4).
    final w = decoded.width;
    final h = decoded.height;
    final pixels = Int32List(w * h);
    var i = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = decoded.getPixel(x, y);
        pixels[i++] = (0xFF << 24) |
            (p.r.toInt() << 16) |
            (p.g.toInt() << 8) |
            p.b.toInt();
      }
    }

    try {
      final source = zxing.RGBLuminanceSource(w, h, pixels);
      final bitmap = zxing.BinaryBitmap(zxing.HybridBinarizer(source));
      final reader = zxing.QRCodeReader();
      // zxing2's `decode` signature doesn't accept a hints Map here; call
      // the plain form. A clean QR PNG decodes fine without TRY_HARDER. If
      // we later want skew/low-contrast tolerance we can wire it via the
      // package's DecodeHints class.
      final result = reader.decode(bitmap);
      return result.text;
    } on zxing.NotFoundException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Open the receive-side "My QR" screen. Pauses the scanner while the QR
  /// route is on top and restarts it when we come back so we don't hold the
  /// camera in the background.
  Future<void> _openMyQr() async {
    final cid = widget.customerId;
    if (cid == null || cid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to view your QR')),
      );
      return;
    }
    _controller?.stop();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MyQrScreen(customerId: cid)),
    );
    if (!mounted) return;
    _handled = false;
    _controller?.start();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    _controller?.stop();

    // ACN_QR_PAY envelope? Route to the pay sheet. Anything else — merchant
    // QR, WiFi QR, arbitrary string — falls through to the generic result
    // sheet so the existing scan behaviour is untouched.
    final acn = _tryParseAcnQr(value);
    if (acn != null) {
      _handleAcnQr(acn);
    } else {
      _showResult(value);
    }
  }

  /// Decodes a base64(JSON) ACN QR envelope. Returns null if the payload
  /// isn't ours — invalid base64, invalid JSON, wrong `type`, missing
  /// `customer_id`, or a version we don't know how to render. Keep this
  /// tolerant: a scanner that trips on garbage would break every non-ACN
  /// QR the user points at.
  Map<String, dynamic>? _tryParseAcnQr(String raw) {
    try {
      final decoded = utf8.decode(base64Decode(raw));
      final obj = json.decode(decoded);
      if (obj is! Map) return null;
      if (obj['type'] != 'ACN_QR_PAY') return null;
      if (obj['v'] != '1') return null;
      final cid = obj['customer_id'];
      if (cid is! String || cid.isEmpty) return null;
      return Map<String, dynamic>.from(obj);
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleAcnQr(Map<String, dynamic> payload) async {
    final payer = widget.customerId;
    if (payer == null || payer.isEmpty) {
      // Shouldn't happen inside AppShell — but if we ever mount ScanScreen
      // pre-login, fall back to the raw display so we don't crash silently.
      _showResult(json.encode(payload));
      return;
    }
    // Guard against self-payment: don't let a user scan their own QR into a
    // payer flow. Bounce back to scanning with a hint.
    if (payload['customer_id'] == payer) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("That's your own QR")),
        );
      }
      _handled = false;
      _controller?.start();
      return;
    }

    final paid = await QrPaySheet.show(
      context,
      payload: payload,
      payerCustomerId: payer,
    );

    // Whether the user paid or dismissed, resume the camera so the tab keeps
    // working the second time they open it.
    if (!mounted) return;
    _handled = false;
    _controller?.start();

    // If they paid, the chat overlay is now expanded on top of us; nothing
    // else to do here — the overlay owns the receipt flow.
    if (paid == true) return;
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
      color: const Color(0xFF0B1F33),
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
                "Point your camera at a QR code to pay, or tap Gallery to "
                'scan an image from your device.',
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
                  _SmallAction(
                    icon: Icons.qr_code_2,
                    label: 'My QR',
                    onTap: _openMyQr,
                  ),
                  _SmallAction(
                    icon: Icons.image,
                    label: 'Gallery',
                    onTap: _pickFromGallery,
                  ),
                  _SmallAction(
                    icon: Icons.history,
                    label: 'History',
                    onTap: _openQrHistory,
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
          Row(
            children: [
              IconButton(
                onPressed: () => _controller?.switchCamera(),
                icon: const Icon(Icons.cameraswitch, color: Colors.white),
              ),
              // Torch is a native-only capability; browsers don't expose it
              // via getUserMedia. Hide on web to avoid a dead button.
              if (!kIsWeb)
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
          child: (_controller == null)
              // Controller not yet created — either the tab hasn't become
              // visible yet, or we're rendering the very first frame before
              // initState/didUpdateWidget wires it up. Show the placeholder.
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
