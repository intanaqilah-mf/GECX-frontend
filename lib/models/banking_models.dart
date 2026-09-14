import 'dart:convert';

class CustomerProfile {
  final String customerId;
  final String displayName;
  final String? email;
  final String? accountNumber;
  final bool found;
  final bool hasCard;
  final CardModel? cardInfo;
  /// ACN QR Pay opt-in flag. Defaults to true when the field is absent from
  /// the /home payload so the demo works even before seedQrFields.mjs has
  /// run. Set qr_enabled: false on the customer doc to hide MyQr entirely.
  final bool qrEnabled;

  CustomerProfile({
    required this.customerId,
    required this.displayName,
    this.email,
    this.accountNumber,
    required this.found,
    this.hasCard = false,
    this.cardInfo,
    this.qrEnabled = true,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      customerId: json['customer_id'] ?? '',
      displayName: json['display_name'] ?? 'Customer',
      email: json['email'],
      accountNumber: json['account_number'],
      found: json['found'] ?? false,
      hasCard: json['has_card'] ?? false,
      cardInfo: json['card_info'] != null ? CardModel.fromJson(json['card_info']) : null,
      // Explicit false hides QR; anything else (true, null, missing) enables.
      qrEnabled: json['qr_enabled'] != false,
    );
  }
}

class CardModel {
  final String cardId;
  final String? applicationId;
  final String? customerId;
  final String status;
  final String? cardNumber;
  final String? cardHolderName;
  final String? expiryDate;
  final String? cardType;
  final String? creditLimit;
  final double spendingLimit;
  final double spentAmount;
  final String cvv;
  final String? statementBillDate;
  final double lastStatementBalance;
  final String? deepLink;

  CardModel({
    required this.cardId,
    this.applicationId,
    this.customerId,
    required this.status,
    this.cardNumber,
    this.cardHolderName,
    this.expiryDate,
    this.cardType,
    this.creditLimit,
    this.spendingLimit = 0.0,
    this.spentAmount = 0.0,
    this.cvv = '•••',
    this.statementBillDate,
    this.lastStatementBalance = 0.0,
    this.deepLink,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      cardId: json['card_id'] ?? '',
      applicationId: json['application_id'],
      customerId: json['customer_id'],
      status: json['status'] ?? 'unknown',
      cardNumber: json['card_number'] ?? '•••• •••• •••• ••••',
      cardHolderName: json['card_holder_name'] ?? 'Card Holder',
      expiryDate: json['expiry_date'] ?? 'MM/YY',
      cardType: json['card_type'] ?? 'Visa Platinum',
      creditLimit: json['credit_limit']?.toString() ?? '0',
      spendingLimit: (json['spending_limit'] ?? 0.0).toDouble(),
      spentAmount: (json['spent_amount'] ?? 0.0).toDouble(),
      cvv: json['cvv'] ?? '•••',
      statementBillDate: json['statement_bill_date'],
      lastStatementBalance: (json['last_statement_balance'] ?? 0.0).toDouble(),
      deepLink: json['deep_link'],
    );
  }
}

class HomeData {
  final CustomerProfile customer;
  final Map<String, dynamic>? latestApplication;
  final CardModel? latestCard;
  final Map<String, dynamic>? latestNotification;
  final List<Map<String, dynamic>> pendingActions;
  final List<Map<String, dynamic>> preApprovedOffers;
  final Map<String, dynamic> summary;

  HomeData({
    required this.customer,
    this.latestApplication,
    this.latestCard,
    this.latestNotification,
    required this.pendingActions,
    this.preApprovedOffers = const [],
    required this.summary,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      customer: CustomerProfile.fromJson(json['customer']),
      latestApplication: json['latest_application'],
      latestCard: json['latest_card'] != null ? CardModel.fromJson(json['latest_card']) : null,
      latestNotification: json['latest_notification'],
      pendingActions: List<Map<String, dynamic>>.from(json['pending_actions'] ?? []),
      preApprovedOffers:
          List<Map<String, dynamic>>.from(json['pre_approved_offers'] ?? []),
      summary: Map<String, dynamic>.from(json['summary'] ?? {}),
    );
  }
}

/// One EPP or mortgage draft/active loan.
///
/// Populated from the `loan_applications/{id}` Firestore document that the
/// CES agent's `create_loan_application` tool writes at the end of the
/// webchat flow. The `payloadSnapshot` string is the JSON-encoded draft the
/// agent handed off — LoanReviewScreen parses it to render product/property
/// details without needing to know either flow's shape statically.
class LoanModel {
  final String loanApplicationId;
  final String loanKind; // 'epp' | 'mortgage'
  final String status;   // draft | submitted | approved | active | cancelled | referred
  final String verdict;  // pre_approved | needs_review | not_eligible
  final bool isProvisional;
  final double monthlyPaymentCad;
  final double principalCad;
  final String tenureLabel;
  final double interestRatePct;
  final String customerId;
  final String? productName;
  final String? productImageUrl;
  final Map<String, dynamic> payloadSnapshot;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LoanModel({
    required this.loanApplicationId,
    required this.loanKind,
    required this.status,
    this.verdict = '',
    this.isProvisional = true,
    this.monthlyPaymentCad = 0,
    this.principalCad = 0,
    this.tenureLabel = '',
    this.interestRatePct = 0,
    this.customerId = '',
    this.productName,
    this.productImageUrl,
    this.payloadSnapshot = const {},
    this.createdAt,
    this.updatedAt,
  });

  bool get isEpp => loanKind == 'epp';
  bool get isMortgage => loanKind == 'mortgage';

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    dynamic snapshot = json['payload_snapshot'];
    Map<String, dynamic> snapMap = const {};
    if (snapshot is String && snapshot.isNotEmpty) {
      try {
        final decoded = jsonDecode(snapshot);
        if (decoded is Map) {
          snapMap = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    } else if (snapshot is Map) {
      snapMap = Map<String, dynamic>.from(snapshot);
    }

    // Pull product name/image from the EPP snapshot when available.
    String? productName;
    String? productImageUrl;
    if (snapMap['epp'] is Map) {
      final epp = Map<String, dynamic>.from(snapMap['epp']);
      productName = epp['product_name'] as String?;
      productImageUrl = epp['product_image_url'] as String?;
    }

    return LoanModel(
      loanApplicationId: (json['loan_application_id'] ?? '') as String,
      loanKind: ((json['loan_kind'] ?? '') as String).toLowerCase(),
      status: ((json['status'] ?? 'draft') as String).toLowerCase(),
      verdict: (json['verdict'] ?? '') as String,
      isProvisional: json['is_provisional'] == true,
      monthlyPaymentCad: (json['monthly_payment_cad'] ?? 0).toDouble(),
      principalCad: (json['principal_cad'] ?? 0).toDouble(),
      tenureLabel: (json['tenure_label'] ?? '') as String,
      interestRatePct: (json['interest_rate_pct'] ?? 0).toDouble(),
      customerId: (json['customer_id'] ?? '') as String,
      productName: productName,
      productImageUrl: productImageUrl,
      payloadSnapshot: snapMap,
      createdAt: _parseIso(json['created_at']),
      updatedAt: _parseIso(json['updated_at']),
    );
  }
}

DateTime? _parseIso(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

class ActivityModel {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final String date;
  final String category;

  ActivityModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.category,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Transaction',
      subtitle: json['subtitle'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      date: json['date'] ?? '',
      category: json['category'] ?? 'General',
    );
  }
}
