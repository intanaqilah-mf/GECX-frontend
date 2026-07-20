import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'services/navigation_service.dart';
import 'theme/app_colors.dart';
import 'screens/dashboard_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/card_details_screen.dart';
import 'screens/statements_screen.dart';
import 'screens/login_screen.dart';
import 'screens/application_status_screen.dart';
import 'models/banking_models.dart';
import 'services/api_service.dart';

class AppStartup {
  static String? pendingCardId;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    final match = RegExp(r'^/cards/([^/]+)/activate$').firstMatch(Uri.base.path);
    if (match != null) {
      AppStartup.pendingCardId = match.group(1);
    }
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FcmService.initialize();
  runApp(const BankingApp());
}

class BankingApp extends StatelessWidget {
  const BankingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light(useMaterial3: true);
    return MaterialApp(
      title: 'ACN Bank',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.secondaryContainer,
          onSecondaryContainer: AppColors.onSecondaryContainer,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          error: AppColors.error,
          onError: Colors.white,
          outline: AppColors.outline,
          outlineVariant: AppColors.outlineVariant,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.interTextTheme(base.textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
          iconTheme: const IconThemeData(color: AppColors.onSurfaceVariant),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.secondaryContainer,
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.all(
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        dividerTheme: const DividerThemeData(
            color: AppColors.outlineVariant, thickness: 1),
      ),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const LoginScreen(),
    );
  }
}

class MainShell extends StatefulWidget {
  final String customerId;
  const MainShell({super.key, required this.customerId});

  static _MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainShellState>();

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final ApiService _apiService = ApiService();
  late Future<HomeData> _homeDataFuture;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _apiService.getHomeData(widget.customerId);
  }

  void setIndex(int index) {
    setState(() => _index = index);
  }

  void refresh() {
    setState(() {
      _homeDataFuture = _apiService.getHomeData(widget.customerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
      future: _homeDataFuture,
      builder: (context, snapshot) {
        final hasCard = snapshot.data?.customer.hasCard ?? false;

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              DashboardScreen(customerId: widget.customerId),
              PaymentsScreen(customerId: widget.customerId),
              hasCard
                  ? CardDetailsScreen(customerId: widget.customerId)
                  : ApplicationStatusScreen(customerId: widget.customerId),
              StatementsScreen(customerId: widget.customerId),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments),
                label: 'Payments',
              ),
              NavigationDestination(
                icon: Icon(hasCard ? Icons.credit_card_outlined : Icons.assignment_outlined),
                selectedIcon: Icon(hasCard ? Icons.credit_card : Icons.assignment),
                label: hasCard ? 'Cards' : 'Application',
              ),
              const NavigationDestination(
                icon: Icon(Icons.contact_support_outlined),
                selectedIcon: Icon(Icons.contact_support),
                label: 'Support',
              ),
            ],
          ),
        );
      },
    );
  }
}
