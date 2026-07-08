import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../models/banking_models.dart';

class StatementsScreen extends StatefulWidget {
  final String customerId;
  const StatementsScreen({super.key, required this.customerId});

  @override
  State<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends State<StatementsScreen> {
  final ApiService _apiService = ApiService();
  late Future<HomeData> _homeDataFuture;

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
        final cardId = snapshot.data?.latestCard?.cardId;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppColors.surface,
              elevation: 0,
              scrolledUnderElevation: 1,
              automaticallyImplyLeading: false,
              title: Text('Statements',
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                  onPressed: () {},
                ),
              ],
            ),
            if (cardId == null)
              const SliverFillRemaining(
                child: Center(child: Text('No active card for statements')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildCurrentStatement(),
                    const SizedBox(height: 24),
                    _buildHistory(cardId),
                    const SizedBox(height: 24),
                    _buildInquiries(context),
                    const SizedBox(height: 24),
                    _buildGreenBanner(),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCurrentStatement() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CURRENT AMOUNT DUE',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('\$1,452.80',
                  style: GoogleFonts.inter(
                      fontSize: 28, color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text('USD',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Due Date',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.white54)),
                    const SizedBox(height: 4),
                    Text('Oct 28, 2023',
                        style: GoogleFonts.inter(
                            fontSize: 17, color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Minimum Payment',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.white54)),
                    const SizedBox(height: 4),
                    Text('\$75.00',
                        style: GoogleFonts.inter(
                            fontSize: 17, color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: Text('Make a Payment',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(String cardId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _apiService.getStatements(cardId),
      builder: (context, snapshot) {
        final statements = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Statement History',
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
                TextButton(
                  onPressed: () {},
                  child: Text('Filter',
                      style: GoogleFonts.inter(
                          color: AppColors.secondary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: statements.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text('No statements available')),
                      )
                    : Column(
                        children: statements.asMap().entries.map((entry) {
                          final i = entry.key;
                          final m = entry.value;
                          return Column(
                            children: [
                              if (i > 0) const Divider(height: 1, color: AppColors.outlineVariant),
                              ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.description_outlined,
                                      color: AppColors.primary),
                                ),
                                title: Text(m['month'] ?? 'Unknown Month',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurface)),
                                subtitle: Text('Available ${m['available_date'] ?? 'N/A'}',
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: AppColors.onSurfaceVariant)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.download_outlined,
                                      color: AppColors.onSurfaceVariant),
                                  onPressed: () {},
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('View Older Statements',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInquiries(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    color: AppColors.secondaryContainer, shape: BoxShape.circle),
                child: const Icon(Icons.help_outline,
                    color: AppColors.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Billing Inquiries',
                        style: GoogleFonts.inter(
                            fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
                    const SizedBox(height: 4),
                    Text(
                      'Have questions about a transaction or your balance? Our team is available 24/7.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _faqTile('How do I dispute a charge?',
              "Select the specific transaction and tap 'Report a Problem' to begin the dispute process electronically."),
          const SizedBox(height: 8),
          _faqTile('When will my payment reflect?',
              'Payments via ACN internal transfer reflect instantly. External bank transfers may take 1–3 business days.'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: Text('Chat with Support',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text('Call Support',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerHigh,
                    foregroundColor: AppColors.onSurface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _faqTile(String question, String answer) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            title: Text(question,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(answer,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreenBanner() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            height: 160,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Center(
              child: Icon(Icons.eco_outlined, size: 64, color: AppColors.secondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Go Green, Get Rewards',
                    style: GoogleFonts.inter(
                        fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.primary)),
                const SizedBox(height: 8),
                Text(
                  'Switch to paperless statements and earn 500 loyalty points per month. Help us reduce our carbon footprint.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero, minimumSize: Size.zero),
                      child: Text('Enroll Now',
                          style: GoogleFonts.inter(
                              color: AppColors.secondary, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero, minimumSize: Size.zero),
                      child: Text('Learn More',
                          style: GoogleFonts.inter(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
