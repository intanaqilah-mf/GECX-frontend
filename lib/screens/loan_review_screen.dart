import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/banking_models.dart';
import '../services/chat_overlay_controller.dart';
import '../services/loans_service.dart';
import '../theme/app_colors.dart';

/// End of the web -> app loan handoff.
///
/// Pushed by main.dart's SSO bootstrap when the launch URL carried
/// `?loan_draft=LOAN_…&handoff_token=…&sso=web`. Fetches the draft, renders a
/// review-and-confirm screen, and either activates or cancels the loan on the
/// backend before returning the customer to AppShell.
class LoanReviewScreen extends StatefulWidget {
  final String loanApplicationId;
  final String? handoffToken;

  const LoanReviewScreen({
    super.key,
    required this.loanApplicationId,
    this.handoffToken,
  });

  @override
  State<LoanReviewScreen> createState() => _LoanReviewScreenState();
}

class _LoanReviewScreenState extends State<LoanReviewScreen> {
  final _cad = NumberFormat.currency(
    locale: 'en_CA',
    symbol: 'CAD ',
    decimalDigits: 2,
  );

  Future<LoanModel?>? _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    ChatOverlayController.instance.pushSuppressBubble();
    _future = LoansService.instance.fetchLoan(
      widget.loanApplicationId,
      handoffToken: widget.handoffToken,
    );
  }

  @override
  void dispose() {
    ChatOverlayController.instance.popSuppressBubble();
    super.dispose();
  }

  Future<void> _confirm(LoanModel loan) async {
    setState(() => _submitting = true);
    try {
      await LoansService.instance.confirmLoan(loan.loanApplicationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loan activated. See it in Expenses.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not activate: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(LoanModel loan) async {
    setState(() => _submitting = true);
    try {
      await LoansService.instance.cancelLoan(loan.loanApplicationId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Review your loan',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
      body: FutureBuilder<LoanModel?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return _emptyState();
          }
          return _reviewBody(snapshot.data!);
        },
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('We couldn\'t find that loan draft.',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('The link may have expired. Please start over from the web chat.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );

  Widget _reviewBody(LoanModel loan) {
    final isEpp = loan.isEpp;
    final kindLabel = isEpp ? 'Easy Payment Plan' : 'Home mortgage';
    final kindIcon = isEpp ? Icons.phone_iphone : Icons.home_outlined;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Journey timeline — grounds the customer in where they are in the
          // arc so the screen never feels like a dead-end static form. The
          // three earlier steps happened on web and are marked done; "Review
          // & sign" is the current step; the two after are what still needs
          // to happen. Copy is intentionally outcome-focused.
          _JourneyTimeline(currentIndex: 3, isEpp: loan.isEpp),
          const SizedBox(height: 18),

          // Kind pill + verdict banner
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(kindIcon, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(kindLabel,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppColors.primary)),
              ]),
            ),
            const Spacer(),
            if (loan.isProvisional)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('PROVISIONAL',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: const Color(0xFFD97706))),
              ),
          ]),
          const SizedBox(height: 16),

          // Product/property tile
          _productTile(loan),
          const SizedBox(height: 20),

          // Monthly headline
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(children: [
              Text('MONTHLY',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(_cad.format(loan.monthlyPaymentCad),
                  style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(height: 6),
              Text(
                '${loan.tenureLabel}${loan.interestRatePct > 0 ? ' · ${loan.interestRatePct}%' : ''}',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Breakdown
          _breakdown(loan),
          const SizedBox(height: 28),

          // Confirm
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _submitting ? null : () => _confirm(loan),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isEpp ? 'Activate my plan' : 'Confirm and continue',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _submitting ? null : () => _cancel(loan),
            child: Text('Cancel this ${isEpp ? 'plan' : 'application'}',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),

          // What happens after they tap Activate. Makes the flow feel like
          // a continuing journey, not an isolated one-shot form.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEpp
                        ? 'After you activate, your first payment schedules for next month and you can manage it under Expenses → Active Financing.'
                        : 'After you confirm, an ACN Bank mortgage advisor will call you within 1 business day to finish the assessment.',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productTile(LoanModel loan) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.hardEdge,
          child: loan.productImageUrl != null && loan.productImageUrl!.isNotEmpty
              ? Image.network(
                  loan.productImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(loan.isEpp ? Icons.devices_other : Icons.home_outlined,
                          color: AppColors.primary, size: 28),
                )
              : Icon(loan.isEpp ? Icons.devices_other : Icons.home_outlined,
                  color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loan.productName ?? 'Loan draft',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              const SizedBox(height: 4),
              Text('Principal ${_cad.format(loan.principalCad)}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text('Ref: ${loan.loanApplicationId}',
                  style: GoogleFonts.inter(
                      fontSize: 10.5, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _breakdown(LoanModel loan) {
    final rows = <MapEntry<String, String>>[];
    if (loan.isEpp) {
      final epp = (loan.payloadSnapshot['epp'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (epp['retail_price_cad'] != null) {
        rows.add(MapEntry('Retail price', _cad.format((epp['retail_price_cad'] as num).toDouble())));
      }
      if (epp['total_repayable_cad'] != null) {
        rows.add(MapEntry('Total repayable', _cad.format((epp['total_repayable_cad'] as num).toDouble())));
      }
      if (epp['merchant'] != null) {
        rows.add(MapEntry('Merchant', epp['merchant'].toString()));
      }
    } else {
      final m = (loan.payloadSnapshot['mortgage'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (m['property_price_cad'] != null) {
        rows.add(MapEntry('Property price', _cad.format((m['property_price_cad'] as num).toDouble())));
      }
      if (m['down_payment_cad'] != null) {
        rows.add(MapEntry('Down payment', _cad.format((m['down_payment_cad'] as num).toDouble())));
      }
      if (m['loan_to_value_pct'] != null) {
        rows.add(MapEntry('Loan-to-value', '${m['loan_to_value_pct']}%'));
      }
      if (m['gds_pct'] != null) {
        rows.add(MapEntry('Gross debt service', '${m['gds_pct']}%'));
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(children: [
              Expanded(
                child: Text(rows[i].key,
                    style: GoogleFonts.inter(
                        fontSize: 12.5, color: AppColors.onSurfaceVariant)),
              ),
              Text(rows[i].value,
                  style: GoogleFonts.inter(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            ]),
            if (i < rows.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Horizontal 6-step progress timeline shown at the top of [LoanReviewScreen].
///
/// [currentIndex] is the index of the "you are here" step (0-based). Steps
/// before it are drawn as completed (filled blue circle + check icon); the
/// current step is drawn as an active pill (larger, filled); steps after
/// are drawn as pending (hollow outline + muted label).
///
/// Reads as the arc:
///   ✓ Picked → ✓ Plan → ✓ Pre-approved → ● REVIEW & SIGN → ○ Auto-pay → ○ First payment
class _JourneyTimeline extends StatelessWidget {
  final int currentIndex;
  final bool isEpp;

  const _JourneyTimeline({required this.currentIndex, required this.isEpp});

  @override
  Widget build(BuildContext context) {
    final steps = isEpp
        ? const ['Picked', 'Plan', 'Pre-approved', 'Review & sign', 'Auto-pay', 'First month']
        : const ['Details', 'Calculator', 'KYC', 'Review & sign', 'Advisor', 'Funded'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(child: _stepCell(steps[i], i, isLast: i == steps.length - 1)),
        ],
      ),
    );
  }

  Widget _stepCell(String label, int index, {required bool isLast}) {
    final bool done = index < currentIndex;
    final bool active = index == currentIndex;
    final Color nodeColor = done || active
        ? AppColors.primary
        : AppColors.outlineVariant;
    final Color labelColor = active
        ? AppColors.primary
        : done
            ? AppColors.onSurface
            : AppColors.onSurfaceVariant;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            Container(
              width: active ? 22 : 16,
              height: active ? 22 : 16,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.primary
                    : active
                        ? AppColors.primary
                        : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: nodeColor, width: active ? 2 : 1.5),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : active
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                        )
                      : null,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: labelColor,
                height: 1.2,
              ),
            ),
          ],
        ),
        // Connector line to next step
        if (!isLast)
          Positioned(
            top: active ? 10 : 7,
            left: null,
            right: 0,
            child: FractionalTranslation(
              translation: const Offset(0.5, 0),
              child: Container(
                width: 40,
                height: 1.5,
                color: done ? AppColors.primary : AppColors.outlineVariant,
              ),
            ),
          ),
      ],
    );
  }
}
