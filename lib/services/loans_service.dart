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
  Future<LoanModel?> fetchLoan(String loanApplicationId,
      {String? handoffToken}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    try {
      return _mock.firstWhere((l) => l.loanApplicationId == loanApplicationId);
    } catch (_) {
      // Not seeded — for the demo, synthesise a mortgage draft so the review
      // screen can still render something meaningful when a real handoff URL
      // arrives before Firestore is wired.
      return LoanModel(
        loanApplicationId: loanApplicationId,
        loanKind: 'mortgage',
        status: 'draft',
        verdict: 'pre_approved',
        isProvisional: true,
        monthlyPaymentCad: 3082.15,
        principalCad: 520000,
        tenureLabel: '25 years',
        interestRatePct: 5.14,
        productName: 'Home mortgage estimate',
        payloadSnapshot: {
          'loan_kind': 'mortgage',
          'mortgage': {
            'property_price_cad': 650000,
            'down_payment_cad': 130000,
            'loan_principal_cad': 520000,
            'tenure_years': 25,
            'interest_rate_pct': 5.14,
            'monthly_payment_cad': 3082.15,
          },
        },
      );
    }
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
