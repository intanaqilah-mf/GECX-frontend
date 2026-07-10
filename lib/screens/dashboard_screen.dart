import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/banking_models.dart';
import '../services/api_service.dart';
import 'card_activation_screen.dart';
import '../main.dart';

class DashboardScreen extends StatefulWidget {
  final String customerId;
  const DashboardScreen({super.key, required this.customerId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<HomeData> _homeDataFuture;
  bool _isAiExpanded = false;
  final List<Map<String, String>> _chatMessages = [
    {'role': 'assistant', 'content': 'Hi! I\'m your ACN Bank AI assistant. How can I help you today?'}
  ];
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _homeDataFuture = _apiService.getHomeData(widget.customerId);
    });
  }

  Widget _buildAIButton(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isAiExpanded = true),
      child: Container(
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0), Color(0xFF00D2FF)],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            color: const Color(0xFF1a2744).withValues(alpha: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'Ask ACN Bank',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSendMessage() {
    if (_chatController.text.trim().isEmpty) return;
    setState(() {
      _chatMessages.add({'role': 'user', 'content': _chatController.text});
      _chatController.clear();
      // Simulate AI response
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _chatMessages.add({
              'role': 'assistant',
              'content': 'I\'m working on that. I can help you with transfers, balance checks, and more!'
            });
          });
        }
      });
    });
  }

  Widget _buildAiExpandedSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutQuart,
      height: _isAiExpanded ? 750 : 0,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0f172a), Color(0xFF1e1b4b), Color(0xFF312e81), Color(0xFF4c1d95)],
        ),
      ),
      child: Column(
        children: [
          // Header within expansion
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _isAiExpanded = false),
                ),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'ACN Bank',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'beta',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  if (_chatMessages.length <= 1) ...[
                    Text(
                      'How can I help you?',
                      style: GoogleFonts.dmSerifDisplay(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.5,
                      children: [
                        _buildSuggestionItem(Icons.auto_awesome_outlined, 'What ACN Bank can do?'),
                        _buildSuggestionItem(Icons.phone_android, 'Pay via screens'),
                        _buildSuggestionItem(Icons.arrow_outward, 'Pay @someone'),
                        _buildSuggestionItem(Icons.file_copy_outlined, 'Upload file and pay'),
                        _buildSuggestionItem(Icons.camera_alt_outlined, 'Snap and pay'),
                        _buildSuggestionItem(Icons.history, 'Show latest transfers'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Learn how to use ACN Bank AI',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, color: Colors.white70, size: 14),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Chat Messages Area
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _chatMessages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF4A00E0).withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isUser ? const Radius.circular(0) : null,
                              bottomLeft: !isUser ? const Radius.circular(0) : null,
                            ),
                          ),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                          child: Text(
                            msg['content']!,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_chatMessages.length <= 1)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.card_giftcard, color: Colors.purple),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ACN Bank REFERRAL',
                                    style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Transfer with ACN Bank, get rewards',
                                    style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const Icon(Icons.close, color: Colors.white54, size: 16),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          style: GoogleFonts.inter(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Ask ACN Bank',
                            hintStyle: GoogleFonts.inter(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _handleSendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white70, size: 20),
                        onPressed: _handleSendMessage,
                      ),
                      const Icon(Icons.add, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      const Icon(Icons.image_outlined, color: Colors.white70, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '100% Malaysian made 🇲🇾 In partnership with YTL AI Labs.',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.keyboard_arrow_up, color: Colors.white38),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
      future: _homeDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${snapshot.error}'),
                ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
              ],
            ),
          );
        } else if (!snapshot.hasData) {
          return const Center(child: Text('No data found'));
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _refreshData(),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 1,
                automaticallyImplyLeading: false,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0f172a), Color(0xFF1e40af), Color(0xFF7e22ce)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                leading: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Center(
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      child: Text(
                        data.customer.displayName.isNotEmpty
                            ? data.customer.displayName.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                centerTitle: true,
                title: _isAiExpanded ? null : _buildAIButton(context),
                actions: [
                  if (!_isAiExpanded)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                          onPressed: () {},
                        ),
                        if (data.summary['total_notifications'] > 0)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverToBoxAdapter(
                child: _buildAiExpandedSection(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildBalanceCard(),
                    const SizedBox(height: 12),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    if (data.summary['has_card_ready_for_activation'] == true)
                      _buildActivationBanner(context, data.latestCard?.cardId),
                    const SizedBox(height: 24),
                    if (data.latestCard != null) _buildCardSection(data.latestCard!),
                    const SizedBox(height: 24),
                    _buildTransactions(),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Net Worth',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('\$142,560.00',
                  style: GoogleFonts.inter(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _balanceTile('Checking', '\$12,450.00')),
                  const SizedBox(width: 12),
                  Expanded(child: _balanceTile('Savings', '\$130,110.00')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceTile(String label, String amount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(amount,
              style: GoogleFonts.inter(
                  fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    const actions = [
      (Icons.send_outlined, 'Send'),
      (Icons.payments_outlined, 'Pay'),
      (Icons.account_balance_wallet_outlined, 'Deposit'),
      (Icons.more_horiz, 'More'),
    ];
    return Row(
      children: actions
          .map((a) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Icon(a.$1, color: AppColors.secondary, size: 22),
                            const SizedBox(height: 4),
                            Text(a.$2,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildActivationBanner(BuildContext context, String? cardId) {
    return GestureDetector(
      onTap: () {
        if (cardId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CardActivationScreen(cardId: cardId),
            ),
          ).then((_) => _refreshData());
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF001b3d), Color(0xFF115cb9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Credit Card is Approved!',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Start using your virtual card now.',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Activate Card',
                        style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.credit_card, color: Colors.white38, size: 56),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSection(CardModel card) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your New Card',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                Text(card.status == 'active' ? 'Active and ready' : 'Pending Activation',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.onSurfaceVariant)),
              ],
            ),
            TextButton(
              onPressed: () => MainShell.of(context)?.setIndex(2),
              child: Text('View Details',
                  style: GoogleFonts.inter(
                      color: AppColors.secondary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)
            ],
          ),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1.58,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1a2744), Color(0xFF000a1e), Color(0xFF1a3060)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('VISA',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 18,
                                  letterSpacing: 2)),
                          const Icon(Icons.contactless, color: Colors.white70),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.cardType ?? 'Platinum Member',
                              style: GoogleFonts.inter(
                                  color: Colors.white54, fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(card.cardNumber ?? '•••• •••• •••• 8842',
                              style: GoogleFonts.robotoMono(
                                  color: Colors.white,
                                  fontSize: 15,
                                  letterSpacing: 3)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(card.cardHolderName ?? 'ALEXANDER NEWMAN',
                                  style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Exp',
                                      style: GoogleFonts.inter(
                                          color: Colors.white54, fontSize: 9)),
                                  Text(card.expiryDate ?? '08/28',
                                      style: GoogleFonts.inter(
                                          color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Limit',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.onSurfaceVariant)),
                        Text('\$${card.spendingLimit.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Spent',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.onSurfaceVariant)),
                        Text('\$${card.spentAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (card.spendingLimit > 0) ? (card.spentAmount / card.spendingLimit) : 0.0,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => MainShell.of(context)?.setIndex(2),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text('Manage Card',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.lock_outline,
                          color: AppColors.onSurfaceVariant),
                      onPressed: () {},
                      iconSize: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactions() {
    const txns = [
      (Icons.shopping_cart_outlined, 'Apple Store', 'Today, 2:45 PM', '-\$1,299.00', 'Electronics', true),
      (Icons.coffee_outlined, 'Starbucks', 'Yesterday, 9:12 AM', '-\$6.45', 'Dining', true),
      (Icons.local_shipping_outlined, 'Amazon.com', 'Oct 24, 2023', '-\$42.10', 'Shopping', true),
      (Icons.account_balance_outlined, 'Monthly Salary', 'Oct 20, 2023', '+\$8,500.00', 'Deposit', false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Transactions',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
            TextButton(
              onPressed: () {},
              child: Text('View All',
                  style: GoogleFonts.inter(
                      color: AppColors.secondary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: txns.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1, color: AppColors.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: t.$6
                                ? AppColors.surfaceContainerHigh
                                : AppColors.secondaryContainer.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(t.$1, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.$2,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                              Text(t.$3,
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(t.$4,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: t.$6
                                        ? AppColors.error
                                        : AppColors.secondary)),
                            Text(t.$5,
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
