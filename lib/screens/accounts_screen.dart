import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/banking_models.dart';
import '../services/api_service.dart';
import '../services/quick_actions.dart';
import '../theme/app_colors.dart';

/// Accounts tab — card hero + full activity feed backed by
/// `GET /cards/{id}/activity`.
class AccountsScreen extends StatefulWidget {
  final String customerId;
  const AccountsScreen({super.key, required this.customerId});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
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
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _title('My Accounts'),
                const SizedBox(height: 12),
                _cardHero(card),
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

  Widget _cardHero(CardModel? card) {
    if (card == null) return _empty('No cards linked yet.');
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA100FF), Color(0xFF3B0064)],
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
          Text(card.cardNumber ?? '•••• •••• •••• ••••',
              style: GoogleFonts.robotoMono(
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 2)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _kv('CARD HOLDER', card.cardHolderName ?? '—'),
              ),
              Expanded(
                child: _kv('EXPIRES', card.expiryDate ?? '—'),
              ),
              _kv('CVV', card.cvv, crossEnd: true),
            ],
          ),
        ],
      ),
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

  Widget _cardActions() {
    final actions = <QuickAction>[
      const QuickAction(
          label: 'Freeze', utterance: 'Block my card', icon: Icons.ac_unit),
      const QuickAction(
          label: 'Unfreeze',
          utterance: 'Unblock my card',
          icon: Icons.lock_open),
      const QuickAction(
          label: 'PIN', utterance: 'Change my card PIN', icon: Icons.password),
      const QuickAction(
          label: 'Limit',
          utterance: 'Show my daily transfer limit',
          icon: Icons.speed),
    ];
    return Row(
      children: actions
          .map((a) => Expanded(
                child: InkWell(
                  onTap: () => runQuickAction(a, widget.customerId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(a.icon,
                              color: AppColors.primary, size: 22),
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
