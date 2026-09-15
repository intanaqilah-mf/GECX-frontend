import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intl/intl.dart';

import '../models/banking_models.dart';
import '../services/api_service.dart';
import '../services/loans_service.dart';
import '../services/quick_actions.dart';
import '../services/transactions_service.dart';
import '../theme/app_colors.dart';
import 'loan_billing_detail_screen.dart';

/// Expenses tab — client-side aggregation of card activity + customer-level
/// transactions (including ACN QR Pay debits) into category buckets. CES
/// doesn't have a spending-insights flow yet, so the view lives here.
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
    // Each source is fetched with its own try/catch. A gateway 500 or an
    // offline network MUST NOT prevent the Firestore-side transactions from
    // rendering — that's exactly what made Expenses show CAD 0.00 even when
    // customers/{cid}/transactions had 21 real docs.
    String? cardId;
    try {
      final home = await _api.getHomeData(widget.customerId);
      cardId = home.latestCard?.cardId;
    } catch (e) {
      // ignore: avoid_print
      print('[Expenses] getHomeData failed: $e');
    }

    List<ActivityModel> cardActivity = const [];
    if (cardId != null && cardId.isNotEmpty) {
      try {
        cardActivity = await _api.getCardActivity(cardId);
      } catch (e) {
        // ignore: avoid_print
        print('[Expenses] getCardActivity failed: $e');
      }
    }

    // Firestore-side customer transactions — the source that matters for
    // QR pay + loan instalments. Rich result so we can differentiate empty
    // vs. permission-denied in the chip.
    final custResult = await TransactionsService.instance
        .fetchCustomerActivity(widget.customerId);

    final merged = <ActivityModel>[...cardActivity, ...custResult.transactions];
    return _ExpensesState.from(
      merged,
      customerTxnCount: custResult.rawCount,
      customerTxnError: custResult.error,
    );
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expenses',
                              style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface)),
                          const SizedBox(height: 4),
                          Text('This month',
                              style: GoogleFonts.inter(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    // Visible refresh — a lot of users don't discover the
                    // pull-to-refresh gesture, especially on web.
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh,
                          color: AppColors.primary),
                      onPressed: () =>
                          setState(() => _future = _load()),
                    ),
                    // Firestore self-test: writes a probe doc + reads it
                    // back three ways so we can see exactly what the
                    // Firestore SDK is doing. Kept next to the refresh
                    // button so it's easy to find while debugging.
                    IconButton(
                      tooltip: 'Firestore self-test',
                      icon: const Icon(Icons.bug_report_outlined,
                          color: AppColors.primary),
                      onPressed: () async {
                        final report = await TransactionsService.instance
                            .selfTest(widget.customerId);
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Firestore self-test'),
                            content: SelectableText(
                              report,
                              style: GoogleFonts.robotoMono(fontSize: 12),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                // Debug / error surfacing — silent-fail hid this before.
                if (state.customerTxnError != null)
                  _debugChip(
                    icon: Icons.error_outline,
                    color: AppColors.error,
                    text:
                        "Couldn't read transactions from Firestore: ${state.customerTxnError}",
                  ),
                if (state.customerTxnError == null &&
                    state.customerTxnCount == 0)
                  _debugChip(
                    icon: Icons.info_outline,
                    color: AppColors.onSurfaceVariant,
                    text:
                        'No transactions on this customer yet (customers/${widget.customerId}/transactions is empty).',
                  ),
                const SizedBox(height: 12),
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

  /// Small hint row — used to distinguish "Firestore empty" from "Firestore
  /// blocked our read" so the user isn't left guessing why Total spend is 0.
  Widget _debugChip({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: color,
                height: 1.35,
              ),
            ),
          ),
        ],
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
    // Special-case product slugs so they read as product names, not
    // snake-case internals.
    if (raw == 'qr_transfer' || raw == 'qr_credit') return 'ACN QR Pay';
    if (raw == 'epp_installment')      return 'EPP Instalment';
    if (raw == 'mortgage_installment') return 'Mortgage Instalment';
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
  /// Raw count of docs in customers/{id}/transactions (before spend/credit
  /// filtering). Surfaced in the UI so a "0 transactions" screen can say
  /// whether Firestore actually has nothing vs. the read was blocked.
  final int customerTxnCount;
  /// Human-readable Firestore error (permission-denied, network) if the
  /// customer-txn read failed. Null on success.
  final String? customerTxnError;

  _ExpensesState({
    required this.total,
    required this.count,
    required this.byCategory,
    this.customerTxnCount = 0,
    this.customerTxnError,
  });

  factory _ExpensesState.empty() =>
      _ExpensesState(total: 0, count: 0, byCategory: {});

  factory _ExpensesState.from(
    List<ActivityModel> acts, {
    int customerTxnCount = 0,
    String? customerTxnError,
  }) {
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
    return _ExpensesState(
      total: total,
      count: acts.length,
      byCategory: sorted,
      customerTxnCount: customerTxnCount,
      customerTxnError: customerTxnError,
    );
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
  // 'all' | 'epp' | 'mortgage' — persists per screen instance. Only shown
  // when the customer has BOTH types; single-type customers see plain list.
  String _tab = 'all';

  @override
  void initState() {
    super.initState();
    _future = LoansService.instance.fetchLoansFor(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LoanModel>>(
      future: _future,
      builder: (context, snap) {
        final loans = snap.data ?? const <LoanModel>[];
        if (loans.isEmpty) return const SizedBox.shrink();

        final hasEpp = loans.any((l) => l.isEpp);
        final hasMortgage = loans.any((l) => l.isMortgage);
        final showTabs = hasEpp && hasMortgage;

        // Auto-normalise the current tab if the loan set changed (e.g. the
        // last EPP was cancelled) so we don't render an empty pane.
        if (!showTabs) _tab = 'all';
        if (_tab == 'epp' && !hasEpp) _tab = 'all';
        if (_tab == 'mortgage' && !hasMortgage) _tab = 'all';

        final visible = switch (_tab) {
          'epp'      => loans.where((l) => l.isEpp).toList(),
          'mortgage' => loans.where((l) => l.isMortgage).toList(),
          _          => loans,
        };

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
                Text('${visible.length} active',
                    style: GoogleFonts.inter(
                        fontSize: 11.5, color: AppColors.onSurfaceVariant)),
              ]),
              if (showTabs) ...[
                const SizedBox(height: 10),
                _financingTabs(),
              ],
              const SizedBox(height: 12),
              for (var i = 0; i < visible.length; i++) ...[
                _row(visible[i]),
                if (i < visible.length - 1) const Divider(height: 20),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Maybank-style segmented header. Rendered only when the customer has
  /// both loan types; single-type customers get the plain list above.
  Widget _financingTabs() {
    return Row(
      children: [
        _tabButton(label: 'All',       value: 'all'),
        _tabButton(label: 'EPP',       value: 'epp'),
        _tabButton(label: 'Mortgage',  value: 'mortgage'),
      ],
    );
  }

  Widget _tabButton({required String label, required String value}) {
    final active = _tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppColors.primary : AppColors.outlineVariant,
                width: active ? 2 : 1,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? AppColors.onSurface : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail(LoanModel loan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoanBillingDetailScreen(loan: loan),
      ),
    );
    // Refresh on return so any instalment paid inside the detail reflects
    // here (loan row shows next-month's amount, count etc.).
    if (!mounted) return;
    setState(() =>
        _future = LoansService.instance.fetchLoansFor(widget.customerId));
  }

  Widget _row(LoanModel loan) {
    final isEpp = loan.isEpp;
    final total = loan.tenureMonths;
    final paid = loan.paidInstalments;
    final progress = total > 0 ? '$paid / $total paid' : loan.tenureLabel;
    return InkWell(
      onTap: () => _openDetail(loan),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            clipBehavior: Clip.hardEdge,
            child:
                loan.productImageUrl != null && loan.productImageUrl!.isNotEmpty
                    ? Image.network(loan.productImageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            isEpp ? Icons.devices_other : Icons.home_outlined,
                            size: 20,
                            color: AppColors.primary))
                    : Icon(isEpp ? Icons.devices_other : Icons.home_outlined,
                        size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    loan.productName ??
                        (isEpp ? 'Easy Payment Plan' : 'Home mortgage'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(
                    '${_cad.format(loan.monthlyPaymentCad)} / mo · $progress',
                    style: GoogleFonts.inter(
                        fontSize: 11.5, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right,
              color: AppColors.onSurfaceVariant, size: 20),
        ]),
      ),
    );
  }
}
