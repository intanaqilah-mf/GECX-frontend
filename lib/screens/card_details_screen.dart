import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/banking_models.dart';
import '../services/api_service.dart';

class CardDetailsScreen extends StatefulWidget {
  final String customerId;
  const CardDetailsScreen({super.key, required this.customerId});

  @override
  State<CardDetailsScreen> createState() => _CardDetailsScreenState();
}

class _CardDetailsScreenState extends State<CardDetailsScreen> {
  final ApiService _apiService = ApiService();
  late Future<HomeData> _homeDataFuture;
  bool _cvvVisible = false;
  bool _cardFrozen = false;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _apiService.getHomeData(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
      future: _homeDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final card = snapshot.data?.latestCard;

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
            if (card == null)
              const SliverFillRemaining(
                child: Center(child: Text('No active card found')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildCardVisual(card),
                    const SizedBox(height: 16),
                    _buildInfoCards(card),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildTransactions(card.cardId),
                    const SizedBox(height: 24),
                    _buildReportButton(),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCardVisual(CardModel card) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: AspectRatio(
          aspectRatio: 1.58,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                  const Color(0xFF001b3d),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                        Text(card.cardType ?? 'Visa Platinum',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white60,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w500)),
                        const Text('ACN Bank',
                            style: TextStyle(
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
                    Text(card.cardNumber ?? '•••• •••• •••• 8842',
                        style: GoogleFonts.robotoMono(
                            color: Colors.white, fontSize: 18, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EXPIRY',
                                style: GoogleFonts.inter(
                                    fontSize: 8, color: Colors.white38)),
                            Text(card.expiryDate ?? '11/28',
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
                                Text(_cvvVisible ? (card.cvv == '•••' ? '412' : card.cvv) : '•••',
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
                    Text(card.cardHolderName ?? 'ALEXANDER NEWMAN',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
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
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCards(CardModel card) {
    double progress = (card.spendingLimit > 0) ? (card.spentAmount / card.spendingLimit) : 0.0;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Spending Limit',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  Text('\$${card.spentAmount.toStringAsFixed(0)} / \$${card.spendingLimit.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoBit('Remaining', '\$${(card.spendingLimit - card.spentAmount).toStringAsFixed(0)}'),
                  _infoBit('Next Billing', card.statementBillDate ?? 'Nov 24'),
                  _infoBit('Last Bill', '\$${card.lastStatementBalance.toStringAsFixed(2)}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
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
                          Text(card.cardNumber ?? '4532 8812 0943 8842',
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
                            ClipboardData(text: card.cardNumber?.replaceAll(' ', '') ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Card number copied')));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoBit(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.onSurfaceVariant, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
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

  Widget _buildTransactions(String cardId) {
    return FutureBuilder<List<ActivityModel>>(
      future: _apiService.getCardActivity(cardId),
      builder: (context, snapshot) {
        final activities = snapshot.data ?? [];

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
              child: activities.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: Text('No recent activity')),
                    )
                  : Column(
                      children: activities.asMap().entries.map((entry) {
                        final i = entry.key;
                        final a = entry.value;
                        return Column(
                          children: [
                            if (i > 0) const Divider(height: 1, color: AppColors.outlineVariant),
                            _txRow(
                              a.category == 'Shopping' ? Icons.shopping_bag_outlined : 
                              a.category == 'Dining' ? Icons.restaurant_outlined : Icons.local_taxi_outlined,
                              a.title,
                              a.date,
                              '-\$${a.amount.toStringAsFixed(2)}',
                            ),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
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
