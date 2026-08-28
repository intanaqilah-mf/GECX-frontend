import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/banking_models.dart';
import '../services/api_service.dart';
import '../services/quick_actions.dart';
import '../theme/app_colors.dart';

/// Home tab — the reference-image layout, adapted to ACN purple.
///
/// Sections top-down:
///  1. Purple hero blob with greeting + masked balance + View All Accounts
///  2. Quick Actions grid (2×4) sourced from [kQuickActionsPrimary/Secondary]
///  3. Featured strip — pre-approved offers + travel-store cross-sell
///  4. Recent activity from `getCardActivity` (real data, not hardcoded)
class HomeScreen extends StatefulWidget {
  final String customerId;
  const HomeScreen({super.key, required this.customerId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  late Future<HomeData> _home;
  bool _hideBalance = false;

  @override
  void initState() {
    super.initState();
    _home = _api.getHomeData(widget.customerId);
  }

  Future<void> _refresh() async {
    final f = _api.getHomeData(widget.customerId);
    setState(() => _home = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: FutureBuilder<HomeData>(
        future: _home,
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final data = snap.data;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroCard(
                  displayName: data?.customer.displayName ?? '…',
                  hideBalance: _hideBalance,
                  onToggleHide: () => setState(() => _hideBalance = !_hideBalance),
                  card: data?.latestCard,
                  loading: loading,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              _SectionHeader(title: 'Quick Actions', trailing: 'View All', onTap: () {}),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.85,
                  children: [
                    ...kQuickActionsPrimary,
                    ...kQuickActionsSecondary,
                  ]
                      .map((qa) => _QuickActionTile(
                            action: qa,
                            onTap: () => runQuickAction(qa, widget.customerId),
                          ))
                      .toList(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              // Dot indicator like the reference screenshot.
              const SliverToBoxAdapter(child: _DotIndicator(count: 2, active: 0)),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              _SectionHeader(title: 'Featured'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 168,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _FeaturedTile(
                        title: 'Card',
                        subtitle: 'e-Payment',
                        icon: Icons.credit_card,
                        badge: '69% OFF',
                        onTap: () => runQuickAction(
                          const QuickAction(
                              label: 'Cards',
                              utterance: 'Show my card offers',
                              icon: Icons.credit_card),
                          widget.customerId,
                        ),
                      ),
                      _FeaturedTile(
                        title: 'Car',
                        subtitle: 'Insurance',
                        icon: Icons.directions_car,
                        onTap: () => runQuickAction(
                          const QuickAction(
                              label: 'Car',
                              utterance: 'Show me car insurance options',
                              icon: Icons.directions_car),
                          widget.customerId,
                        ),
                      ),
                      _FeaturedTile(
                        title: 'Travel',
                        subtitle: 'Store',
                        icon: Icons.flight_takeoff,
                        onTap: () async {
                          final cardId = data?.latestCard?.cardId ?? '';
                          final uri = Uri.parse(
                              'https://acn-travel-store-483471568825.web.app/'
                              '${cardId.isEmpty ? '' : '?card_id=$cardId'}');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                      ),
                      _FeaturedTile(
                        title: 'Credit',
                        subtitle: 'Score',
                        icon: Icons.trending_up,
                        badge: '20% OFF',
                        onTap: () => runQuickAction(
                          const QuickAction(
                              label: 'Credit Score',
                              utterance: 'Show my credit score',
                              icon: Icons.trending_up),
                          widget.customerId,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              _SectionHeader(title: 'Recent Activity', trailing: 'View All', onTap: () {}),
              _RecentActivitySliver(cardId: data?.latestCard?.cardId),
              // Bottom padding so content clears the notched bottom bar + FAB.
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

// ─── Hero ──────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String displayName;
  final CardModel? card;
  final bool hideBalance;
  final VoidCallback onToggleHide;
  final bool loading;

  const _HeroCard({
    required this.displayName,
    required this.card,
    required this.hideBalance,
    required this.onToggleHide,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = displayName.split(' ').first;
    // creditLimit is a String on the model — parse defensively.
    final limit = double.tryParse(card?.creditLimit ?? '') ?? 0;
    final spent = card?.spentAmount ?? 0;
    final available = limit - spent;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA100FF), Color(0xFF7500C0)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(48),
          bottomRight: Radius.circular(48),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topBar(context, firstName),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'Account',
                style: GoogleFonts.inter(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                card?.cardNumber != null
                    ? _formatCardMask(card!.cardNumber!)
                    : '**** **** ****',
                style: GoogleFonts.robotoMono(
                    fontSize: 14,
                    color: Colors.white70,
                    letterSpacing: 4),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  hideBalance || available == 0
                      ? 'CAD ****'
                      : 'CAD ${available.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                _EyeButton(hidden: hideBalance, onTap: onToggleHide),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () {},
                child: Text(
                  'View All Accounts',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, String firstName) {
    return Row(
      children: [
        Stack(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: AppColors.primary),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.settings,
                    size: 12, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello,',
                style: GoogleFonts.inter(
                    color: Colors.white70, fontSize: 13)),
            Text(firstName,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.logout, color: Colors.white),
        ),
      ],
    );
  }

  String _formatCardMask(String pan) {
    final digits = pan.replaceAll(RegExp(r'\D'), '');
    final last = digits.length >= 4 ? digits.substring(digits.length - 4) : '****';
    return '**** **** **** $last';
  }
}

class _EyeButton extends StatelessWidget {
  final bool hidden;
  final VoidCallback onTap;
  const _EyeButton({required this.hidden, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}

// ─── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  const _SectionHeader({required this.title, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
        child: Row(
          children: [
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface)),
            const Spacer(),
            if (trailing != null)
              TextButton(
                onPressed: onTap,
                child: Text(trailing!,
                    style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick action tile ─────────────────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  final QuickAction action;
  final VoidCallback onTap;
  const _QuickActionTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: action.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(action.icon, color: action.foreground, size: 26),
                ),
                if (action.badgeText != null)
                  Positioned(
                    top: -8,
                    left: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: action.badgeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(action.badgeText!,
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.15,
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Featured tile ─────────────────────────────────────────────────────────

class _FeaturedTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;
  const _FeaturedTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 128,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 118,
                    width: 128,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: AppColors.primary, size: 44),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -6,
                      left: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE21B24),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(badge!,
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.onSurface)),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 11.5, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dot indicator ─────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  final int count;
  final int active;
  const _DotIndicator({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == active;
        return Container(
          width: on ? 10 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : AppColors.outline,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─── Recent activity ───────────────────────────────────────────────────────

class _RecentActivitySliver extends StatelessWidget {
  final String? cardId;
  const _RecentActivitySliver({required this.cardId});

  @override
  Widget build(BuildContext context) {
    if (cardId == null || cardId!.isEmpty) {
      return SliverToBoxAdapter(
        child: _emptyActivity(
          'No activity yet — activate a card to see transactions here.',
        ),
      );
    }
    return SliverToBoxAdapter(
      child: FutureBuilder<List<ActivityModel>>(
        future: ApiService().getCardActivity(cardId!),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) return _emptyActivity('No recent transactions.');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: items.take(5).map(_row).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _row(ActivityModel a) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.onSurface)),
                Text(a.subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            '${a.amount < 0 ? '-' : ''}CAD ${a.amount.abs().toStringAsFixed(2)}',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: a.amount < 0 ? AppColors.error : AppColors.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _emptyActivity(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.onSurfaceVariant))),
          ],
        ),
      ),
    );
  }
}
