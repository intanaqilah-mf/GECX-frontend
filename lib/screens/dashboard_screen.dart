import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Platform utilities for Web/Mobile compatibility
import '../services/platform_utils.dart'
    if (dart.library.html) '../services/platform_utils_web.dart';
import '../theme/app_colors.dart';
import '../models/banking_models.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import 'card_activation_screen.dart';
import '../main.dart';

// Runs in a background isolate — rootBundle cannot be called here, only encoding.
List<Map<String, String>> _encodeCardImages(Map<String, Uint8List> byteMap) {
  return byteMap.entries.map((e) => {
    'name': e.key,
    'image_url': 'data:image/png;base64,${base64Encode(e.value)}',
    'description': 'Premium benefits for your lifestyle.',
  }).toList();
}

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
  
  late final WebViewController _webController;
  bool _isWebViewReady = false;
  bool _isPageLoaded = false;
  bool _hasInjectedCards = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
    
    if (kIsWeb) {
      // Register a native iframe factory for Web to avoid 'data:' URL security issues.
      // We use the absolute origin to ensure the browser doesn't treat it as a data URL.
      registerWebViewFactory('acn-chat-iframe', '${Uri.base.origin}/chat.html');
      _isWebViewReady = true;
      _isPageLoaded = true;
    } else {
      _initWebViewController();
    }
  }

  Future<void> _initWebViewController() async {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));

    if (!kIsWeb) {
      _webController.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _isPageLoaded = true;
            if (_isAiExpanded && !_hasInjectedCards) {
              _hasInjectedCards = true;
              _injectCardData();
            }
          },
        ),
      );
      _webController.loadHtmlString(_getMessengerHtml());
    } else {
      _isPageLoaded = true; 
      // On Web, we MUST load from a real URL to enable sessionStorage.
      // We'll construct the absolute URL manually to ensure no 'data:' URL fallback.
      final String origin = Uri.base.origin;
      // Ensure we don't have double slashes if origin ends with /
      final String path = origin.endsWith('/') ? 'chat.html' : '/chat.html';
      final String fullUrl = '$origin$path';
      debugPrint("ACN Web: Loading messenger from $fullUrl");
      _webController.loadRequest(Uri.parse(fullUrl));
    }

    setState(() => _isWebViewReady = true);
  }

  String _getMessengerHtml() {
    return r'''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; background-color: transparent; overflow: hidden; height: 100vh; }
    chat-messenger {
      position: absolute !important;
      top: 0 !important; left: 0 !important;
      width: 100% !important; height: 100% !important;
      --chat-messenger-color--primary: #1e40af;
      --chat-messenger-color--primary-container: #1e40af;
      --chat-messenger-color--on-primary: #ffffff;
      --chat-messenger-color--secondary: #7e22ce;
      --chat-messenger-color--surface: #ffffff;
    }
    chat-messenger-container::part(titlebar) {
      background: linear-gradient(to right, #0f172a, #1e40af, #7e22ce) !important;
    }
  </style>
  <script defer src="https://www.gstatic.com/chat-messenger/sdk/prod/v1.16/chat-messenger.js"></script>
  <link rel="stylesheet" href="https://www.gstatic.com/chat-messenger/sdk/prod/v1.16/themes/chat-messenger-default.css">
  <link rel="stylesheet" href="https://www.gstatic.com/chat-messenger/sdk/prod/v1.16/themes/chat-messenger-layout.css">
</head>
<body>
  <script>
    window.addEventListener("chat-messenger-loaded", () => {
      chatSdk.registerContext(
        chatSdk.prebuilts.ces.createContext({
          deploymentName: "projects/483471568825/locations/us/apps/27be6c70-74dc-4e50-a3e8-25b032e7c965/deployments/7cbb68f9-147f-4698-be02-e7ea5fa5d1a3",
          tokenBroker: { enableTokenBroker: true, enableRecaptcha: false }
        }),
      );
    });
  </script>
  <chat-messenger url-allowlist="*">
    <chat-messenger-container
        chat-title="ACN Bank Assistant"
        chat-title-icon="https://gstatic.com/dialogflow-console/common/assets/ccai-favicons/conversational_agents.png"
        enable-file-upload
        enable-audio-input
    >
      <chat-reset-session-button slot="titlebar-actions" title-text="Start new chat"></chat-reset-session-button>
      <chat-toggle-dialog-button slot="titlebar-actions" title-text-expanded="Collapse" title-text-collapsed="Expand"></chat-toggle-dialog-button>
      <chat-messenger-close-button slot="titlebar-actions" title-text="Close"></chat-messenger-close-button>
    </chat-messenger-container>
  </chat-messenger>
</body>
</html>
''';
  }

  Future<void> _injectCardData() async {
    const cardImages = {
      'Visa Platinum': 'lib/assets/ChatGPT Image May 24, 2026, 06_03_30 PM.png',
      'World Elite Mastercard': 'lib/assets/ChatGPT Image May 24, 2026, 06_05_06 PM.png',
      'Infinite Cashback': 'lib/assets/ChatGPT Image May 24, 2026, 06_06_18 PM.png',
      'Student Rewards': 'lib/assets/ChatGPT Image May 24, 2026, 06_07_55 PM.png',
      'Business Gold': 'lib/assets/ChatGPT Image May 24, 2026, 06_09_25 PM.png',
    };

    // Load raw bytes on the main isolate (rootBundle requires it).
    final Map<String, Uint8List> byteMap = {};
    for (final entry in cardImages.entries) {
      try {
        final data = await rootBundle.load(entry.value);
        byteMap[entry.key] = data.buffer.asUint8List();
      } catch (e) {
        debugPrint("Error loading asset ${entry.value}: $e");
      }
    }

    // base64Encode on ~10 MB of PNG data is CPU-heavy — run it in a background isolate.
    final cards = await compute(_encodeCardImages, byteMap);

    final String jsonCards = jsonEncode(cards);
    await _webController.runJavaScript(
      'window.ACN_AVAILABLE_CARDS = $jsonCards; console.log("ACN Cards injected");',
    );
  }

  void _refreshData() {
    setState(() {
      _homeDataFuture = _apiService.getHomeData(widget.customerId);
    });
  }

  void _openAiChat() {
    setState(() => _isAiExpanded = true);
    // runJavaScript is not implemented in webview_flutter_web 0.2.x
    if (!kIsWeb && _isPageLoaded && !_hasInjectedCards) {
      _hasInjectedCards = true;
      _injectCardData();
    }
  }

  Future<void> _requestNotificationsAndShowToken(BuildContext context) async {
    final token = await FcmService.requestPermissionAndGetToken();
    if (!context.mounted) return;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Notification permission denied. Enable it in your browser site settings.'),
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Your FCM Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this token with your backend developer:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            SelectableText(
              token,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: token));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Token copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAIButton(BuildContext context) {
    return GestureDetector(
      onTap: _openAiChat,
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

  Widget _buildAiExpandedSection() {
    final double screenHeight = MediaQuery.of(context).size.height;
    // Calculate a height that leaves room for the bottom nav but shows the chat clearly
    final double expandedHeight = screenHeight * 0.8; 

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      height: _isAiExpanded ? expandedHeight : 0,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
        ],
      ),
      child: SingleChildScrollView(
        // Prevent internal scroll physics from fighting with the column layout
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          height: expandedHeight,
          child: Column(
            children: [
              // Header
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0f172a), Color(0xFF1e40af), Color(0xFF7e22ce)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _isAiExpanded = false),
                      ),
                      Text(
                        'ACN Bank Assistant',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
              // The Chat Area
              Expanded(
                child: _isWebViewReady 
                  ? (kIsWeb 
                      ? const HtmlElementView(viewType: 'acn-chat-iframe')
                      : WebViewWidget(controller: _webController))
                  : const Center(child: CircularProgressIndicator(color: Colors.blue)),
              ),
            ],
          ),
        ),
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
        return Scaffold(
          body: RefreshIndicator(
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
                            onPressed: () => _requestNotificationsAndShowToken(context),
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
                      if (data.summary['has_card_ready_for_activation'] == true) ...[
                        _buildActivationBanner(context, data.latestCard?.cardId),
                        const SizedBox(height: 24),
                      ],
                      _buildApplicationsSection(data),
                      _buildTransactions(),
                    ]),
                  ),
                ),
              ],
            ),
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
          ).then((_) {
            _refreshData();
            MainShell.of(context)?.refresh();
          });
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



  Widget _buildApplicationsSection(HomeData data) {
    // If user already has an active card, we don't show the tracking section
    // unless they have a NEW application that is not yet fully activated.
    if (data.customer.hasCard && data.summary['total_applications'] == 0) {
      return const SizedBox.shrink();
    }

    if (data.summary['total_applications'] == 0) {
      return _buildNoApplicationCard();
    }

    final app = data.latestApplication;
    if (app == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Applications',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
            TextButton(
              onPressed: () => MainShell.of(context)?.setIndex(2),
              child: Text('View Details',
                  style: GoogleFonts.inter(
                      color: AppColors.secondary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => MainShell.of(context)?.setIndex(2),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_outlined,
                      color: AppColors.secondary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app['selected_product_name'] ?? 'Credit Card Application',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      const SizedBox(height: 2),
                      Text('Status: ${app['status']?.toUpperCase() ?? 'PENDING'}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: app['status'] == 'approved'
                                  ? Colors.green
                                  : AppColors.onSurfaceVariant,
                              fontWeight: app['status'] == 'approved'
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoApplicationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card, color: AppColors.secondary),
              const SizedBox(width: 12),
              Text('Looking for a Card?',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'You haven\'t applied for any credit cards yet. Ask our AI assistant to help you find the best card for your needs.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _openAiChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Ask ACN Bank',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
        const SizedBox(height: 24),
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
