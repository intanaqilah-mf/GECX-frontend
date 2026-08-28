import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

/// Hosted Travel Store — opens in the system browser (or a new tab on web)
/// with the freshly-activated cardId so the store can call the gateway's
/// purchase endpoints against that card.
const String _travelStoreBaseUrl = 'https://acn-travel-store-483471568825.web.app';

class ActivationSuccessScreen extends StatefulWidget {
  /// Card that was just activated. Forwarded to the Travel Store as a query
  /// param so the store's first-purchase flow is scoped to this card.
  final String? cardId;

  const ActivationSuccessScreen({super.key, this.cardId});

  @override
  State<ActivationSuccessScreen> createState() => _ActivationSuccessScreenState();
}

class _ActivationSuccessScreenState extends State<ActivationSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Hands off to the hosted Travel Store with the activated card's id so the
  /// store can quote/purchase against it via the platform gateway. Uses
  /// platformDefault so on web it becomes a normal tab navigation and on
  /// mobile it opens the system browser — no in-app WebView chrome to fight.
  Future<void> _openTravelStore() async {
    final cardId = widget.cardId;
    if (cardId == null || cardId.isEmpty) {
      // Defensive: without a cardId the store can't scope the purchase.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card ID unavailable — please try again from Cards.')),
      );
      return;
    }

    final uri = Uri.parse(_travelStoreBaseUrl).replace(
      queryParameters: {'card_id': cardId},
    );

    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Travel Store: $uri')),
      );
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
          icon: const Icon(Icons.menu, color: AppColors.primary),
          onPressed: () {},
        ),
        title: Text('ACN Bank',
            style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                onPressed: () {},
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.error, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        child: Column(
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.secondary, size: 48),
              ),
            ),
            const SizedBox(height: 20),
            Text('Card Activated!',
                style: GoogleFonts.inter(
                    fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 8),
            Text(
              'Your ACN Visa Platinum is now active and ready for use.\nYour physical card is on its way.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 32),
            _buildCardVisual(),
            const SizedBox(height: 16),
            _buildSummaryRow(),
            const SizedBox(height: 24),
            _buildWalletButtons(),
            const SizedBox(height: 32),
            // ── Journey close-out: nudge the customer into their first
            //    purchase in the Travel Store instead of dropping them back
            //    on the dashboard. Rendered as the top CTA so it wins
            //    attention over the dashboard/wallet fallbacks.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _openTravelStore,
                icon: const Icon(Icons.flight_takeoff, size: 18),
                label: Text('Explore Travel Store',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Earn travel points on your first purchase.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: const StadiumBorder(),
                ),
                child: Text('Go to Dashboard',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildCardVisual() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: AspectRatio(
        aspectRatio: 1.58,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
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
                      Text('Visa Platinum',
                          style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 11,
                              letterSpacing: 1.5)),
                      Text('ACN Bank',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)),
                    ],
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.contactless, color: Colors.white38),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•••• •••• •••• 4289',
                      style: GoogleFonts.robotoMono(
                          color: Colors.white, fontSize: 17, letterSpacing: 2)),
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
                          Text('ALEXANDER NEWMAN',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Text('VISA',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              fontSize: 18,
                              letterSpacing: 2)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text('CARD ENDS IN',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('...4289',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ],
          ),
          Container(width: 1, height: 36, color: AppColors.outlineVariant),
          Column(
            children: [
              Text('CREDIT LIMIT',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('\$10,000',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.wallet, size: 18),
            label: Text('Apple Wallet',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.g_mobiledata, color: AppColors.secondary, size: 24),
            label: Text('Google Pay',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.onSurface)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.outlineVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home, 'Home', true),
            _navItem(Icons.payments_outlined, 'Payments', false),
            _navItem(Icons.credit_card_outlined, 'Cards', false),
            _navItem(Icons.contact_support_outlined, 'Support', false),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    return Container(
      decoration: active
          ? BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(100))
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: active ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
              size: 22),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: active
                      ? AppColors.onSecondaryContainer
                      : AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

