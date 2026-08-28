import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/banking_models.dart';
import '../services/api_service.dart';
import '../services/quick_actions.dart';
import '../theme/app_colors.dart';

/// Apply tab — the narrative anchor for "web app applies, mobile app uses".
///
///  - If the customer already has a card: show status + "explore more products"
///    hand-off to Credit_Cards / Card_Application_Agent.
///  - Otherwise: hero CTA sending them to the acn-bank-demo web app to apply,
///    plus the 6 valid card products (from Card_Application_Agent line 44-49)
///    with tap-to-ask-AI for details.
class ApplyScreen extends StatefulWidget {
  final String customerId;
  const ApplyScreen({super.key, required this.customerId});

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  final _api = ApiService();
  late Future<HomeData> _home;

  @override
  void initState() {
    super.initState();
    _home = _api.getHomeData(widget.customerId);
  }

  Future<void> _refresh() async {
    setState(() => _home = _api.getHomeData(widget.customerId));
    await _home;
  }

  Future<void> _openWebApply() async {
    // acn-bank-demo web app hosts the browse/apply flow.
    final uri = Uri.parse('https://emvnzir-canada-song.web.app/');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: FutureBuilder<HomeData>(
          future: _home,
          builder: (context, snap) {
            final data = snap.data;
            final hasCard = data?.customer.hasCard ?? false;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text('Apply',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface)),
                const SizedBox(height: 4),
                Text(hasCard
                        ? 'Explore more products.'
                        : 'Start your ACN Bank journey.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 20),
                if (data?.latestApplication != null)
                  _applicationCard(data!.latestApplication!),
                if (data?.latestApplication != null) const SizedBox(height: 20),
                _heroCta(),
                const SizedBox(height: 24),
                Text('Our credit cards',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface)),
                const SizedBox(height: 12),
                ..._cards.map(_productTile),
              ],
            );
          },
        ),
      ),
    );
  }

  // Hard-coded from Card_Application_Agent/instruction.txt line 44-49 (valid
  // product list) + tool/credit_card_repository/python_function/python_code.py
  // catalogue snippets. Keeps the mobile app aligned with what the CES agent
  // is willing to actually process an application for.
  static const List<_Product> _cards = [
    _Product(
      name: 'ACN Infinite Travel Visa',
      tagline: 'Our flagship travel card, for people who are rarely home.',
      fee: 'CAD 149 / year',
      welcome: '60,000 bonus points after CAD 3,000 in purchases in 90 days',
    ),
    _Product(
      name: 'ACN Travel Rewards Visa',
      tagline: 'Travel rewards without the flagship price tag.',
      fee: 'CAD 89 / year',
      welcome: '30,000 bonus points after CAD 1,500 in purchases in 90 days',
    ),
    _Product(
      name: 'ACN Cash Back Mastercard',
      tagline: 'The most cash back on the things you buy every week.',
      fee: 'No annual fee',
      welcome: 'CAD 75 cash back after your first CAD 500 in purchases',
    ),
    _Product(
      name: 'ACN Everyday Cash Mastercard',
      tagline: 'Pick your best category and earn more on it.',
      fee: 'No annual fee',
      welcome: 'CAD 25 cash back after your first purchase',
    ),
    _Product(
      name: 'ACN Low Rate Visa',
      tagline: 'For balances you plan to pay down, not points.',
      fee: 'CAD 29 / year',
      welcome: '0% on balance transfers for the first 10 months',
    ),
    _Product(
      name: 'ACN Starter Visa',
      tagline: 'No income requirement. Build a credit history from zero.',
      fee: 'No annual fee',
      welcome: 'Approval with no credit history required',
    ),
  ];

  Widget _heroCta() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFA100FF), Color(0xFF7500C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.language, color: Colors.white),
              const SizedBox(width: 8),
              Text('acnbank.ca',
                  style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Apply for a card in minutes',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            "Continue in our web experience — it's the fastest way to pick "
            'a card, upload docs, and get approved. You can activate it here '
            'in the app after.',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openWebApply,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open web app'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => runQuickAction(
                  const QuickAction(
                    label: 'Compare',
                    utterance: 'Compare your credit cards',
                    icon: Icons.compare_arrows,
                  ),
                  widget.customerId,
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Ask AI'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _productTile(_Product p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.name,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(p.fee,
                    style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(p.tagline,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.card_giftcard,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(p.welcome,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => runQuickAction(
                  QuickAction(
                    label: 'Details',
                    utterance: 'Tell me more about the ${p.name}',
                    icon: Icons.info,
                  ),
                  widget.customerId,
                ),
                child: const Text('Details'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => runQuickAction(
                  QuickAction(
                    label: 'Apply',
                    utterance: 'I want to apply for the ${p.name}',
                    icon: Icons.check_circle,
                  ),
                  widget.customerId,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _applicationCard(Map<String, dynamic> app) {
    final status = (app['status'] ?? 'pending').toString();
    final productName = (app['product_name'] ?? 'Your application').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_turned_in, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your latest application',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
                Text(productName,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface)),
                Text('Status: $status',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Product {
  final String name;
  final String tagline;
  final String fee;
  final String welcome;
  const _Product({
    required this.name,
    required this.tagline,
    required this.fee,
    required this.welcome,
  });
}
