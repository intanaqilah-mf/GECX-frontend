import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/banking_models.dart';
import '../services/chat_overlay_controller.dart';
import '../services/loans_service.dart';
import '../theme/app_colors.dart';

/// Details view for one loan — Order block + Pay-in-N timeline + Pay Now.
///
/// Layout mirrors the Grab PayLater "Details" screen the user shared:
///   • Product card at the top
///   • Order block (Order ID, Order amount, Instalment Rate, Total payable)
///   • Pay-in-N with a checkmark timeline (paid rows green ticks, upcoming
///     rows empty circles, dashed "Auto-deducted" for next-up etc.)
///   • Sticky Pay Now button at the bottom
///
/// Data comes from [LoanModel.schedule] — a computed getter that derives
/// installment amounts + due dates from `monthlyPaymentCad`, `tenureMonths`
/// and `createdAt`, marking the first [LoanModel.paidInstalments] as paid.
class LoanBillingDetailScreen extends StatefulWidget {
  final LoanModel loan;
  const LoanBillingDetailScreen({super.key, required this.loan});

  @override
  State<LoanBillingDetailScreen> createState() =>
      _LoanBillingDetailScreenState();
}

class _LoanBillingDetailScreenState extends State<LoanBillingDetailScreen> {
  late LoanModel _loan;
  bool _paying = false;

  static final _cad =
      NumberFormat.currency(locale: 'en_CA', symbol: 'CAD ', decimalDigits: 2);
  static final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loan = widget.loan;
  }

  Future<void> _payNext() async {
    if (_paying) return;
    final schedule = _loan.schedule;
    final nextIdx = schedule.indexWhere((i) => !i.paid);
    if (nextIdx < 0) return; // fully paid
    setState(() => _paying = true);

    // Pass the model + signed-in customerId so payInstalment can actually
    // debit the account and write a real transaction (not just bump a
    // counter). Falls back to the counter-only behaviour if the model
    // doesn't have a customerId and none is available from the overlay.
    final cid = _loan.customerId.isNotEmpty
        ? _loan.customerId
        : (ChatOverlayController.instance.customerId ?? '');
    final result = await LoansService.instance.payInstalment(
      _loan.loanApplicationId,
      loan: _loan,
      customerId: cid,
    );

    // Re-fetch so the schedule reflects the incremented count.
    final refreshed = await LoansService.instance
        .fetchLoan(_loan.loanApplicationId);
    if (!mounted) return;
    setState(() {
      _paying = false;
      if (refreshed != null) _loan = refreshed;
    });

    // Loud, honest snackbar — if the debit was skipped (no active account,
    // permission-denied, missing customer_id), the user needs to know why
    // instead of celebrating a "success" that never touched the ledger.
    final msg = result.debited
        ? 'Paid instalment ${nextIdx + 1} of ${schedule.length} · '
            '${_cad.format(schedule[nextIdx].amount)}'
        : "Counter bumped but NO money moved — ${result.summary}";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            result.debited ? null : AppColors.error,
        duration: Duration(seconds: result.debited ? 3 : 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _loan.schedule;
    final paidCount = schedule.where((i) => i.paid).length;
    final total = schedule.length;
    final fullyPaid = paidCount >= total && total > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F6),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.onSurface,
        centerTitle: true,
        title: Text('Details',
            style: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & support coming soon')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _productCard(),
                  const SizedBox(height: 16),
                  _orderCard(),
                  const SizedBox(height: 16),
                  _scheduleCard(schedule, total),
                ],
              ),
            ),
            _payBar(schedule, paidCount, total, fullyPaid),
          ],
        ),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _productCard() {
    final name = _loan.productName ??
        (_loan.isMortgage ? 'Home mortgage' : 'Easy Payment Plan');
    final date =
        _loan.createdAt != null ? _dateFmt.format(_loan.createdAt!) : '';
    return _whiteCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(26),
            ),
            clipBehavior: Clip.hardEdge,
            child: (_loan.productImageUrl != null &&
                    _loan.productImageUrl!.isNotEmpty)
                ? Image.network(_loan.productImageUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackIcon())
                : _fallbackIcon(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface)),
                if (date.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(date,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Icon _fallbackIcon() => Icon(
        _loan.isMortgage ? Icons.home_outlined : Icons.devices_other,
        color: AppColors.primary,
      );

  Widget _orderCard() {
    return _whiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _orderRow('Order ID', _loan.loanApplicationId),
          _orderRow('Order amount', _cad.format(_loan.principalCad)),
          _orderRow(
            'Installment Rate',
            _cad.format(_loan.interestCad),
            trailingIcon: Icons.info_outline,
          ),
          const Divider(height: 20, thickness: 1, color: Color(0xFFEFEFF1)),
          _orderRow(
            'Total payable',
            _cad.format(_loan.totalRepayableCad),
            valueBold: true,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _orderRow(String label, String value,
      {IconData? trailingIcon, bool valueBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 15, color: AppColors.onSurfaceVariant)),
          if (trailingIcon != null) ...[
            const SizedBox(width: 6),
            Icon(trailingIcon,
                size: 16, color: AppColors.onSurfaceVariant),
          ],
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: valueBold ? FontWeight.w800 : FontWeight.w700,
                color: AppColors.onSurface,
              )),
        ],
      ),
    );
  }

  Widget _scheduleCard(List<LoanInstalment> schedule, int total) {
    return _whiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pay in $total',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface)),
          const SizedBox(height: 12),
          for (var i = 0; i < schedule.length; i++)
            _scheduleRow(schedule[i], total, isLast: i == schedule.length - 1),
        ],
      ),
    );
  }

  Widget _scheduleRow(LoanInstalment it, int total, {required bool isLast}) {
    final paid = it.paid;
    final label = paid ? '${it.index}/$total Paid' : '${it.index}/$total Auto-deduct';
    final labelColor = paid ? const Color(0xFF1F8A4C) : AppColors.onSurfaceVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column: circle + connector line.
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: paid ? const Color(0xFF1F8A4C) : Colors.white,
                    border: Border.all(
                      color:
                          paid ? const Color(0xFF1F8A4C) : AppColors.outline,
                      width: 2,
                    ),
                  ),
                  child: paid
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color:
                          paid ? const Color(0xFF1F8A4C) : AppColors.outline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Row content — label + date + amount on the right.
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: labelColor)),
                        const SizedBox(height: 2),
                        Text(_dateFmt.format(it.dueDate),
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text(_cad.format(it.amount),
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _payBar(List<LoanInstalment> schedule, int paid, int total, bool fullyPaid) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(top: BorderSide(color: Color(0xFFE0E1E4))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: (_paying || fullyPaid) ? null : _payNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppColors.primary.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          child: _paying
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  fullyPaid
                      ? 'Fully paid'
                      : total > 0
                          ? 'Pay Now · ${paid + 1} of $total'
                          : 'Pay Now',
                ),
        ),
      ),
    );
  }

  Widget _whiteCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFEFF1)),
      ),
      child: child,
    );
  }
}
