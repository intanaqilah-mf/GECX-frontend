import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../models/banking_models.dart';

class PaymentsScreen extends StatefulWidget {
  final String customerId;
  const PaymentsScreen({super.key, required this.customerId});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _paymentsFuture;
  late Future<HomeData> _homeDataFuture;

  @override
  void initState() {
    super.initState();
    _paymentsFuture = _apiService.getPayments(widget.customerId);
    _homeDataFuture = _apiService.getHomeData(widget.customerId);
  }

  static const _contacts = [
    ('Sarah J.', Color(0xFF6B9BD2)),
    ('Michael K.', Color(0xFF5B8DB8)),
    ('Elena R.', Color(0xFF7A9EC5)),
    ('David L.', Color(0xFF4A7BA8)),
    ('Sophia M.', Color(0xFF8AAFD4)),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_paymentsFuture, _homeDataFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final scheduled = (snapshot.data?[0] as List<Map<String, dynamic>>?) ?? [];
        final homeData = snapshot.data?[1] as HomeData?;
        final cardId = homeData?.latestCard?.cardId;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppColors.surface,
              elevation: 0,
              scrolledUnderElevation: 1,
              automaticallyImplyLeading: false,
              title: Text('Payments',
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary)),
              actions: [
                IconButton(
                    icon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
                    onPressed: () {}),
                IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: AppColors.onSurfaceVariant),
                    onPressed: () {}),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildCurrentStatement(),
                  const SizedBox(height: 24),
                  _buildQuickSend(),
                  const SizedBox(height: 32),
                  _buildMoveMoney(),
                  const SizedBox(height: 32),
                  _buildScheduled(context, scheduled),
                  if (cardId != null) ...[
                    const SizedBox(height: 32),
                    _buildHistory(cardId),
                  ],
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

  Widget _buildQuickSend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Send',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
            TextButton(
              onPressed: () {},
              child: Text('View All',
                  style: GoogleFonts.inter(
                      color: AppColors.secondary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _contactAvatar(null, 'Add New', isAddButton: true),
              ..._contacts.map((c) => _contactAvatar(c.$2, c.$1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactAvatar(Color? color, String name, {bool isAddButton = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          isAddButton
              ? Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outlineVariant, width: 2),
                  ),
                  child: const Icon(Icons.add, color: AppColors.secondary),
                )
              : CircleAvatar(
                  radius: 30,
                  backgroundColor: color,
                  child: Text(
                    name.split(' ').map((w) => w[0]).join(),
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                ),
          const SizedBox(height: 6),
          Text(name,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildMoveMoney() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Move Money',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _moneyCard(Icons.swap_horiz, 'Between Accounts',
                  'Transfer funds instantly within ACN Bank.'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _moneyCard(Icons.person_add_outlined, 'Send to Someone',
                  'Move money to any bank or external contact.'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _moneyCard(Icons.receipt_long_outlined, 'Pay a Bill',
            'Settle utility, credit card, or service bills.',
            fullWidth: true),
      ],
    );
  }

  Widget _moneyCard(IconData icon, String title, String description,
      {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.onSecondaryContainer, size: 22),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          const SizedBox(height: 4),
          Text(description,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildScheduled(BuildContext context, List<Map<String, dynamic>> scheduled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Scheduled Payments',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface)),
            IconButton(
              icon: const Icon(Icons.filter_list, color: AppColors.onSurfaceVariant),
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: scheduled.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: Text('No scheduled payments')),
                    )
                  ]
                : scheduled.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    return Column(
                      children: [
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.outlineVariant),
                        _scheduledRow(
                          Icons.payment,
                          s['recipient_name'] ?? 'Recipient',
                          'Due ${s['due_date'] ?? 'N/A'}',
                          '-\$${s['amount'] ?? '0.00'}',
                          s['is_autopay'] ?? false,
                        ),
                      ],
                    );
                  }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: Text('Schedule New Payment',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scheduledRow(
      IconData icon, String title, String date, String amount, bool autoPay) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.secondary, size: 20),
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
                        color: AppColors.onSurface)),
                Text(date,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface)),
              Text(
                autoPay ? 'Auto-pay' : 'One-time',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: autoPay ? AppColors.secondary : AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
