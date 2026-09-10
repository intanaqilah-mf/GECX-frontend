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
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              // Travel protection alert — tells the customer where coverage lives
              // when the CES agent offers travel protection during a session.
              const SliverToBoxAdapter(child: _TravelProtectionAlert()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _SectionHeader(title: 'Quick Actions', trailing: 'View All', onTap: () {}),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                // Fixed cell size instead of a flex-grid — keeps tiles the
                // same physical size on every screen width, so on tablet /
                // web the tiles don't balloon out.
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 110, // ~4 across on a 440-wide column
                    mainAxisExtent: 88,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 4,
                  ),
                  delegate: SliverChildListDelegate(
                    [
                      ...kQuickActionsPrimary,
                      ...kQuickActionsSecondary,
                    ]
                        .map((qa) => _QuickActionTile(
                              action: qa,
                              onTap: () =>
                                  runQuickAction(qa, widget.customerId),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              // Dot indicator like the reference screenshot.
              const SliverToBoxAdapter(child: _DotIndicator(count: 2, active: 0)),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              // My Cards — hardcoded active cards so the customer can see what
              // they hold without leaving Home (Card Activation screen hides it).
              _SectionHeader(title: 'My Cards', trailing: 'View All', onTap: () {}),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 190,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: const [
                      _ActiveCardTile(
                        name: 'ACN Travel Rewards Visa',
                        tier: 'Platinum',
                        last4: '8842',
                        gradient: [Color(0xFF0056B3), Color(0xFF002147)],
                      ),
                      _ActiveCardTile(
                        name: 'ACN Infinite Travel Visa',
                        tier: 'Infinite',
                        last4: '4242',
                        gradient: [Color(0xFF002147), Color(0xFF008080)],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
          colors: [Color(0xFF002147), Color(0xFF0056B3)],
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
  final VoidCallback onTap;
  const _FeaturedTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
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

// ─── Travel protection alert ───────────────────────────────────────────────
// Info banner shown right below the Hero card so a customer who's been offered
// travel protection by the CES agent knows where to find their coverage.
class _TravelProtectionAlert extends StatelessWidget {
  const _TravelProtectionAlert();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F4FD), Color(0xFFEEF6FF)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB8D9F5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Travel Protection Available',
                        style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB45309),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'OFFER',
                          style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "You've been offered travel medical coverage. "
                    'Tap to review and activate.',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        height: 1.4,
                        color: const Color(0xFF3A5F80)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF3A5F80), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Active card tile ──────────────────────────────────────────────────────
// Hardcoded card visual used by the "My Cards" horizontal strip on Home.
// Mirrors the accounts_screen.dart card hero styling (gradient + monospace PAN).
class _ActiveCardTile extends StatelessWidget {
  final String name;
  final String tier;
  final String last4;
  final List<Color> gradient;

  const _ActiveCardTile({
    required this.name,
    required this.tier,
    required this.last4,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 260,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ACN Bank',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tier.toUpperCase(),
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8),
                    ),
                  ),
                ],
              ),
              Container(
                width: 34,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7D794),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                '••••  ••••  ••••  $last4',
                style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 14,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF5EE39F),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Active',
                              style: GoogleFonts.inter(
                                  color: const Color(0xFF5EE39F),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'VISA',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
