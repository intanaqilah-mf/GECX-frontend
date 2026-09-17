import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'account_events.dart';

/// Structured result of a successful QR payment. Passed to the receipt
/// screen so the layout can render every row without extra fetches.
class QrPaymentResult {
  final String referenceId;      // e.g. QR-A3F91C — shown as "Reference ID"
  final String recipientName;
  final String recipientCustomerId;
  final String? recipientAccountId;
  final double amount;
  final String currency;
  final DateTime timestamp;
  final double? senderNewBalance;

  QrPaymentResult({
    required this.referenceId,
    required this.recipientName,
    required this.recipientCustomerId,
    required this.recipientAccountId,
    required this.amount,
    required this.currency,
    required this.timestamp,
    required this.senderNewBalance,
  });
}

/// Thrown by [QrPaymentService.submit] with a customer-facing message the
/// pay sheet can display in a snackbar / inline error card.
class QrPaymentException implements Exception {
  final String message;
  QrPaymentException(this.message);
  @override
  String toString() => message;
}

/// Client-side ACN QR Pay executor. Writes debit + credit to Firestore
/// directly (bypasses the CES chat overlay so we can show a native receipt
/// screen). Mirrors the same steps the Fund Transfer Agent runs on the
/// server side — recipient existence check, balance validation, debit,
/// credit, txn rows — so the receipt the user sees matches what the CES
/// flow would have produced.
///
/// SECURITY NOTE: this trusts the client to enforce balance / limit rules,
/// which is fine for a demo. Production would keep the write in a Cloud
/// Function or the existing CES agent path so the check is server-authoritative.
class QrPaymentService {
  QrPaymentService._();
  static final QrPaymentService instance = QrPaymentService._();

  /// The named Firestore database the whole app writes into. Matches the
  /// web app's `getFirestore(app, 'acn-bank-fs-db')` binding.
  static const String _databaseId = 'acn-bank-fs-db';

