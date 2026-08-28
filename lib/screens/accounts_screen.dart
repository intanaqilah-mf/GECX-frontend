import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/banking_models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Accounts tab — card hero + Card Actions that mutate local UI state, not
/// CES intents. `HomeData` gives us the card + the customer's real display
/// name (used on the card artwork instead of the customerId).
class AccountsScreen extends StatefulWidget {
  final String customerId;
  const AccountsScreen({super.key, required this.customerId});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _api = ApiService();
  late Future<HomeData> _home;

  // ── Local card state ────────────────────────────────────────────────────
  // Freeze: purely a visual state today — a real production hook would fire
  // the Card_Management_Agent's block flow, but the ask is to make the card
  // *look* frozen inline. Same idea for PIN: it toggles the mask, doesn't
  // hit the backend.
  bool _frozen = false;
  bool _masked = true;

  @override
  void initState() {
    super.initState();
    _home = _api.getHomeData(widget.customerId);
  }

  Future<void> _refresh() async {
    setState(() => _home = _api.getHomeData(widget.customerId));
    await _home;
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
            final card = data?.latestCard;
            final holderName = data?.customer.displayName ?? 'Card Holder';
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _title('My Accounts'),
                const SizedBox(height: 12),
                _cardHero(card, holderName),
                const SizedBox(height: 24),
                _title('Card Actions'),
                const SizedBox(height: 12),
                _cardActions(),
                const SizedBox(height: 24),
                _title('Activity'),
                const SizedBox(height: 12),
                if (card == null)
                  _empty('Activate a card to see activity here.')
                else
                  _ActivityList(cardId: card.cardId),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _title(String text) => Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface),
      );

  // ─── Card hero (freeze + mask aware) ──────────────────────────────────
  Widget _cardHero(CardModel? card, String holderName) {
    if (card == null) return _empty('No cards linked yet.');

    final pan = card.cardNumber ?? '•••• •••• •••• ••••';
    final expiry = card.expiryDate ?? '—';
    final cvv = card.cvv;

    // Mask is the default (card's sensitive info hidden). Tapping "PIN"
    // reveals it and toggles again to re-mask.
    final panDisplay = _masked ? _maskPan(pan) : pan;
    final expiryDisplay = _masked ? '••/••' : expiry;
    final cvvDisplay = _masked ? '•••' : cvv;

    // Freeze overlay: desaturate the card and add a snowflake watermark so
    // the "frozen" state is unmistakable.
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _frozen
                  ? const [Color(0xFF6D6A7A), Color(0xFF3E3B47)]
                  : const [Color(0xFFA100FF), Color(0xFF3B0064)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.cardType ?? 'Visa',
                  style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Text('ACN Bank',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 28),
              Text(panDisplay,
                  style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 2)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _kv('CARD HOLDER', holderName)),
                  Expanded(child: _kv('EXPIRES', expiryDisplay)),
                  _kv('CVV', cvvDisplay, crossEnd: true),
                ],
              ),
            ],
          ),
        ),
        // Frozen watermark — big snowflake, semi-transparent.
        if (_frozen)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Cool blue tint over the card so it reads "frozen".
                  Container(
                    color: const Color(0xFF8CB8E8).withValues(alpha: 0.18),
                  ),
                  Opacity(
                    opacity: 0.22,
                    child: Icon(Icons.ac_unit,
                        size: 140, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  // "FROZEN" ribbon at the top so a glance tells the story.
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.ac_unit,
                              size: 12, color: Color(0xFF3E5F87)),
                          const SizedBox(width: 4),
                          Text('FROZEN',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF3E5F87))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _kv(String label, String value, {bool crossEnd = false}) {
    return Column(
      crossAxisAlignment:
          crossEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white38, fontSize: 9, letterSpacing: 0.5)),
        Text(value,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _maskPan(String pan) {
    final digits = pan.replaceAll(RegExp(r'\D'), '');
    final last4 =
        digits.length >= 4 ? digits.substring(digits.length - 4) : '••••';
    return '•••• •••• •••• $last4';
  }

  // ─── Card actions row (local state only) ──────────────────────────────
  Widget _cardActions() {
    final items = <_CardActionSpec>[
      _CardActionSpec(
        label: _frozen ? 'Frozen' : 'Freeze',
        icon: Icons.ac_unit,
        active: _frozen,
        onTap: () => setState(() => _frozen = true),
      ),
      _CardActionSpec(
        label: 'Unfreeze',
        icon: Icons.lock_open,
        // Purely UI-side counterpart to Freeze. Disabled visually when the
        // card isn't frozen so the pairing reads clearly.
        active: !_frozen,
        onTap: () => setState(() => _frozen = false),
      ),
      _CardActionSpec(
        label: _masked ? 'Show' : 'Hide',
        icon: _masked ? Icons.visibility : Icons.visibility_off,
        active: !_masked,
        onTap: () => setState(() => _masked = !_masked),
      ),
      _CardActionSpec(
        label: 'PIN',
        icon: Icons.password,
        // PIN is a separate mask toggle intentionally kept as an alias for
        // Show/Hide to match the reference design's four-icon row.
        active: !_masked,
        onTap: () => setState(() => _masked = !_masked),
      ),
    ];

    return Row(
      children: items
          .map((a) => Expanded(
                child: InkWell(
                  onTap: a.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: a.active
                                ? AppColors.primary
                                : AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(a.icon,
                              color: a.active
                                  ? Colors.white
                                  : AppColors.primary,
                              size: 22),
                        ),
                        const SizedBox(height: 6),
                        Text(a.label,
                            style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface)),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _empty(String msg) => Container(
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
                        color: AppColors.onSurfaceVariant, fontSize: 13))),
          ],
        ),
      );
}

class _CardActionSpec {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  _CardActionSpec({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
}

class _ActivityList extends StatelessWidget {
  final String cardId;
  const _ActivityList({required this.cardId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ActivityModel>>(
      future: ApiService().getCardActivity(cardId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Text('No recent transactions.',
                style: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant, fontSize: 13)),
          );
        }
        return Column(children: items.map(_row).toList());
      },
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
            child: const Icon(Icons.receipt_long,
                color: AppColors.primary, size: 20),
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
}
