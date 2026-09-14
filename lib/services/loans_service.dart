import '../main.dart' show AppStartup;
import '../models/banking_models.dart';

/// Reads and mutates the customer's loan applications.
///
/// For the demo this backs onto in-memory mock data so the app renders
/// end-to-end without requiring Firestore rules, a gateway route, or a live
/// deployment. When you're ready to wire real reads, swap [fetchLoansFor] and
/// [fetchLoan] with a Cloud Firestore call:
///
///     final snap = await FirebaseFirestore.instance
///         .collection('loan_applications')
///         .where('customer_id', isEqualTo: customerId)
///         .get();
///     return snap.docs.map((d) => LoanModel.fromJson(d.data())).toList();
///
/// The mock seed matches the shape written by the CES `create_loan_application`
/// tool exactly, so the UI code doesn't change when you flip the switch.
class LoansService {
  LoansService._();
  static final LoansService instance = LoansService._();

  // ── Demo seed ──────────────────────────────────────────────────────────────
  final List<LoanModel> _mock = [
    LoanModel(
      loanApplicationId: 'LOAN_SEED_EPP_0001',
      loanKind: 'epp',
      status: 'active',
      verdict: 'pre_approved',
      isProvisional: false,
      monthlyPaymentCad: 152.24,
      principalCad: 1749.00,
      tenureLabel: '12 months',
      interestRatePct: 1.5,
      productName: 'iPhone 17 Pro',
      productImageUrl:
          'https://placehold.co/440x440/0b1e3a/ffffff?text=iPhone+17+Pro',
      payloadSnapshot: {
        'loan_kind': 'epp',
        'epp': {
          'product_id': 'iphone-17-pro-256',
          'product_name': 'iPhone 17 Pro',
          'product_image_url':
              'https://placehold.co/440x440/0b1e3a/ffffff?text=iPhone+17+Pro',
          'retail_price_cad': 1749.00,
          'tenure_months': 12,
          'monthly_amount_cad': 152.24,
          'total_repayable_cad': 1775.24,
          'interest_rate_pct': 1.5,
          'merchant': 'Apple Canada',
        },
      },
    ),
  ];

  /// Every loan owned by the customer, most recently updated first.
  Future<List<LoanModel>> fetchLoansFor(String customerId) async {
    // Simulate network latency so the UI shows the loading state.
    await Future.delayed(const Duration(milliseconds: 250));
    return _mock
        .where((l) =>
            l.customerId.isEmpty || // seed rows have no customer bound
            l.customerId == customerId)
        .toList();
  }

  /// Fetch one loan by id — used by LoanReviewScreen after the deep-link handoff.
  ///
  /// Resolution order:
  ///   1. Any seed row that matches loanApplicationId (test data).
  ///   2. The flat snapshot parsed from the handoff URL (kind, product,
  ///      monthly, principal, tenure, rate, verdict, img). This is what
  ///      the current CES `create_loan_application` tool encodes, so the
  ///      review screen always matches the webchat journey.
  ///   3. Give up and return null (LoanReviewScreen shows _emptyState).
  ///
  /// Swap steps 1+3 for a Cloud Firestore read when the gateway is live;
  /// step 2 stays useful as a hot-path so the review screen renders even
  /// before the backend replies.
  Future<LoanModel?> fetchLoan(String loanApplicationId,
      {String? handoffToken}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    try {
      return _mock.firstWhere((l) => l.loanApplicationId == loanApplicationId);
    } catch (_) {
      // Fall through — try the URL-encoded snapshot.
    }

    final snap = AppStartup.pendingLoanSnapshot;
    if (snap != null && snap.isNotEmpty) {
      // Consume once — a hot-reload / rebuild shouldn't reuse stale data.
      AppStartup.pendingLoanSnapshot = null;
      return _buildFromSnapshot(loanApplicationId, snap);
    }

    return null;
  }

  /// Turns the flat handoff-URL snapshot into a LoanModel. Both loan kinds
  /// share the same query keys — we branch on `kind` to fill the nested
  /// payloadSnapshot map that the review screen's breakdown widget reads.
  LoanModel _buildFromSnapshot(String loanApplicationId, Map<String, String> s) {
    final kind = (s['kind'] ?? 'epp').toLowerCase();
    final monthly = double.tryParse(s['monthly'] ?? '') ?? 0;
    final principal = double.tryParse(s['principal'] ?? '') ?? 0;
    final rate = double.tryParse(s['rate'] ?? '') ?? 0;
    final tenure = s['tenure'] ?? '';
    final verdict = s['verdict'] ?? 'pre_approved';
    final product = s['product'] ?? (kind == 'mortgage' ? 'Home mortgage estimate' : 'Loan draft');
    final image = s['img'];

    final Map<String, dynamic> payload;
    if (kind == 'mortgage') {
      payload = {
        'loan_kind': 'mortgage',
        'mortgage': {
          'loan_principal_cad': principal,
          'tenure_years': _yearsFromLabel(tenure),
          'interest_rate_pct': rate,
          'monthly_payment_cad': monthly,
        },
      };
    } else {
      payload = {
        'loan_kind': 'epp',
        'epp': {
          'product_name': product,
          if (image != null && image.isNotEmpty) 'product_image_url': image,
          'retail_price_cad': principal,
          'tenure_months': _monthsFromLabel(tenure),
          'monthly_amount_cad': monthly,
          'total_repayable_cad':
              double.parse((principal * (1 + rate / 100)).toStringAsFixed(2)),
          'interest_rate_pct': rate,
        },
      };
    }

    return LoanModel(
      loanApplicationId: loanApplicationId,
      loanKind: kind,
      status: 'draft',
      verdict: verdict,
      isProvisional: true,
      monthlyPaymentCad: monthly,
      principalCad: principal,
      tenureLabel: tenure,
      interestRatePct: rate,
      productName: product,
      productImageUrl: image,
      payloadSnapshot: payload,
    );
  }

  int _monthsFromLabel(String tenure) {
    final m = RegExp(r'(\d+)').firstMatch(tenure);
    return m == null ? 0 : int.tryParse(m.group(1) ?? '0') ?? 0;
  }

  int _yearsFromLabel(String tenure) {
    // Same regex — the label already says "years" for mortgage / "months" for EPP.
    final m = RegExp(r'(\d+)').firstMatch(tenure);
    return m == null ? 0 : int.tryParse(m.group(1) ?? '0') ?? 0;
  }

  /// Marks a loan as active (called after the customer confirms review).
  Future<void> confirmLoan(String loanApplicationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _mock.indexWhere((l) => l.loanApplicationId == loanApplicationId);
    if (idx >= 0) return; // already active — no-op
    // In real impl: POST /loans/{id}/actions body {action: 'activate'}
  }

  /// Marks a loan as cancelled.
  Future<void> cancelLoan(String loanApplicationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _mock.removeWhere((l) => l.loanApplicationId == loanApplicationId);
  }

  /// Records a single instalment payment against an EPP loan.
  Future<void> payInstalment(String loanApplicationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Real impl posts a transaction — mock just no-ops.
  }
}