  FirebaseFirestore get _db =>
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: _databaseId);

  /// Lazy anon sign-in. Same pattern the web app uses to satisfy Firestore
  /// rules that require `request.auth != null` on reads / writes.
  Future<void> _ensureAuth() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  /// Runs the payment end-to-end. Throws [QrPaymentException] on any user-
  /// facing failure — the sheet catches it and shows the message.
  Future<QrPaymentResult> submit({
    required String senderCustomerId,
    required String recipientCustomerId,
    required String recipientDisplayName,
    required double amount,
    String currency = 'CAD',
  }) async {
    if (amount <= 0) throw QrPaymentException('Amount must be greater than 0.');
    if (senderCustomerId == recipientCustomerId) {
      throw QrPaymentException("You can't send money to yourself.");
    }

    await _ensureAuth();

    // 1) Sender's first active account (prefer CHQ-*). This mirrors the CES
    //    agent's Collect From Account step for a single-account customer.
    final senderAcc = await _pickActiveAccount(senderCustomerId);
    if (senderAcc == null) {
      throw QrPaymentException('No active account on your profile.');
    }
    final senderBalance = (senderAcc['balance'] ?? 0).toDouble();
    final senderAccountId = senderAcc['account_id'] as String;

    if (amount > senderBalance) {
      throw QrPaymentException(
          'Insufficient funds. Available: $currency ${senderBalance.toStringAsFixed(2)}.');
    }

    // 2) Recipient existence + first active account.
    final recipAcc = await _pickActiveAccount(recipientCustomerId);
    if (recipAcc == null) {
      throw QrPaymentException(
          "We couldn't find an ACN Bank account for that QR code.");
    }
    final recipBalance = (recipAcc['balance'] ?? 0).toDouble();
    final recipAccountId = recipAcc['account_id'] as String;

    // 3) Generate a single reference number used for both legs so the debit
    //    and credit rows are joinable (credit uses "<ref>-C").
    final referenceId = _newReferenceId();
    final now = DateTime.now();
    final ts = now.toUtc().toIso8601String();

    // 4) Debit sender — update account balance + write debit txn.
    final senderNewBalance = senderBalance - amount;
    final senderAccRef = _db
        .collection('customers')
        .doc(senderCustomerId)
        .collection('accounts')
        .doc(senderAccountId);
    final senderTxnRef = _db
        .collection('customers')
        .doc(senderCustomerId)
        .collection('transactions')
        .doc(referenceId);

    // Batch the two sender writes so a partial state can't happen on the
    // debit side. (Cross-customer batches are still separate — Firestore
    // batches can span docs but a rules failure on one still rolls back
    // the whole batch.)
    final senderBatch = _db.batch();
    senderBatch.set(senderAccRef, {
      'balance': senderNewBalance,
      'updated_at': ts,
    }, SetOptions(merge: true));
    senderBatch.set(senderTxnRef, {
      'transaction_id': referenceId,
      'account_id': senderAccountId,
      'customer_id': senderCustomerId,
      'type': 'debit',
      'category': 'qr_transfer',
      'amount': amount,
      'currency': currency,
      'description': 'ACN QR Pay to $recipientDisplayName',
      'counterparty_name': recipientDisplayName,
      'counterparty_customer_id': recipientCustomerId,
      'balance_after': senderNewBalance,
      'reference_no': referenceId,
      'channel': 'acn_qr_pay',
      'timestamp': ts,
    });
    await senderBatch.commit();

    // 5) Credit recipient — best-effort. A failure here doesn't roll back
    //    the sender debit (matches the Fund Transfer Agent's 9b comment);
    //    reconciliation happens out-of-band via reference_no.
    try {
      final recipNewBalance = recipBalance + amount;
      final recipBatch = _db.batch();
      recipBatch.set(
        _db
            .collection('customers')
            .doc(recipientCustomerId)
            .collection('accounts')
            .doc(recipAccountId),
        {'balance': recipNewBalance, 'updated_at': ts},
        SetOptions(merge: true),
      );
      recipBatch.set(
        _db
            .collection('customers')
            .doc(recipientCustomerId)
            .collection('transactions')
            .doc('$referenceId-C'),
        {
          'transaction_id': '$referenceId-C',
          'account_id': recipAccountId,
          'customer_id': recipientCustomerId,
          'type': 'credit',
          'category': 'qr_transfer',
          'amount': amount,
          'currency': currency,
          'description': 'ACN QR Pay from customer $senderCustomerId',
          'counterparty_name': senderCustomerId,
          'counterparty_customer_id': senderCustomerId,
          'balance_after': recipNewBalance,
          'reference_no': referenceId,
          'channel': 'acn_qr_pay',
          'timestamp': ts,
        },
      );
      await recipBatch.commit();
    } catch (e) {
      // Do NOT rethrow — sender's already been debited and the receipt
      // still needs to render. Surface via console; a real deployment would
      // push this to Crashlytics / a reconciliation queue.
      // ignore: avoid_print
      print('[QrPayment] credit-side write failed (ref=$referenceId): $e');
    }

    // Notify listeners (Home + Accounts screens) so they invalidate their
    // cached HomeData snapshot and re-fetch the fresh balance.
    AccountEvents.instance.notifyBalanceChanged();

    return QrPaymentResult(
      referenceId: referenceId,
      recipientName: recipientDisplayName,
      recipientCustomerId: recipientCustomerId,
      recipientAccountId: recipAccountId,
      amount: amount,
      currency: currency,
      timestamp: now,
      senderNewBalance: senderNewBalance,
    );
  }

  /// Returns the first active account for a customer as a plain map with
  /// `account_id` + `balance`. Prefers CHQ-* accounts so the demo behaves
  /// like the seed script's `default_receive_account` even when the seed
  /// hasn't run.
  Future<Map<String, dynamic>?> _pickActiveAccount(String customerId) async {
    final snap = await _db
        .collection('customers')
        .doc(customerId)
        .collection('accounts')
        .get();
    if (snap.docs.isEmpty) return null;

    Map<String, dynamic>? active;
    Map<String, dynamic>? activeChq;
    for (final d in snap.docs) {
      final data = Map<String, dynamic>.from(d.data());
      // Some seed data stores the account_id in the field and uses the doc id
      // as a mirror. Fall back to the doc id if the field is missing.
      data['account_id'] ??= d.id;
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status != 'active') continue;
      active ??= data;
      if ((data['account_id'] as String).startsWith('CHQ-')) {
        activeChq ??= data;
      }
    }
    return activeChq ?? active;
  }

  static String _newReferenceId() {
    // "QR-" + 6 hex chars keeps this visually distinct from TXN-/PMT- refs
    // written by the CES agents. Matches execute_qr_transfer's format so
    // receipts look the same regardless of which side moved the money.
    final r = Random.secure();
    final buf = StringBuffer('QR-');
    for (var i = 0; i < 6; i++) {
      buf.write(r.nextInt(16).toRadixString(16).toUpperCase());
    }
    return buf.toString();
  }
}
