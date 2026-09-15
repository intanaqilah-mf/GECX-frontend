import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../main.dart' show AppStartup;
import '../models/banking_models.dart';

/// Reads and mutates the customer's loan applications.
///
/// Reads live docs from Firestore (`loan_applications` collection where
/// `customer_id == customerId`) so a new EPP / mortgage created through
/// CES shows up in the app immediately. Falls back to a small in-memory
/// mock when the customer has no docs yet, so an unseeded demo instance
/// still renders a plausible "Active Financing" row.
///
/// The CES `create_loan_application` tool writes docs matching
/// [LoanModel.fromJson]'s expected shape (see banking_models.dart) — no
/// translation layer needed.
class LoansService {
  LoansService._();
  static final LoansService instance = LoansService._();

  static const String _databaseId = 'acn-bank-fs-db';

  FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: _databaseId,
      );

  Future<void> _ensureAuth() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  // ── Demo seed ──────────────────────────────────────────────────────────────
  // Used only when Firestore returns nothing for a customer — keeps the demo
  // "Active Financing" section populated without needing to seed the DB.
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
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      payloadSnapshot: {
        'loan_kind': 'epp',
        'paid_instalments': 3, // 3 of 12 paid — realistic snapshot
        'epp': {
          'product_id': 'iphone-17-pro-256',
          'product_name': 'iPhone 17 Pro',
          'product_image_url':
              'https://placehold.co/440x440/0b1e3a/ffffff?text=iPhone+17+Pro',
          'retail_price_cad': 1749.00,
          'tenure_months': 12,
          'monthly_amount_cad': 152.24,
          'total_repayable_cad': 1826.88,
          'interest_rate_pct': 1.5,
          'merchant': 'Apple Canada',
        },
      },
    ),
  ];

  /// Every loan owned by the customer, most recently updated first.
  ///
  /// Read path: Firestore `loan_applications` where `customer_id == cid`.
  /// If the read fails (rules, offline) or returns empty, we return the
  /// mock so the demo Expenses tab isn't blank.
  Future<List<LoanModel>> fetchLoansFor(String customerId) async {
    try {
      await _ensureAuth();
      final snap = await _db
          .collection('loan_applications')
          .where('customer_id', isEqualTo: customerId)
          .get();
      if (snap.docs.isNotEmpty) {
        final loans = snap.docs
            .map((d) => LoanModel.fromJson({
                  ...d.data(),
                  'loan_application_id': d.id,
                }))
            .toList();
        loans.sort((a, b) {
          final ad = a.updatedAt ?? a.createdAt ?? DateTime(1970);
          final bd = b.updatedAt ?? b.createdAt ?? DateTime(1970);
          return bd.compareTo(ad);
        });
        return loans;
      }
    } catch (e) {
      // ignore: avoid_print
      print('[LoansService] fetchLoansFor Firestore failed, using mock: $e');
    }
    // Fallback — demo mock, filtered to unbound seed rows or exact match.
    return _mock
        .where((l) => l.customerId.isEmpty || l.customerId == customerId)
        .toList();
  }

  /// Fetch one loan by id — used by LoanReviewScreen after the deep-link handoff.
  ///
  /// Resolution order (freshest first):
  ///   1. Deep-link snapshot (URL hand-off) — the user literally just tapped
  ///      "Continue in the app" and the CES widget encoded the full plan into
  ///      the URL. This wins over Firestore because the CES agent's
  ///      create_loan_application tool sometimes writes a stub doc with only
  ///      status/kind and no monetary fields, which would render CAD 0.00.
  ///   2. Firestore `loan_applications/{id}` — for a loan the user opened
  ///      later without going through the hand-off (e.g. from the Active
  ///      Financing list).
  ///   3. Seed mock — demo fallback.
  Future<LoanModel?> fetchLoan(String loanApplicationId,
      {String? handoffToken}) async {
    // 1) URL-handoff snapshot — authoritative when fresh.
    final snap = AppStartup.pendingLoanSnapshot;
    if (snap != null && snap.isNotEmpty) {
      // Consume once — a hot-reload / rebuild shouldn't reuse stale data.
      AppStartup.pendingLoanSnapshot = null;
      return _buildFromSnapshot(loanApplicationId, snap);
    }

    // 2) Firestore.
    try {
      await _ensureAuth();
      final doc = await _db
          .collection('loan_applications')
          .doc(loanApplicationId)
          .get();
      if (doc.exists) {
        return LoanModel.fromJson({
          ...doc.data()!,
          'loan_application_id': doc.id,
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('[LoansService] fetchLoan Firestore failed: $e');
    }

    // 3) Seed mock.
    try {
      return _mock.firstWhere((l) => l.loanApplicationId == loanApplicationId);
    } catch (_) {}

    return null;
  }

  LoanModel _buildFromSnapshot(String loanApplicationId, Map<String, String> s) {
    final kind = (s['kind'] ?? 'epp').toLowerCase();
    final monthly = double.tryParse(s['monthly'] ?? '') ?? 0;
    final principal = double.tryParse(s['principal'] ?? '') ?? 0;
    final rate = double.tryParse(s['rate'] ?? '') ?? 0;
    final tenure = s['tenure'] ?? '';
    final verdict = s['verdict'] ?? 'pre_approved';
    final product =
        s['product'] ?? (kind == 'mortgage' ? 'Home mortgage estimate' : 'Loan draft');
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
    final m = RegExp(r'(\d+)').firstMatch(tenure);
    return m == null ? 0 : int.tryParse(m.group(1) ?? '0') ?? 0;
  }

  /// Marks a loan as active (called after the customer confirms review).
  ///
  /// If [loan] is provided, we upsert the FULL record (customer_id, kind,
  /// principal, monthly, tenure, rate, payload_snapshot, ...). This matters
  /// because CES's `create_loan_application` sometimes writes a stub doc
  /// (or none at all) and `fetchLoansFor` queries by `customer_id ==` —
  /// without a customer_id on the doc it never shows up in Expenses.
  ///
  /// The id-only overload is kept for backward compatibility with call
  /// sites that don't have the model handy.
  Future<void> confirmLoan(String loanApplicationId, {LoanModel? loan}) async {
    try {
      await _ensureAuth();
      final now = DateTime.now();
      final payload = <String, dynamic>{
        'status': 'active',
        'updated_at': now.toUtc().toIso8601String(),
      };
      if (loan != null) {
        payload.addAll({
          'loan_application_id': loan.loanApplicationId,
          'loan_kind': loan.loanKind,
          'customer_id': loan.customerId,
          'verdict': loan.verdict.isEmpty ? 'pre_approved' : loan.verdict,
          'is_provisional': false,
          'monthly_payment_cad': loan.monthlyPaymentCad,
          'principal_cad': loan.principalCad,
          'interest_rate_pct': loan.interestRatePct,
          'tenure_label': loan.tenureLabel,
          'payload_snapshot': loan.payloadSnapshot,
          // Only write created_at if the doc is brand new — merge:true
          // won't overwrite an existing value, so this is safe to always
          // include.
          'created_at': (loan.createdAt ?? now).toUtc().toIso8601String(),
        });
      }
      await _db.collection('loan_applications').doc(loanApplicationId).set(
        payload,
        SetOptions(merge: true),
      );
    } catch (e) {
      // ignore: avoid_print
      print('[LoansService] confirmLoan Firestore failed: $e');
    }
  }

  /// Marks a loan as cancelled.
  Future<void> cancelLoan(String loanApplicationId) async {
    try {
      await _ensureAuth();
      await _db.collection('loan_applications').doc(loanApplicationId).set(
        {
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      // ignore: avoid_print
      print('[LoansService] cancelLoan Firestore failed: $e');
    }
    _mock.removeWhere((l) => l.loanApplicationId == loanApplicationId);
  }

  /// Records a single instalment payment against a loan. See [PayInstalmentResult]
  /// for what each field reports back so the UI can distinguish "counter
  /// bumped but no money moved" from full success.
  Future<PayInstalmentResult> payInstalment(
    String loanApplicationId, {
    LoanModel? loan,
    String? customerId,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toUtc().toIso8601String();
    final cid = (customerId?.isNotEmpty ?? false)
        ? customerId!
        : (loan?.customerId ?? '');
    final amount = loan?.monthlyPaymentCad ?? 0;
    final kind = loan?.loanKind ?? '';
    final productName = loan?.productName ??
        (kind == 'mortgage' ? 'Home mortgage' : 'Easy Payment Plan');

    // Tracks what actually happened so the UI can surface it in the snackbar.
    bool debited = false;
    String? debitError;
    String? debitAccountId;
    int accountsSeen = 0;
    int activeAccountsSeen = 0;

    // ── Step 1-3: debit sender + write installment txn (only if we have
    // enough info to do so). Mock-only loans (no customer_id, no amount)
    // skip this and just bump the counter — same as before.
    if (cid.isEmpty) {
      debitError = 'no customer id (loan.customerId + overlay customerId both empty)';
    } else if (amount <= 0) {
      debitError = 'no monthly amount on loan (was $amount)';
    } else {
      try {
        await _ensureAuth();

        // Pick the account to debit — first active, prefer CHQ-*.
        final accSnap = await _db
            .collection('customers')
            .doc(cid)
            .collection('accounts')
            .get();
        accountsSeen = accSnap.docs.length;
        Map<String, dynamic>? active;
        Map<String, dynamic>? chq;
        String? accountId;
        for (final d in accSnap.docs) {
          final data = Map<String, dynamic>.from(d.data());
          data['account_id'] ??= d.id;
          if ((data['status'] ?? '').toString().toLowerCase() != 'active') {
            continue;
          }
          activeAccountsSeen++;
          active ??= data;
          final id = data['account_id'] as String;
          if (id.startsWith('CHQ-')) chq ??= data;
        }
        final chosen = chq ?? active;
        if (chosen == null) {
          debitError = 'customer $cid has $accountsSeen accounts, '
              '0 active — cannot debit';
        } else {
          accountId = chosen['account_id'] as String;
          debitAccountId = accountId;
          final balance = (chosen['balance'] as num?)?.toDouble() ?? 0.0;
          final newBalance = balance - amount;

          final category =
              kind == 'mortgage' ? 'mortgage_installment' : 'epp_installment';
          final ref =
              '${kind == 'mortgage' ? 'MTG' : 'EPP'}-$loanApplicationId-${(loan?.paidInstalments ?? 0) + 1}';

          final batch = _db.batch();
          batch.set(
            _db
                .collection('customers')
                .doc(cid)
                .collection('accounts')
                .doc(accountId),
            {'balance': newBalance, 'updated_at': nowIso},
            SetOptions(merge: true),
          );
          batch.set(
            _db
                .collection('customers')
                .doc(cid)
                .collection('transactions')
                .doc(ref),
            {
              'transaction_id': ref,
              'account_id': accountId,
              'customer_id': cid,
              'type': 'debit',
              'category': category,
              'amount': amount,
              'currency': 'CAD',
              'description':
                  '${kind == 'mortgage' ? 'Mortgage' : 'EPP'} instalment · $productName',
              'counterparty_name': productName,
              'balance_after': newBalance,
              'reference_no': ref,
              'loan_application_id': loanApplicationId,
              'timestamp': nowIso,
            },
          );
          await batch.commit();
          debited = true;
          // ignore: avoid_print
          print('[LoansService] payInstalment debited $cid/$accountId '
              '$amount → new balance $newBalance (ref $ref)');

          // ── DIAGNOSTIC: immediately read back what we just wrote via
          //    (a) direct get on the doc  (needs `get` permission)
          //    (b) list of the parent collection  (needs `list` permission)
          //    Both should succeed if rules are consistent. If (a) is fine
          //    and (b) returns 0, Firestore rules are letting us CREATE
          //    docs but blocking LIST — which is exactly why Expenses shows
          //    "empty" even after a successful pay.
          try {
            final direct = await _db
                .collection('customers')
                .doc(cid)
                .collection('transactions')
                .doc(ref)
                .get();
            final list = await _db
                .collection('customers')
                .doc(cid)
                .collection('transactions')
                .limit(3)
                .get();
            // ignore: avoid_print
            print('[LoansService] readback direct=${direct.exists} '
                'list.size=${list.docs.length}');
          } catch (e) {
            // ignore: avoid_print
            print('[LoansService] readback failed: $e');
          }
        }
      } catch (e) {
        debitError = e.toString();
        // ignore: avoid_print
        print('[LoansService] payInstalment debit failed: $e');
      }
    }

    // ── Step 4: bump paid_instalments on the loan doc (Firestore first).
    bool counterBumped = false;
    String? counterError;
    try {
      await _ensureAuth();
      final ref = _db.collection('loan_applications').doc(loanApplicationId);
      final doc = await ref.get();
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data() ?? {});
        int paid = (data['paid_instalments'] as int?) ?? 0;
        Map<String, dynamic>? snap;
        if (data['payload_snapshot'] is Map) {
          snap = Map<String, dynamic>.from(data['payload_snapshot'] as Map);
          paid = (snap['paid_instalments'] as int?) ?? paid;
        }
        final nextPaid = paid + 1;
        final update = <String, dynamic>{
          'paid_instalments': nextPaid,
          'updated_at': nowIso,
        };
        if (snap != null) {
          snap['paid_instalments'] = nextPaid;
          update['payload_snapshot'] = snap;
        }
        await ref.set(update, SetOptions(merge: true));
        counterBumped = true;
        return PayInstalmentResult(
          debited: debited,
          debitError: debitError,
          debitAccountId: debitAccountId,
          accountsSeen: accountsSeen,
          activeAccountsSeen: activeAccountsSeen,
          counterBumped: counterBumped,
        );
      }
    } catch (e) {
      counterError = e.toString();
      // ignore: avoid_print
      print('[LoansService] payInstalment counter update failed: $e');
    }

    // ── Fallback: bump the mock so single-tab demo without Firestore still
    // sees the counter tick over.
    final idx =
        _mock.indexWhere((l) => l.loanApplicationId == loanApplicationId);
    if (idx >= 0) {
      final l = _mock[idx];
      final snap = Map<String, dynamic>.from(l.payloadSnapshot);
      final current = (snap['paid_instalments'] as int?) ?? 0;
      snap['paid_instalments'] = current + 1;
      _mock[idx] = LoanModel(
        loanApplicationId: l.loanApplicationId,
        loanKind: l.loanKind,
        status: l.status,
        verdict: l.verdict,
        isProvisional: l.isProvisional,
        monthlyPaymentCad: l.monthlyPaymentCad,
        principalCad: l.principalCad,
        tenureLabel: l.tenureLabel,
        interestRatePct: l.interestRatePct,
        customerId: l.customerId,
        productName: l.productName,
        productImageUrl: l.productImageUrl,
        payloadSnapshot: snap,
        createdAt: l.createdAt,
        updatedAt: DateTime.now(),
      );
      counterBumped = true;
    }

    return PayInstalmentResult(
      debited: debited,
      debitError: debitError,
      debitAccountId: debitAccountId,
      accountsSeen: accountsSeen,
      activeAccountsSeen: activeAccountsSeen,
      counterBumped: counterBumped,
      counterError: counterError,
    );
  }
}

/// Detailed outcome of [LoansService.payInstalment]. Lets the caller
/// distinguish "counter bumped but debit skipped" from "everything worked"
/// so the UI can surface the actual reason nothing shows in Expenses.
class PayInstalmentResult {
  final bool debited;             // did we actually write account+txn?
  final String? debitError;       // reason we didn't
  final String? debitAccountId;   // which account got debited
  final int accountsSeen;         // how many docs under customer/accounts
  final int activeAccountsSeen;   // how many had status == "active"
  final bool counterBumped;       // did paid_instalments increment?
  final String? counterError;

  const PayInstalmentResult({
    required this.debited,
    required this.accountsSeen,
    required this.activeAccountsSeen,
    required this.counterBumped,
    this.debitError,
    this.debitAccountId,
    this.counterError,
  });

  /// One-line human summary, safe to drop into a snackbar.
  String get summary {
    if (debited && counterBumped) {
      return 'Debited $debitAccountId, transaction written, counter bumped';
    }
    final parts = <String>[];
    if (!debited) parts.add('DEBIT SKIPPED: ${debitError ?? "unknown"}');
    if (!counterBumped) parts.add('counter NOT bumped: ${counterError ?? "loan doc missing"}');
    return parts.join(' · ');
  }
}
