import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/qr_receipt_screen.dart';
import '../services/qr_payment_service.dart';
import '../theme/app_colors.dart';

/// The payer-side sheet that appears after a valid ACN QR is scanned.
///
/// Shows the recipient (parsed from the QR envelope), lets the user tap an
/// amount on a Maybank-style numpad, then submits the payment directly via
/// [QrPaymentService] and pushes [QrReceiptScreen] on success — no chat
/// overlay. The CES agent's QR pay flow still works if the user types the
/// utterance manually into chat; this sheet is the native-app fast path.
class QrPaySheet extends StatefulWidget {
  /// Decoded ACN_QR_PAY envelope — see [MyQrScreen] for the writer side.
  /// Required keys: `customer_id`, `display_name`. Extra keys are ignored.
  final Map<String, dynamic> payload;

  /// Signed-in payer's customer id. Needed only to (re-)open the chat overlay
  /// with the right session id before we push the pending utterance.
  final String payerCustomerId;

  const QrPaySheet({
    super.key,
    required this.payload,
    required this.payerCustomerId,
  });

  /// Convenience — the standard modal presentation. Rounded top corners,
  /// full-width, dismissible. Returns true if the user hit "Pay Now" (so the
  /// scanner can stay stopped), false / null if they dismissed.
  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> payload,
    required String payerCustomerId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QrPaySheet(
        payload: payload,
        payerCustomerId: payerCustomerId,
      ),
    );
  }

  @override
  State<QrPaySheet> createState() => _QrPaySheetState();
}

class _QrPaySheetState extends State<QrPaySheet> {
  /// Amount as raw cents (no decimal parsing headaches). Numpad taps append a
  /// digit worth 1¢ at the far right and shift everything up by 10× — this is
  /// how ATMs / DuitNow do it and it's the natural feel on a bank numpad.
  int _cents = 0;

  /// True while [QrPaymentService.submit] is running. Disables the numpad +
  /// Pay Now button and shows a spinner in place of the button label.
  bool _submitting = false;

  String get _recipientId => (widget.payload['customer_id'] ?? '') as String;
  String get _recipientName =>
      (widget.payload['display_name'] ?? 'Recipient') as String;

  String get _formattedAmount {
    final dollars = _cents ~/ 100;
    final rem = (_cents % 100).toString().padLeft(2, '0');
    // Simple thousand-separators, no `intl` dep needed for cents-level math.
    final withCommas = dollars.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$withCommas.$rem';
  }

  void _tapDigit(int d) {
    if (_submitting) return;
    setState(() {
      // Cap at $999,999.99 so the display can't blow out of the sheet.
      final next = _cents * 10 + d;
      if (next > 99999999) return;
      _cents = next;
    });
  }

  void _backspace() {
    if (_submitting) return;
    setState(() => _cents = _cents ~/ 10);
  }

  /// Submit via [QrPaymentService] (client-side Firestore writes) and push
  /// [QrReceiptScreen] on success. No chat overlay — the receipt is native.
  Future<void> _payNow() async {
    if (_cents <= 0 || _submitting) return;
    setState(() => _submitting = true);

    final amount = _cents / 100.0;
    try {
      final result = await QrPaymentService.instance.submit(
        senderCustomerId: widget.payerCustomerId,
        recipientCustomerId: _recipientId,
        recipientDisplayName: _recipientName,
        amount: amount,
        currency: 'CAD',
      );
      if (!mounted) return;
      // Close the sheet, then push the receipt as a full route. Using
      // pushReplacement isn't right here — sheet lives above ScanScreen and
      // popping it returns us to Scan; then we push the receipt on top of
      // Scan so the close button on the receipt lands us back on the shell.
      Navigator.of(context).pop(true);
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => QrReceiptScreen(result: result)),
      );
    } on QrPaymentException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canPay = _cents > 0 && !_submitting;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Drag handle.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _recipientHeader(),
            const SizedBox(height: 20),
            _amountDisplay(),
            const SizedBox(height: 12),
            _numpad(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canPay ? _payNow : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Pay Now'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipientHeader() {
    final initials = _recipientName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: GoogleFonts.inter(
                color: AppColors.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paying', style: _muted()),
                const SizedBox(height: 2),
                Text(
                  _recipientName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(_recipientId, style: _muted()),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ACN QR',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountDisplay() {
    return Column(
      children: [
        Text('CAD', style: _muted()),
        const SizedBox(height: 2),
        Text(
          '\$$_formattedAmount',
          style: GoogleFonts.inter(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _numpad() {
    // 4×3 grid: 1..9, backspace / 0 / <-. Using a plain Table for even sizing.
    Widget key(String label, VoidCallback? onTap, {IconData? icon}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 56,
          child: Center(
            child: icon != null
                ? Icon(icon, color: AppColors.onSurface, size: 22)
                : Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
          ),
        ),
      );
    }

    Widget row(List<Widget> children) => Row(
          children: [
            for (final c in children) Expanded(child: c),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          row([
            for (final d in [1, 2, 3])
              key('$d', () => _tapDigit(d)),
          ]),
          row([
            for (final d in [4, 5, 6])
              key('$d', () => _tapDigit(d)),
          ]),
          row([
            for (final d in [7, 8, 9])
              key('$d', () => _tapDigit(d)),
          ]),
          row([
            const SizedBox.shrink(),
            key('0', () => _tapDigit(0)),
            key('', _cents > 0 ? _backspace : null,
                icon: Icons.backspace_outlined),
          ]),
        ],
      ),
    );
  }

  TextStyle _muted() => GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      );
}
