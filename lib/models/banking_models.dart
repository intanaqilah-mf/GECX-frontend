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

  /// Total number of installments derived from the payload snapshot.
  /// EPP uses `tenure_months`; mortgage uses `tenure_years * 12`. Falls
  /// back to parsing digits out of [tenureLabel] so a doc missing the
  /// nested numeric field still yields something usable.
  int get tenureMonths {
    if (isEpp) {
      final v = (payloadSnapshot['epp'] is Map)
          ? (payloadSnapshot['epp']['tenure_months'] as num?)?.toInt()
          : null;
      if (v != null && v > 0) return v;
    } else if (isMortgage) {
      final v = (payloadSnapshot['mortgage'] is Map)
          ? (payloadSnapshot['mortgage']['tenure_years'] as num?)?.toInt()
          : null;
      if (v != null && v > 0) return v * 12;
    }
    final m = RegExp(r'(\d+)').firstMatch(tenureLabel);
    return m == null ? 0 : (int.tryParse(m.group(1) ?? '0') ?? 0);
  }

  /// How many installments have been marked paid. Written by
  /// [LoansService.payInstalment]. Absent → 0.
  int get paidInstalments {
    final top = payloadSnapshot['paid_instalments'];
    if (top is num) return top.toInt();
    return 0;
  }

  /// Interest total (order amount * rate). This mirrors the "Installment
  /// Rate" row on the reference receipt — a single "total interest" number,
  /// not per-instalment interest.
  double get interestCad =>
      double.parse((principalCad * interestRatePct / 100.0)
          .toStringAsFixed(2));

  /// Principal + interest — the "Total payable" row.
  double get totalRepayableCad {
    final v = (payloadSnapshot['epp'] is Map)
        ? (payloadSnapshot['epp']['total_repayable_cad'] as num?)?.toDouble()
        : null;
    if (v != null && v > 0) return v;
    return double.parse((principalCad + interestCad).toStringAsFixed(2));
  }

  /// Computed schedule — one row per installment, past or future. Uses
  /// [createdAt] as the origin (first installment) and adds one month per
  /// row. Marks the first [paidInstalments] as paid.
  List<LoanInstalment> get schedule {
    final start = createdAt ?? DateTime.now();
    final n = tenureMonths;
    final double amt = monthlyPaymentCad > 0
        ? monthlyPaymentCad
        : (n > 0 ? totalRepayableCad / n : 0.0);
    final paid = paidInstalments.clamp(0, n);
    return List.generate(n, (i) {
      // Simple month math — clamp day-of-month to end of target month so
      // Jan 31 → Feb 28 doesn't spill into March.
      final due = DateTime(start.year, start.month + i, start.day);
      return LoanInstalment(
        index: i + 1,
        dueDate: due,
        amount: amt,
        paid: i < paid,
      );
    });
  }

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
    // CES's create_loan_application often writes a stub doc where only
    // status / kind / customer_id live at the top and the real numbers
    // (monthly, principal, rate, tenure_months) live inside the nested
    // payload_snapshot map. Extract those as fallbacks so the review
    // screen doesn't show CAD 0.00 when the top-level fields are absent.
    Map<String, dynamic>? nested;
    if (snapMap['epp'] is Map) {
      nested = Map<String, dynamic>.from(snapMap['epp']);
    } else if (snapMap['mortgage'] is Map) {
      nested = Map<String, dynamic>.from(snapMap['mortgage']);
    }

    double pickNum(String topKey, List<String> nestedKeys) {
      final t = (json[topKey] as num?)?.toDouble() ?? 0.0;
      if (t > 0) return t;
      if (nested == null) return 0.0;
      for (final k in nestedKeys) {
        final v = nested[k];
        if (v is num && v > 0) return v.toDouble();
      }
      return 0.0;
    }

    String? productName;
    String? productImageUrl;
    if (snapMap['epp'] is Map) {
      final epp = Map<String, dynamic>.from(snapMap['epp']);
      productName = epp['product_name'] as String?;
      productImageUrl = epp['product_image_url'] as String?;
    }

    // Tenure label — try top-level, else synthesize from nested tenure_months
    // (EPP) or tenure_years (mortgage) so the "24 months" text populates.
    String tenureLabel = (json['tenure_label'] ?? '') as String;
    if (tenureLabel.isEmpty && nested != null) {
      if (snapMap['epp'] is Map && nested['tenure_months'] is num) {
        tenureLabel = '${(nested['tenure_months'] as num).toInt()} months';
      } else if (snapMap['mortgage'] is Map && nested['tenure_years'] is num) {
        tenureLabel = '${(nested['tenure_years'] as num).toInt()} years';
      }
    }

    return LoanModel(
      loanApplicationId: (json['loan_application_id'] ?? '') as String,
      loanKind: ((json['loan_kind'] ?? snapMap['loan_kind'] ?? '') as String)
          .toLowerCase(),
      status: ((json['status'] ?? 'draft') as String).toLowerCase(),
      verdict: (json['verdict'] ?? '') as String,
      isProvisional: json['is_provisional'] == true,
      monthlyPaymentCad:
          pickNum('monthly_payment_cad', const ['monthly_amount_cad', 'monthly_payment_cad']),
      principalCad:
          pickNum('principal_cad', const ['retail_price_cad', 'loan_principal_cad']),
      tenureLabel: tenureLabel,
      interestRatePct: pickNum('interest_rate_pct', const ['interest_rate_pct']),
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

/// One row on the Pay-in-N schedule shown by LoanBillingDetailScreen.
class LoanInstalment {
  final int index;
  final DateTime dueDate;
  final double amount;
  final bool paid;
  const LoanInstalment({
    required this.index,
    required this.dueDate,
    required this.amount,
    required this.paid,
  });
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
