import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/banking_models.dart';
import '../services/api_service.dart';
import '../services/application_events.dart';
import '../services/quick_actions.dart';
import '../theme/app_colors.dart';
import 'card_activation_screen.dart';

/// Apply tab — the narrative anchor for "web app applies, mobile app uses".
///
///  - If the customer already has a card: show status + "explore more products"
///    hand-off to Credit_Cards / Card_Application_Agent.
///  - Otherwise: hero CTA sending them to the acn-bank-demo web app to apply,
///    plus the 6 valid card products (from Card_Application_Agent line 44-49)
///    with tap-to-ask-AI for details.
class ApplyScreen extends StatefulWidget {
  final String customerId;

  /// Optional callback the parent shell provides so the "Go to Accounts" CTA
  /// (rendered when the latest application is approved) can flip the bottom
  /// nav to the Accounts tab (index 1) instead of pushing a new route.
  final ValueChanged<int>? onGoToTab;

  const ApplyScreen({super.key, required this.customerId, this.onGoToTab});

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  final _api = ApiService();
  late Future<HomeData> _home;

  // Local overlay onto latestApplication so an optimistic PATCH (e.g. after a
  // doc upload) can update the timeline in place without waiting for the
  // next home fetch. Keyed by application_id → partial doc.
  final Map<String, Map<String, dynamic>> _optimistic = {};

  bool _uploadingKyc = false;

  @override
  void initState() {
    super.initState();
    _home = _api.getHomeData(widget.customerId);
    // Subscribe to lifecycle pushes (FCM `application_updated`) so the tab
    // re-renders as soon as CES advances the state — no user action needed.
    ApplicationEvents.instance.addListener(_onApplicationEvent);
  }

  @override
  void dispose() {
    ApplicationEvents.instance.removeListener(_onApplicationEvent);
    super.dispose();
  }

