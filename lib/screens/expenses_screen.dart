import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intl/intl.dart';

import '../models/banking_models.dart';
import '../services/api_service.dart';
import '../services/loans_service.dart';
import '../services/quick_actions.dart';
import '../theme/app_colors.dart';

/// Expenses tab — client-side aggregation of `getCardActivity` into category
/// buckets. CES does NOT have a spending-insights flow (only mini-statement +
/// pre-approved offers), so this view lives entirely in the app for now.
class ExpensesScreen extends StatefulWidget {
  final String customerId;
  const ExpensesScreen({super.key, required this.customerId});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _api = ApiService();
  Future<_ExpensesState>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ExpensesState> _load() async {
    final home = await _api.getHomeData(widget.customerId);
    final cardId = home.latestCard?.cardId;
    if (cardId == null || cardId.isEmpty) {
      return _ExpensesState.empty();
    }
    final acts = await _api.getCardActivity(cardId);
    return _ExpensesState.from(acts);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => setState(() => _future = _load()),
        child: FutureBuilder<_ExpensesState>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            final state = snap.data ?? _ExpensesState.empty();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text('Expenses',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface)),
                const SizedBox(height: 4),
                Text('This month',
                    style: GoogleFonts.inter(
                        color: AppColors.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 20),
                _totalCard(state),
                const SizedBox(height: 20),
                _ActiveFinancingSection(customerId: widget.customerId),
                const SizedBox(height: 20),
                _byCategoryCard(state),
                const SizedBox(height: 20),
                _insightCta(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _totalCard(_ExpensesState s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF002147), Color(0xFF0056B3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total spend',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text('CAD ${s.total.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('${s.count} transactions',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _byCategoryCard(_ExpensesState s) {
    if (s.byCategory.isEmpty) {
      return _empty('No spending yet this period.');
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By category',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
          const SizedBox(height: 12),
          ...s.byCategory.entries.map((e) => _row(e.key, e.value, s.total)),
        ],
      ),
    );
  }

  Widget _row(String category, double amount, double total) {
    final pct = total == 0 ? 0.0 : amount / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_prettyCategory(category),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface)),
              const Spacer(),
              Text('CAD ${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.secondaryContainer,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCta() {
    return InkWell(
      onTap: () => runQuickAction(
        const QuickAction(
          label: 'Insights',
          utterance: 'Give me a spending insight',
          icon: Icons.insights,
        ),
        widget.customerId,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.smart_toy, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask the AI for a spending tip',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  Text('Get one takeaway based on this month.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _empty(String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: GoogleFonts.inter(
                        color: AppColors.onSurfaceVariant, fontSize: 13))),
          ],
        ),
      );

  String _prettyCategory(String raw) {
    if (raw.isEmpty) return 'Other';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1)))
        .join(' ');
  }
}

class _ExpensesState {
  final double total;
  final int count;
  final Map<String, double> byCategory;
  _ExpensesState({
    required this.total,
    required this.count,
    required this.byCategory,
  });

  factory _ExpensesState.empty() =>
      _ExpensesState(total: 0, count: 0, byCategory: {});

  factory _ExpensesState.from(List<ActivityModel> acts) {
    // Only debits count as "spend" — inbound credits are excluded from the
    // total and category breakdown so refunds don't distort the donut.
    double total = 0;
    final buckets = <String, double>{};
    for (final a in acts) {
      if (a.amount >= 0) continue;
      final v = a.amount.abs();
      total += v;
      buckets.update(a.category.isEmpty ? 'other' : a.category,
          (existing) => existing + v,
          ifAbsent: () => v);
    }
    // Sort by descending amount.
    final sorted = Map.fromEntries(buckets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)));
    return _ExpensesState(total: total, count: acts.length, byCategory: sorted);
  }
}


/// Active Financing — EPP + mortgage rows with quick pay actions.
/// Sits on the Expenses tab so the customer sees monthly commitments alongside
/// their spending.
class _ActiveFinancingSection extends StatefulWidget {
  final String customerId;
  const _ActiveFinancingSection({required this.customerId});

  @override
  State<_ActiveFinancingSection> createState() => _ActiveFinancingSectionState();
}

class _ActiveFinancingSectionState extends State<_ActiveFinancingSection> {
  final _cad = NumberFormat.currency(locale: 'en_CA', symbol: 'CAD ', decimalDigits: 2);
  Future<List<LoanModel>>? _future;

  @override
  void initState() {
    super.initState();
    _future = LoansService.instance.fetchLoansFor(widget.customerId);
  }

  Future<void> _pay(LoanModel loan) async {
    await LoansService.instance.payInstalment(loan.loanApplicationId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Instalment paid for ${loan.productName ?? loan.loanApplicationId}')),
    );
    setState(() => _future = LoansService.instance.fetchLoansFor(widget.customerId));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LoanModel>>(
      future: _future,
      builder: (context, snap) {
        final loans = snap.data ?? const <LoanModel>[];
        if (loans.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text('Active Financing',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                const Spacer(),
                Text('${loans.length} active',
                    style: GoogleFonts.inter(
                        fontSize: 11.5, color: AppColors.onSurfaceVariant)),
              ]),
              const SizedBox(height: 12),
              for (var i = 0; i < loans.length; i++) ...[
                _row(loans[i]),
                if (i < loans.length - 1) const Divider(height: 20),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(LoanModel loan) {
    final isEpp = loan.isEpp;
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(9),
        ),
        clipBehavior: Clip.hardEdge,
        child: loan.productImageUrl != null && loan.productImageUrl!.isNotEmpty
            ? Image.network(loan.productImageUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(isEpp ? Icons.devices_other : Icons.home_outlined,
                        size: 20, color: AppColors.primary))
            : Icon(isEpp ? Icons.devices_other : Icons.home_outlined,
                size: 20, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loan.productName ?? (isEpp ? 'Easy Payment Plan' : 'Home mortgage'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            const SizedBox(height: 2),
            Text('${_cad.format(loan.monthlyPaymentCad)} / mo · ${loan.tenureLabel}',
                style: GoogleFonts.inter(
                    fontSize: 11.5, color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
      const SizedBox(width: 8),
      TextButton(
        onPressed: () => _pay(loan),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          foregroundColor: AppColors.primary,
        ),
        child: Text('Pay',
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}
