import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/banking_models.dart';

/// Rich result from [TransactionsService.fetchCustomerActivity]. Keeps the
/// list AND any surfaced error string, so callers can distinguish "empty
/// because nothing to show" from "empty because the read failed".
class CustomerActivityResult {
  final List<ActivityModel> transactions;
  final String? error;   // human-readable Firestore / network error
  final int rawCount;    // raw doc count before filtering, for debug UI

  const CustomerActivityResult({
    required this.transactions,
    this.error,
    required this.rawCount,
  });

  bool get failed => error != null;
}

/// Read-side companion to [QrPaymentService]. Fetches transaction docs from
/// `customers/{id}/transactions` so surfaces like Expenses can see QR
/// payments + loan instalments (neither of which are on a card, so the
/// existing `/cards/{id}/activity` gateway endpoint doesn't return them).
class TransactionsService {
  TransactionsService._();
  static final TransactionsService instance = TransactionsService._();

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

  /// One-shot Firestore probe. Writes a doc under
  /// customers/{cid}/transactions/, then immediately reads it back three
  /// ways so we can pinpoint what's silently failing:
  ///   • direct GET on the doc we just wrote
  ///   • LIST on the collection
  ///   • GET on the parent customer doc (proves the DB / project is right)
  ///
  /// Returns a multi-line human-readable report that a diagnostic UI can
  /// paste into an AlertDialog verbatim.
  Future<String> selfTest(String customerId) async {
    final lines = <String>[];
    lines.add('Database ID: $_databaseId');
    lines.add('Project ID: ${Firebase.app().options.projectId}');
    lines.add('Customer:   $customerId');
    try {
      await _ensureAuth();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      lines.add('Auth UID:   $uid');
    } catch (e) {
      lines.add('Auth FAILED: $e');
      return lines.join('\n');
    }

    final probeId =
        'PROBE-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final ref = _db
        .collection('customers')
        .doc(customerId)
        .collection('transactions')
        .doc(probeId);

    // Write.
    try {
      await ref.set({
        'transaction_id': probeId,
        'type': 'debit',
        'category': 'probe',
        'amount': 0.01,
        'currency': 'CAD',
        'description': 'Self-test probe',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      lines.add('WRITE ok → $probeId');
    } catch (e) {
      lines.add('WRITE FAILED: $e');
      return lines.join('\n');
    }

    // Direct get.
    try {
      final direct = await ref.get();
      lines.add('DIRECT GET: exists=${direct.exists}');
    } catch (e) {
      lines.add('DIRECT GET FAILED: $e');
    }

    // List parent.
    try {
      final list = await _db
          .collection('customers')
          .doc(customerId)
          .collection('transactions')
          .get();
      lines.add('LIST: ${list.docs.length} docs');
      for (final d in list.docs.take(5)) {
        lines.add('  • ${d.id}');
      }
    } catch (e) {
      lines.add('LIST FAILED: $e');
    }

    // Customer parent existence.
    try {
      final parent =
          await _db.collection('customers').doc(customerId).get();
      lines.add('Parent customer doc exists=${parent.exists}');
    } catch (e) {
      lines.add('Parent GET FAILED: $e');
    }

    return lines.join('\n');
  }

  /// Returns all transactions on this customer, converted to the app's
  /// existing [ActivityModel] so Expenses can bucket them alongside card
  /// spend. Debits are returned as negative amounts (matches card activity's
  /// sign convention).
  ///
  /// Errors are captured in the result's `error` field instead of throwing —
  /// Expenses uses this to show "Couldn't load transactions: <reason>" so a
  /// permission-denied doesn't look like "no spending yet".
  Future<CustomerActivityResult> fetchCustomerActivity(String customerId) async {
    if (customerId.isEmpty) {
      return const CustomerActivityResult(transactions: [], rawCount: 0);
    }
    try {
      await _ensureAuth();
      final snap = await _db
          .collection('customers')
          .doc(customerId)
          .collection('transactions')
          .get();

      final list = <ActivityModel>[];
      for (final d in snap.docs) {
        final data = d.data();
        final type = (data['type'] ?? '').toString().toLowerCase();
        final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
        // Match card activity's sign convention: debits negative, credits
        // positive. Expenses._ExpensesState.from filters positives out of
        // the spending total but still counts them in the row count.
        final signed = type == 'credit' ? amt : -amt;
        final ts = (data['timestamp'] ?? '').toString();

        list.add(ActivityModel(
          id: d.id,
          title: (data['description'] ?? 'Transaction').toString(),
          subtitle: (data['counterparty_name'] ?? '').toString(),
          amount: signed,
          date: ts.isEmpty ? '' : ts.substring(0, ts.length.clamp(0, 10)),
          category: (data['category'] ?? 'other').toString(),
        ));
      }
      // ignore: avoid_print
      print('[TransactionsService] fetched ${list.length} txns for $customerId');
      return CustomerActivityResult(
        transactions: list,
        rawCount: snap.docs.length,
      );
    } catch (e) {
      final msg = e.toString();
      // ignore: avoid_print
      print('[TransactionsService] fetchCustomerActivity failed: $msg');
      return CustomerActivityResult(
        transactions: const [],
        error: msg,
        rawCount: 0,
      );
    }
  }
}