  void _onApplicationEvent() {
    if (!mounted) return;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _home = _api.getHomeData(widget.customerId);
      _optimistic.clear();
    });
    await _home;
  }

  Future<void> _openWebApply() async {
    // acn-bank-demo web app hosts the browse/apply flow.
    final uri = Uri.parse('https://emvnzir-canada-song.web.app/');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Merges any optimistic overlay into `latestApplication` so the UI reads
  /// the freshest view — server truth on refresh, local overlay in between.
  Map<String, dynamic>? _viewOfLatestApplication(HomeData data) {
    final base = data.latestApplication;
    if (base == null) return null;
    final id = (base['application_id'] ?? '').toString();
    final overlay = _optimistic[id];
    if (overlay == null) return base;
    return {...base, ...overlay};
  }

  Future<void> _pickAndSubmitDoc(String applicationId) async {
    if (_uploadingKyc) return;
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.primary),
              title: const Text('Take a photo of your ID'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 82,
      );
      if (picked == null) return;

      setState(() => _uploadingKyc = true);
      // The gateway doesn't ship binary upload today — we just PATCH the
      // application so the timeline advances step 2 into `in_progress`. The
      // real bytes would go to a storage endpoint you add later.
      final merged = await _api.submitApplicationDocument(
        applicationId,
        documentType: 'Government-issued ID',
      );
      if (!mounted) return;
      setState(() {
        _optimistic[applicationId] = {
          ...(_optimistic[applicationId] ?? {}),
          ...merged,
        };
        _uploadingKyc = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploaded. Verifying your ID now.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingKyc = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  void _activateNewCard(String cardId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardActivationScreen(cardId: cardId),
      ),
    );
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
            final latestApp =
                data == null ? null : _viewOfLatestApplication(data);
            final offers = data?.preApprovedOffers ?? const [];
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
                const SizedBox(height: 16),

                // Pre-qualification chip — surfaces one of the pre-approved
                // offers Firestore holds under customers/{id}/financials/profile.
                // Only shows when the customer has no in-flight app AND there's
                // at least one offer to display.
                if (latestApp == null && offers.isNotEmpty) ...[
                  _preQualChip(offers.first),
                  const SizedBox(height: 16),
                ],

                if (latestApp != null) _applicationCard(latestApp),
                if (latestApp != null) const SizedBox(height: 20),
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
          colors: [Color(0xFF002147), Color(0xFF0056B3)],
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
    final stages = _ApplicationJourney.from(app);
    final productName = (app['selected_product_name'] ??
            app['product_name'] ??
            'Your application')
        .toString();
    final applicationId = (app['application_id'] ?? '').toString();
    final submittedAt = _parseDate(app['submitted_at'] ?? app['created_at']);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: product name + stage chip + application id ────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your application',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(productName,
                        style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface)),
                  ],
                ),
              ),
              _stageChip(stages.headline),
            ],
          ),
          if (applicationId.isNotEmpty || submittedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (applicationId.isNotEmpty) 'Ref $applicationId',
                if (submittedAt != null)
                  'Submitted ${_shortDate(submittedAt)}',
              ].join('  ·  '),
              style: GoogleFonts.inter(
                  fontSize: 11.5, color: AppColors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 18),

          // ── Timeline ─────────────────────────────────────────────────
          for (var i = 0; i < stages.steps.length; i++)
            _timelineRow(
              step: stages.steps[i],
              isLast: i == stages.steps.length - 1,
              // Inline "Upload your ID" action on the KYC step when the
              // customer hasn't provided a doc yet. Advances the timeline
              // in-place via a PATCH; no route change required.
              action: (i == 1 &&
                      stages.kycNeedsAction &&
                      stages.applicationId.isNotEmpty &&
                      stages.outcome == _JourneyOutcome.inProgress)
                  ? _kycUploadAction(stages.applicationId)
                  : null,
            ),

          // ── Outcome-specific CTA / banner ────────────────────────────
          const SizedBox(height: 6),
          _outcomeSection(stages),
        ],
      ),
    );
  }

  Widget _stageChip(_JourneyHeadline h) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: h.tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: h.tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(h.icon, size: 12, color: h.tone),
          const SizedBox(width: 5),
          Text(h.label,
              style: GoogleFonts.inter(
                  color: h.tone,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }

  Widget _timelineRow({
    required _JourneyStep step,
    required bool isLast,
    Widget? action,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left rail: dot + connector line
          Column(
            children: [
              _StepDot(state: step.state),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: step.state == _StepState.pending
                        ? AppColors.outlineVariant
                        : AppColors.secondary.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Right: label + subtitle + optional timestamp + optional action
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title,
                      style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: step.state == _StepState.current
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: step.state == _StepState.pending
                              ? AppColors.onSurfaceVariant
                              : AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Text(step.subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.onSurfaceVariant)),
                  if (step.timestamp != null) ...[
                    const SizedBox(height: 3),
                    Text(_shortDate(step.timestamp!),
                        style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: AppColors.onSurfaceVariant
                                .withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600)),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: 8),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Small inline action rendered inside the "Documents & Verification" step
  // when the app is in-flight and KYC is still `pending`. One tap opens the
  // camera / gallery picker, then PATCHes the application to advance step 2.
  Widget _kycUploadAction(String applicationId) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        onPressed: _uploadingKyc ? null : () => _pickAndSubmitDoc(applicationId),
        icon: _uploadingKyc
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.upload_file, size: 16),
        label: Text(_uploadingKyc ? 'Uploading…' : 'Upload your ID'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _outcomeSection(_ApplicationJourney j) {
    switch (j.outcome) {
      case _JourneyOutcome.approved:
        final cardId = j.cardId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC9E9D6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF1A6E3C), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cardId != null
                          ? "Great news — you're approved. Activate your new card to start using it."
                          : "Great news — you're approved. Your new card is ready in Accounts.",
                      style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF14532D),
                          height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Primary CTA: activate the newly-issued card if we know its id,
            // otherwise fall back to the Accounts tab.
            if (cardId != null)
              ElevatedButton.icon(
                onPressed: () => _activateNewCard(cardId),
                icon: const Icon(Icons.credit_card, size: 18),
                label: const Text('Activate my card'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => widget.onGoToTab?.call(1),
                icon: const Icon(Icons.account_balance_wallet, size: 18),
                label: const Text('Go to Accounts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            if (cardId != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => widget.onGoToTab?.call(1),
                icon: const Icon(Icons.account_balance_wallet,
                    size: 16, color: AppColors.secondary),
                label: Text('Or view it in Accounts',
                    style: GoogleFonts.inter(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5)),
              ),
            ],
            // Cross-sell tile — nudge to compare against a step-up product.
            const SizedBox(height: 12),
            _compareTile(j.productName),
          ],
        );
      case _JourneyOutcome.declined:
        return _declinedSection(j);
      case _JourneyOutcome.referred:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6E5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFAD98A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.pending_actions,
                  color: Color(0xFF9A6A00), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "We're taking a closer look. A specialist will reach out shortly.",
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF7A4E00),
                      height: 1.35),
                ),
              ),
            ],
          ),
        );
      case _JourneyOutcome.inProgress:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.secondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Typical decisions take just a few minutes. We'll notify you as soon as it's ready.",
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.onSurface,
                      height: 1.35),
                ),
              ),
            ],
          ),
        );
    }
  }

  // ─── Pre-qualification nudge ────────────────────────────────────────
  // Renders one of the pre_approved_offers surfaced by the gateway's home
  // endpoint (backed by customers/{id}/financials/profile.pre_approved_offers).
  Widget _preQualChip(Map<String, dynamic> offer) {
    final product = (offer['product_name'] ??
            offer['card_name'] ??
            offer['label'] ??
            'a card')
        .toString();
    final rawScore = offer['approval_likelihood'] ?? offer['score'];
    final int? percent = rawScore is num
        ? (rawScore <= 1 ? (rawScore * 100).round() : rawScore.round())
        : null;

    return InkWell(
      onTap: () => runQuickAction(
        QuickAction(
          label: 'Prefill',
          utterance: 'I want to apply for the $product',
          icon: Icons.bolt,
        ),
        widget.customerId,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.bolt, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You look like a fit for $product',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    percent != null
                        ? "Estimated $percent% approval — apply in under 2 minutes."
                        : "You're pre-selected. Apply in under 2 minutes.",
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.onSurfaceVariant,
                        height: 1.35),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  // ─── Cross-sell tile shown under the approved-outcome section ──────
  Widget _compareTile(String currentProduct) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows,
              color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You could also add…',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(
                    'See how $currentProduct compares against a step-up product.',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.onSurfaceVariant,
                        height: 1.35)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => runQuickAction(
              QuickAction(
                label: 'Compare',
                utterance:
                    'Compare $currentProduct against your other credit cards',
                icon: Icons.compare_arrows,
              ),
              widget.customerId,
            ),
            child: const Text('Compare'),
          ),
        ],
      ),
    );
  }

  // ─── Decline outcome — reasons expander + per-reason improve CTAs ──
  Widget _declinedSection(_ApplicationJourney j) {
    final reasons = j.declineReasons.isNotEmpty
        ? j.declineReasons
        : (j.declineReason != null ? [j.declineReason!] : const <String>[]);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3C2C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFFB4231F), size: 18),
              const SizedBox(width: 8),
              Text('Application not approved',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF7F1D1D))),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Theme(
              // Kill the divider ExpansionTile draws by default so it sits
              // cleanly inside the light-red banner.
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                iconColor: const Color(0xFF7F1D1D),
                collapsedIconColor: const Color(0xFF7F1D1D),
                title: Text('Why? (${reasons.length})',
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7F1D1D))),
                children: [
                  for (final r in reasons) _reasonRow(r),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => runQuickAction(
              const QuickAction(
                label: 'Advisor',
                utterance:
                    'I want to talk to someone about my application',
                icon: Icons.support_agent,
              ),
              widget.customerId,
            ),
            icon: const Icon(Icons.support_agent, size: 16),
            label: const Text('Speak to an advisor'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7F1D1D),
              side: const BorderSide(color: Color(0xFFF3C2C2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasonRow(String reason) {
    // Map a coarse hint from the reason text to a CES coaching utterance.
    // Falls back to the generic explainer when nothing matches.
    final lower = reason.toLowerCase();
    late final String utterance;
    late final IconData icon;
    late final String cta;
    if (lower.contains('credit') && lower.contains('score')) {
      utterance = 'Show me tips to improve my credit score';
      icon = Icons.trending_up;
      cta = 'Improve score';
    } else if (lower.contains('income') || lower.contains('affordability')) {
      utterance = 'How can I improve my chances by updating my income info?';
      icon = Icons.attach_money;
      cta = 'Update income';
    } else if (lower.contains('kyc') || lower.contains('identity') || lower.contains('document')) {
      utterance = 'What documents do I need to complete verification?';
      icon = Icons.badge_outlined;
      cta = 'Fix documents';
    } else if (lower.contains('debt') || lower.contains('utilisation') || lower.contains('utilization')) {
      utterance = 'How can I lower my credit utilisation?';
      icon = Icons.balance;
      cta = 'Lower utilisation';
    } else {
      utterance = 'Explain this decision reason: $reason';
      icon = Icons.help_outline;
      cta = 'Learn more';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7F1D1D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(reason,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF7F1D1D),
                    height: 1.4)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => runQuickAction(
              QuickAction(
                  label: cta, utterance: utterance, icon: icon),
              widget.customerId,
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7F1D1D),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            child: Text(cta),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final s = raw.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  String _shortDate(DateTime d) => DateFormat('MMM d, h:mm a').format(d);
}

// ─── Journey model ─────────────────────────────────────────────────────
//
// The Flutter gateway's `applications` collection today only writes a single
// `status:"approved"` row (see backend/app/services/application_service.py) —
// there's no `submitted_at`, no `kyc_status`, no `credit_check_status`, no
// per-step events. The CES side's `card_applications` collection has all of
// those fields but the active Card_Application_Agent doesn't write to it.
//
// This model reads whatever fields ARE present and infers the rest from the
// `status` enum so the UI keeps working today AND lights up correctly once
// either backend starts writing richer state.
//
// Legal `status` values (matches update_card_application/python_code.py:7-14):
//   received | under_review | approved | declined | referred | abandoned

enum _StepState { done, current, pending }

enum _JourneyOutcome { inProgress, approved, declined, referred }

class _JourneyStep {
  final String title;
  final String subtitle;
  final _StepState state;
  final DateTime? timestamp;
  const _JourneyStep({
    required this.title,
    required this.subtitle,
    required this.state,
    this.timestamp,
  });
}

class _JourneyHeadline {
  final String label;
  final Color tone;
  final IconData icon;
  const _JourneyHeadline(this.label, this.tone, this.icon);
}

class _ApplicationJourney {
  final List<_JourneyStep> steps;
  final _JourneyOutcome outcome;
  final _JourneyHeadline headline;
  final String? declineReason;
  final List<String> declineReasons;
  final String applicationId;
  final String? cardId;
  final String productName;
  final bool kycNeedsAction; // step 2 is `current` and no doc uploaded yet

  const _ApplicationJourney({
    required this.steps,
    required this.outcome,
    required this.headline,
    required this.applicationId,
    required this.productName,
    this.cardId,
    this.declineReason,
    this.declineReasons = const [],
    this.kycNeedsAction = false,
  });

  factory _ApplicationJourney.from(Map<String, dynamic> app) {
    final rawStatus = (app['status'] ?? '').toString().toLowerCase().trim();

    DateTime? d(String k) {
      final v = app[k];
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    final submittedAt = d('submitted_at') ?? d('created_at');
    final decisionAt = d('decision_at') ?? d('updated_at');
    final kycStatus = (app['kyc_status'] ?? '').toString().toLowerCase();
    final creditStatus =
        (app['credit_check_status'] ?? app['fraud_verdict'] ?? '')
            .toString()
            .toLowerCase();

    // Rank the overall status enum so we can compare against per-stage flags.
    // (received < under_review < terminal)
    final rank = switch (rawStatus) {
      'received' => 1,
      'under_review' => 2,
      'approved' || 'declined' || 'referred' || 'abandoned' => 3,
      _ => 3, // legacy rows that only have `approved` land here — treat terminal
    };

    _StepState submittedState = _StepState.done; // always done once a row exists

    _StepState docsState;
    if (kycStatus == 'passed' || kycStatus == 'verified') {
      docsState = _StepState.done;
    } else if (kycStatus == 'failed') {
      docsState = _StepState.done; // failed still moves the pipeline forward
    } else if (kycStatus == 'in_progress' || kycStatus == 'pending') {
      docsState = _StepState.current;
    } else {
      // No per-stage signal — infer from the overall status.
      docsState = rank >= 2 ? _StepState.done : _StepState.current;
    }

    _StepState creditState;
    if (creditStatus == 'passed' || creditStatus == 'clean') {
      creditState = _StepState.done;
    } else if (creditStatus == 'failed' || creditStatus == 'flagged') {
      creditState = _StepState.done;
    } else if (creditStatus == 'in_progress' || creditStatus == 'pending') {
      creditState = _StepState.current;
    } else {
      creditState = rank >= 3
          ? _StepState.done
          : (docsState == _StepState.done
              ? _StepState.current
              : _StepState.pending);
    }

    _StepState decisionState;
    _JourneyOutcome outcome;
    _JourneyHeadline headline;
    String? declineReason;
    List<String> declineReasonsList = const [];

    switch (rawStatus) {
      case 'approved':
        decisionState = _StepState.done;
        outcome = _JourneyOutcome.approved;
        headline = const _JourneyHeadline(
            'APPROVED', Color(0xFF1A6E3C), Icons.check_circle);
        break;
      case 'declined':
        decisionState = _StepState.done;
        outcome = _JourneyOutcome.declined;
        headline = const _JourneyHeadline(
            'NOT APPROVED', Color(0xFFB4231F), Icons.cancel);
        final reasons = app['decision_reasons'];
        if (reasons is String && reasons.trim().isNotEmpty) {
          declineReason = reasons.trim();
          declineReasonsList = [reasons.trim()];
        } else if (reasons is List && reasons.isNotEmpty) {
          declineReasonsList =
              reasons.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
          declineReason = declineReasonsList.join(', ');
        }
        break;
      case 'referred':
        decisionState = _StepState.current;
        outcome = _JourneyOutcome.referred;
        headline = const _JourneyHeadline(
            'IN REVIEW', Color(0xFF9A6A00), Icons.pending_actions);
        break;
      case 'abandoned':
        decisionState = _StepState.done;
        outcome = _JourneyOutcome.declined;
        headline = const _JourneyHeadline(
            'CLOSED', Color(0xFF66788A), Icons.close);
        declineReason = 'This application was closed. Start a new one anytime.';
        break;
      default:
        // In-progress states (received / under_review / anything else).
        decisionState = creditState == _StepState.done
            ? _StepState.current
            : _StepState.pending;
        outcome = _JourneyOutcome.inProgress;
        headline = _JourneyHeadline(
            rawStatus == 'under_review' ? 'IN REVIEW' : 'PROCESSING',
            AppColors.secondary,
            Icons.autorenew);
    }

    // The KYC step needs a user action when either (a) the row explicitly
    // says kyc_status is pending or (b) we're in a state where step 2 is the
    // current stage and no per-stage signal has moved it. `docsState == current`
    // captures both because of the inference block above.
    final kycNeedsAction = docsState == _StepState.current &&
        kycStatus != 'in_progress';

    return _ApplicationJourney(
      outcome: outcome,
      headline: headline,
      declineReason: declineReason,
      declineReasons: declineReasonsList,
      applicationId: (app['application_id'] ?? '').toString(),
      cardId: (app['card_id'] ?? '').toString().isEmpty
          ? null
          : app['card_id'].toString(),
      productName: (app['selected_product_name'] ??
              app['product_name'] ??
              'Your application')
          .toString(),
      kycNeedsAction: kycNeedsAction,
      steps: [
        _JourneyStep(
          title: 'Application Submitted',
          subtitle: 'We have received your application.',
          state: submittedState,
          timestamp: submittedAt,
        ),
        _JourneyStep(
          title: 'Documents & Verification',
          subtitle: kycStatus == 'failed'
              ? "We couldn't verify your documents."
              : 'Our team is verifying your ID and documents.',
          state: docsState,
        ),
        _JourneyStep(
          title: 'Credit Assessment',
          subtitle: creditStatus == 'flagged'
              ? 'A specialist is reviewing your file.'
              : 'Reviewing your credit history and affordability.',
          state: creditState,
        ),
        _JourneyStep(
          title: 'Final Decision',
          subtitle: switch (outcome) {
            _JourneyOutcome.approved => "You're approved. Card is being issued.",
            _JourneyOutcome.declined =>
              "We're unable to approve this application.",
            _JourneyOutcome.referred =>
              'Referred to a specialist for closer review.',
            _JourneyOutcome.inProgress =>
              "You'll be notified via app and email.",
          },
          state: decisionState,
          timestamp:
              outcome == _JourneyOutcome.inProgress ? null : decisionAt,
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final _StepState state;
  const _StepDot({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _StepState.done:
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.secondary, // Tertiary Teal
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check, color: Colors.white, size: 14),
        );
      case _StepState.current:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      case _StepState.pending:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outlineVariant, width: 2),
          ),
        );
    }
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
