import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/accounts_screen.dart';
import '../screens/apply_screen.dart';
import '../screens/expenses_screen.dart';
import '../screens/home_screen.dart';
import '../screens/scan_screen.dart';
import '../theme/app_colors.dart';

/// Five-tab shell with a raised center Scan button — mirrors the reference
/// design (Maybank2u-style) while keeping the ACN purple brand. The bottom
/// nav sits above every route the shell renders; the persistent [ChatOverlay]
/// wired in main.dart sits above THIS.
class AppShell extends StatefulWidget {
  final String customerId;
  const AppShell({super.key, required this.customerId});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // Each tab keeps its own state via IndexedStack (list-scroll positions, form
  // input, futures already loaded). Tabs that fetch on init won't refetch when
  // you flip away and back.
  late final List<Widget> _tabs = <Widget>[
    HomeScreen(customerId: widget.customerId),
    AccountsScreen(customerId: widget.customerId),
    const ScanScreen(),
    ExpensesScreen(customerId: widget.customerId),
    ApplyScreen(customerId: widget.customerId),
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Center Scan button is a real FAB (not a nav item) so it can float
      // above the bar. The bar has a matching notch cut out for it.
      floatingActionButton: _ScanFab(active: _index == 2, onTap: () => _go(2)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: _AppBottomBar(
        index: _index,
        onTap: _go,
      ),
    );
  }
}

class _AppBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _AppBottomBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: const Color(0xFF140025),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 12,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(context, 0, Icons.home_rounded, Icons.home_outlined, 'Home'),
            _navItem(context, 1, Icons.account_balance_wallet,
                Icons.account_balance_wallet_outlined, 'Accounts'),
            // Gap for the center FAB
            const SizedBox(width: 60),
            _navItem(context, 3, Icons.pie_chart, Icons.pie_chart_outline, 'Expenses'),
            _navItem(context, 4, Icons.assignment_turned_in,
                Icons.assignment_outlined, 'Apply'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int i,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final active = index == i;
    final color = active ? AppColors.primary : Colors.white70;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : inactiveIcon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Raised center Scan button — same pattern as the reference screenshot.
class _ScanFab extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _ScanFab({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      width: 62,
      child: FloatingActionButton(
        onPressed: onTap,
        backgroundColor: AppColors.primary,
        elevation: 6,
        shape: const CircleBorder(),
        child: Icon(
          active ? Icons.qr_code_scanner : Icons.qr_code_scanner_outlined,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
