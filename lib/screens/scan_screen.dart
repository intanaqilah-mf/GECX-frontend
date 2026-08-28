import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Scan tab — QR pay stub.
///
/// The CES agent does NOT expose a QR / scan-to-pay flow today (verified in
/// ACN_Bank_Demo agent instructions — grep for "QR" and "scan" returns zero
/// hits). This screen renders a coming-soon placeholder with the visual
/// scaffolding a real scanner would need (viewfinder + torch stub) so it's
/// easy to drop in `mobile_scanner` later without touching the shell.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF140025),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Scan & Pay',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.flash_off, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _ViewfinderFrame(),
            const SizedBox(height: 32),
            Text(
              'QR pay coming soon',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Point your camera at a merchant's QR code to pay directly "
                'from your ACN card.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SmallAction(icon: Icons.qr_code_2, label: 'My QR'),
                  _SmallAction(icon: Icons.image, label: 'Gallery'),
                  _SmallAction(icon: Icons.history, label: 'History'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary, width: 2),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: const Center(
        child: Icon(Icons.qr_code_scanner, color: Colors.white38, size: 96),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SmallAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}
