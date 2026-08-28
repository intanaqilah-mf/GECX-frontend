import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/banking_models.dart';
import '../services/api_service.dart';
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
          colors: [Color(0xFFA100FF), Color(0xFF7500C0)],
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
