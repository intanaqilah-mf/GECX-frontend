class CustomerProfile {
  final String customerId;
  final String displayName;
  final String? email;
  final String? accountNumber;
  final bool found;

  CustomerProfile({
    required this.customerId,
    required this.displayName,
    this.email,
    this.accountNumber,
    required this.found,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      customerId: json['customer_id'] ?? '',
      displayName: json['display_name'] ?? 'Customer',
      email: json['email'],
      accountNumber: json['account_number'],
      found: json['found'] ?? false,
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
