import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  static const _contacts = [
    ('Sarah J.', Color(0xFF6B9BD2)),
    ('Michael K.', Color(0xFF5B8DB8)),
    ('Elena R.', Color(0xFF7A9EC5)),
    ('David L.', Color(0xFF4A7BA8)),
    ('Sophia M.', Color(0xFF8AAFD4)),
  ];

  static const _scheduled = [
    (Icons.electric_bolt, 'Metropolis Utilities', 'Due Oct 24, 2023', '-\$142.50', true),
    (Icons.home_work_outlined, 'Riverside Rent', 'Due Nov 01, 2023', '-\$2,100.00', false),
    (Icons.directions_car_outlined, 'Luxe Auto Finance', 'Due Nov 05, 2023', '-\$485.00', true),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 1,
          automaticallyImplyLeading: false,
          title: Text('Payments',
              style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary)),
          actions: [
            IconButton(
                icon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
                onPressed: () {}),
            IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.onSurfaceVariant),
                onPressed: () {}),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildQuickSend(),
              const SizedBox(height: 32),
              _buildMoveMoney(),
              const SizedBox(height: 32),
              _buildScheduled(context),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Send',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
            TextButton(
              onPressed: () {},
              child: Text('View All',
                  style: GoogleFonts.inter(
                      color: AppColors.secondary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _contactAvatar(null, 'Add New', isAddButton: true),
              ..._contacts.map((c) => _contactAvatar(c.$2, c.$1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactAvatar(Color? color, String name, {bool isAddButton = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          isAddButton
              ? Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outlineVariant, width: 2),
                  ),
                  child: const Icon(Icons.add, color: AppColors.secondary),
                )
              : CircleAvatar(
                  radius: 30,
                  backgroundColor: color,
                  child: Text(
                    name.split(' ').map((w) => w[0]).join(),
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                ),
          const SizedBox(height: 6),
          Text(name,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildMoveMoney() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Move Money',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _moneyCard(Icons.swap_horiz, 'Between Accounts',
                  'Transfer funds instantly within ACN Bank.'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _moneyCard(Icons.person_add_outlined, 'Send to Someone',
                  'Move money to any bank or external contact.'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _moneyCard(Icons.receipt_long_outlined, 'Pay a Bill',
            'Settle utility, credit card, or service bills.',
            fullWidth: true),
      ],
    );
  }

  Widget _moneyCard(IconData icon, String title, String description,
      {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.onSecondaryContainer, size: 22),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          const SizedBox(height: 4),
          Text(description,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildScheduled(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Scheduled Payments',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface)),
            IconButton(
              icon: const Icon(Icons.filter_list, color: AppColors.onSurfaceVariant),
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: _scheduled.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return Column(
                children: [
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.outlineVariant),
                  _scheduledRow(s.$1, s.$2, s.$3, s.$4, s.$5),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: Text('Schedule New Payment',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scheduledRow(
      IconData icon, String title, String date, String amount, bool autoPay) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface)),
                Text(date,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface)),
              Text(
                autoPay ? 'Auto-pay' : 'One-time',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: autoPay ? AppColors.secondary : AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

