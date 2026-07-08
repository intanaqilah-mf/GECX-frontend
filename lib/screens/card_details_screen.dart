import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class CardDetailsScreen extends StatefulWidget {
  const CardDetailsScreen({super.key});

  @override
  State<CardDetailsScreen> createState() => _CardDetailsScreenState();
}

class _CardDetailsScreenState extends State<CardDetailsScreen> {
  bool _cvvVisible = false;
  bool _cardFrozen = false;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 1,
          automaticallyImplyLeading: false,
          title: Text('Card Details',
              style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary)),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
              onPressed: () {},
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildCardVisual(),
              const SizedBox(height: 16),
              _buildInfoCards(),
              const SizedBox(height: 16),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildTransactions(),
              const SizedBox(height: 24),
              _buildReportButton(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildCardVisual() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
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
            padding: const EdgeInsets.all(24),
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
                        Text('Premier Credit',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white60,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w500)),
                        Text('ACN Bank',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Icon(Icons.contactless, color: Colors.white60),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('•••• •••• •••• 8842',
                            style: GoogleFonts.robotoMono(
                                color: Colors.white, fontSize: 15, letterSpacing: 2)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EXPIRY',
                                style: GoogleFonts.inter(
                                    fontSize: 8, color: Colors.white38)),
                            Text('11/28',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CVV',
                                style: GoogleFonts.inter(
                                    fontSize: 8, color: Colors.white38)),
                            Row(
                              children: [
                                Text(_cvvVisible ? '412' : '•••',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _cvvVisible = !_cvvVisible),
                                  child: Icon(
                                    _cvvVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white54,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Alexander Newman',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                              color: Color(0xCCCC0000), shape: BoxShape.circle),
                        ),
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                                color: Color(0xCCFFAA00), shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Virtual Card Number',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('4532 8812 0943 8842',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined,
                      color: AppColors.secondary, size: 20),
                  onPressed: () {
                    Clipboard.setData(
                        const ClipboardData(text: '4532881209438842'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Card number copied')));
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Billing Address',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('128 Financial Plaza, NY',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ],
                  ),
                ),
                const Icon(Icons.location_on_outlined,
                    color: AppColors.outline, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionTile(
            icon: _cardFrozen ? Icons.lock_open_outlined : Icons.ac_unit_outlined,
            label: _cardFrozen ? 'Unfreeze' : 'Freeze',
            frozen: _cardFrozen,
            onTap: () {
              setState(() => _cardFrozen = !_cardFrozen);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_cardFrozen
                    ? 'Card frozen — no new transactions.'
                    : 'Card unfrozen.'),
              ));
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionTile(
              icon: Icons.pin_outlined, label: 'View PIN', onTap: () {}),
        ),
        const SizedBox(width: 8),
        Expanded(
          child:
              _actionTile(icon: Icons.tune, label: 'Limits', onTap: () {}),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    bool frozen = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: frozen
              ? AppColors.errorContainer.withValues(alpha: 0.4)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLowest, shape: BoxShape.circle),
              child: Icon(icon,
                  color: frozen ? AppColors.error : AppColors.primary, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: frozen ? AppColors.error : AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activity',
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
            TextButton(
              onPressed: () {},
              child: Text('View All',
                  style: GoogleFonts.inter(
                      color: AppColors.secondary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: [
              _txRow(Icons.shopping_bag_outlined, 'Apple Store Soho',
                  'Today, 2:45 PM', '-\$1,299.00'),
              const Divider(height: 1, color: AppColors.outlineVariant),
              _txRow(Icons.restaurant_outlined, 'The Grill House',
                  'Yesterday, 8:12 PM', '-\$84.50'),
              const Divider(height: 1, color: AppColors.outlineVariant),
              _txRow(Icons.local_taxi_outlined, 'Uber Trip',
                  'Yesterday, 6:00 PM', '-\$18.22'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _txRow(IconData icon, String title, String date, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                Text(date,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Text(amount,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildReportButton() {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.report_outlined, color: AppColors.error),
      label: Text('Report Lost or Stolen',
          style: GoogleFonts.inter(
              color: AppColors.error, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.errorContainer, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 0),
      ),
    );
  }
}

