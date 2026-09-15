import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../services/qr_payment_service.dart';
import '../theme/app_colors.dart';

/// Post-payment receipt for ACN QR Pay.
///
/// Layout mirrors the Maybank2u "Scan & Pay" successful screen from the
/// reference the user shared: bank-branded header band, "Successful" pill,
/// four data rows (Reference ID, Recipient Name, Recipient Account, Amount),
/// footer note, close chevron in the top-left.
class QrReceiptScreen extends StatelessWidget {
  final QrPaymentResult result;
  const QrReceiptScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM yyyy, h:mm a').format(result.timestamp);
    final amountStr = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    ).format(result.amount);
    final refShortTitle = 'ACN_${_yyyymmddhhmm(result.timestamp)}';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar — black band with reference title and close button. Uses
            // the same visual weight as the Maybank reference so the receipt
            // reads as a modal, not a routed page.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const SizedBox(width: 48), // balance the close button
                  Expanded(
                    child: Center(
                      child: Text(
                        refShortTitle,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _CircleIconButton(
                    icon: Icons.close,
                    onTap: () {
                      // Pop back to the scan screen. AppShell restores the
                      // camera on that tab in its didUpdateWidget hook.
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                ],
              ),
            ),

            // Receipt body
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _brandHeader(),
                    _statusBar(),
                    _row(
                      label: 'Reference ID',
                      value: result.referenceId,
                      trailing: dateStr,
                    ),
                    _row(
                      label: 'Recipient Name',
                      value: result.recipientName.toUpperCase(),
                    ),
                    _row(
                      label: 'Recipient ACN Bank ID',
                      value: result.recipientCustomerId,
                    ),
                    if (result.recipientAccountId != null)
                      _row(
                        label: 'Recipient Account',
                        value: _maskAccount(result.recipientAccountId!),
                      ),
                    _amountRow(amountStr),
                    _footerNote(),
                    _legalFooter(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom action bar — mirrors Maybank's [edit / search / share]
            // trio. Only wire what's obviously useful (share) so users don't
            // find dead buttons.
            _bottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget _brandHeader() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.account_balance,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            'ACN Bank',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBar() {
    return Container(
      color: const Color(0xFFF0F1F3),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Text(
            'Scan & Pay',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF7A),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Successful',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({required String label, required String value, String? trailing}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(value,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 12),
              child: Text(
                trailing,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _amountRow(String amountStr) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amount',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            '${result.currency} $amountStr',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerNote() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Text(
        'Note: This receipt is computer generated and no signature is required.',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _legalFooter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACN Bank · Powered by Accenture × Google GECX',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
                height: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Reference retained for 7 years for audit purposes.',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
                height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _bottomActions(BuildContext context) {
    // Only Share here — the edit / search icons in the Maybank reference
    // aren't wired to anything meaningful for the demo, and dead buttons
    // feel worse than a clean single action.
    return Container(
      color: const Color(0xFFF0F1F3),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _CircleIconButton(
            icon: Icons.ios_share,
            onTap: () => _share(context),
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final dateStr = DateFormat('d MMM yyyy, h:mm a').format(result.timestamp);
    final amountStr = NumberFormat.currency(symbol: '', decimalDigits: 2)
        .format(result.amount);

    // Plain-text receipt summary — copy-pasteable and shows fine in any share
    // target (WhatsApp, Mail, Notes, browser downloads on web).
    final body = [
      'ACN Bank — Scan & Pay Receipt',
      '',
      'Reference ID: ${result.referenceId}',
      'Date: $dateStr',
      'Recipient: ${result.recipientName}',
      'ACN Bank ID: ${result.recipientCustomerId}',
      if (result.recipientAccountId != null)
        'Account: ${_maskAccount(result.recipientAccountId!)}',
      'Amount: ${result.currency} $amountStr',
      '',
      'Status: Successful',
    ].join('\n');

    try {
      await Share.share(body, subject: 'ACN Bank receipt ${result.referenceId}');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open share sheet: $e')),
      );
    }
  }

  static String _maskAccount(String accountId) {
    // Show account type + last 4 (or last 4 of the id itself).
    final last4 = accountId.length > 4
        ? accountId.substring(accountId.length - 4)
        : accountId;
    return '**** $last4';
  }

  static String _yyyymmddhhmm(DateTime dt) {
    final s = dt;
    two(int n) => n.toString().padLeft(2, '0');
    return '${s.year}${two(s.month)}${two(s.day)}_${two(s.hour)}${two(s.minute)}';
  }
}

/// Round grey button used both for the close icon in the header and the
/// pill-grouped edit/search/share row at the bottom.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool pillLeft;
  final bool pillRight;
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.pillLeft = false,
    this.pillRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(pillLeft || (!pillLeft && !pillRight) ? 22 : 0),
      bottomLeft:
          Radius.circular(pillLeft || (!pillLeft && !pillRight) ? 22 : 0),
      topRight: Radius.circular(pillRight || (!pillLeft && !pillRight) ? 22 : 0),
      bottomRight:
          Radius.circular(pillRight || (!pillLeft && !pillRight) ? 22 : 0),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        width: 48,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade600,
          borderRadius: radius,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
