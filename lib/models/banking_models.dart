class CustomerProfile {
  final String customerId;
  final String displayName;
  final String? email;
  final String? accountNumber;
  final bool found;
  final bool hasCard;
  final CardModel? cardInfo;

  CustomerProfile({
    required this.customerId,
    required this.displayName,
    this.email,
    this.accountNumber,
    required this.found,
    this.hasCard = false,
    this.cardInfo,
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
    );
  }
}

class HomeData {
  final CustomerProfile customer;
  final Map<String, dynamic>? latestApplication;
  final CardModel? latestCard;
  final Map<String, dynamic>? latestNotification;
  final List<Map<String, dynamic>> pendingActions;
  final Map<String, dynamic> summary;

  HomeData({
    required this.customer,
    this.latestApplication,
    this.latestCard,
    this.latestNotification,
    required this.pendingActions,
    required this.summary,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      customer: CustomerProfile.fromJson(json['customer']),
      latestApplication: json['latest_application'],
      latestCard: json['latest_card'] != null ? CardModel.fromJson(json['latest_card']) : null,
      latestNotification: json['latest_notification'],
      pendingActions: List<Map<String, dynamic>>.from(json['pending_actions'] ?? []),
      summary: Map<String, dynamic>.from(json['summary'] ?? {}),
    );
  }
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
