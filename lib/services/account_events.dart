import 'package:flutter/foundation.dart';

/// Broadcasts whenever a service moves money on a customer's account so the
/// Home + Accounts screens can invalidate their cached [HomeData] snapshot
/// and re-fetch the balance.
///
/// Kept as a singleton ValueNotifier<int> — the value itself is just a
/// monotonically-increasing counter, listeners re-fetch on any change.
///
/// Fired by:
///   • [QrPaymentService.submit]      after a QR debit / credit lands
///   • [LoansService.payInstalment]    after an EPP / mortgage instalment
class AccountEvents {
  AccountEvents._();
  static final AccountEvents instance = AccountEvents._();

  /// Bumped by any write that changes an account balance. Home + Accounts
  /// wire a listener that calls their own `_refresh()` on change.
  final ValueNotifier<int> balanceRevision = ValueNotifier<int>(0);

  void notifyBalanceChanged() {
    balanceRevision.value = balanceRevision.value + 1;
  }
}
