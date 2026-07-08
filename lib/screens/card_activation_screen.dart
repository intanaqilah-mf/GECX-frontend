import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import 'activation_success_screen.dart';

class CardActivationScreen extends StatefulWidget {
  final String cardId;
  const CardActivationScreen({super.key, required this.cardId});

  @override
  State<CardActivationScreen> createState() => _CardActivationScreenState();
}

class _CardActivationScreenState extends State<CardActivationScreen> {
  final ApiService _apiService = ApiService();
  bool _activating = false;

  Future<void> _handleActivate() async {
    setState(() => _activating = true);
    try {
      final result = await _apiService.activateCard(widget.cardId);
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ActivationSuccessScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Activation failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('ACN Bank',
            style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            child: Column(
              children: [
                _buildNotificationBanner(),
                const SizedBox(height: 32),
                _buildCardHero(),
                const SizedBox(height: 28),
                Text(
                  'Welcome!\nLet\'s activate your card.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      height: 1.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your virtual card is ready for Apple Wallet.\nPhysical card arriving in 3–5 business days.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 15, color: AppColors.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildBadge(Icons.security, 'Secure Activation'),
                    _buildBadge(Icons.account_balance_wallet_outlined, 'Apple Wallet Ready'),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withValues(alpha: 0),
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _activating ? null : _handleActivate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _activating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Activate Card Now',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600, fontSize: 15)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: Text('Maybe later',
                        style: GoogleFonts.inter(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ACN BANK',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    Text('now',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6))),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Your card is ready!',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                Text(
                  'Congratulations! Your new Visa Platinum is approved. Tap to activate.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHero() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AspectRatio(
              aspectRatio: 1.58,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF001b3d),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8))
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ACN Bank',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    letterSpacing: 1)),
                            Text('Platinum Privilege',
                                style: GoogleFonts.inter(
                                    color: Colors.white38, fontSize: 9, letterSpacing: 0.5)),
                          ],
                        ),
                        Container(
                          width: 44,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFD700),
                                Color(0xFFFFE866),
                                Color(0xFFFFAA00),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•••• •••• •••• 8842',
                            style: GoogleFonts.robotoMono(
                                color: Colors.white, fontSize: 15, letterSpacing: 3)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CARD HOLDER',
                                    style: GoogleFonts.inter(
                                        color: Colors.white38,
                                        fontSize: 8,
                                        letterSpacing: 0.5)),
                                Text('CARD HOLDER',
                                    style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const Icon(Icons.contactless,
                                color: Colors.white38, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -12,
              right: -12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)
                  ],
                ),
                child: const Icon(Icons.contactless,
                    color: AppColors.secondary, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
