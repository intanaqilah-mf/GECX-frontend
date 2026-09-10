import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/api_service.dart';
import 'services/biometric_auth_service.dart';
import 'services/fcm_service.dart';
import 'services/navigation_service.dart';
import 'theme/app_colors.dart';
import 'screens/login_screen.dart';
import 'screens/card_activation_screen.dart';
import 'widgets/app_shell.dart';
import 'widgets/chat_overlay.dart';

/// Pending, one-shot hand-off values captured before the first frame. Consumed
/// by the login flow (or the SSO fast-path in [BankingApp]) and then cleared.
class AppStartup {
  /// Card id parsed from a `/cards/<id>/activate` web URL — after login we
  /// push CardActivationScreen on top of the shell.
  static String? pendingCardId;

  /// Customer id parsed from a `?customer_id=…&sso=web` query string. When
  /// present, the app skips the login screen and lands directly on AppShell.
  /// Populated only when the launch URL also carries `sso=web` (the marker the
  /// web app sets when the user was already signed in there — see
  /// `acn-bank-demo/src/components/CardActivationWidget.jsx`).
  static String? pendingCustomerId;
}

/// Shared parser: extracts card-id and customer-id from any activation URI,
/// regardless of whether it came from the browser URL bar (web) or an Android
/// intent / iOS universal link (native).
///
/// Accepted forms:
///   /cards/<id>/activate?customer_id=X&sso=web   (path + query)
///   gecxbanking://activate?card_id=X&customer_id=Y&sso=web   (scheme + query)
void _parseActivationUri(Uri uri) {
  // 1. Path-based card id: /cards/<id>/activate
  final pathMatch = RegExp(r'^/cards/([^/]+)/activate$').firstMatch(uri.path);
  if (pathMatch != null) {
    AppStartup.pendingCardId = pathMatch.group(1);
  }

  final qp = uri.queryParameters;

  // 2. Query-based card id (scheme-style link): ?card_id=<id>
  final qCardId = qp['card_id'];
  if (qCardId != null && qCardId.trim().isNotEmpty) {
    AppStartup.pendingCardId ??= qCardId.trim();
  }

  // 3. SSO hand-off — requires BOTH customer_id AND sso=web so a bare
  //    ?customer_id= in a shared link can't silently bypass login.
  final sso = qp['sso'];
  final cid = qp['customer_id'];
  if (sso == 'web' && cid != null && cid.trim().isNotEmpty) {
    AppStartup.pendingCustomerId = cid.trim();
  }
}

/// Reads SSO / deep-link params from the browser URL on Flutter Web.
void _captureWebDeepLink() {
  if (!kIsWeb) return;
  _parseActivationUri(Uri.base);
}

/// Reads the launch URI on native platforms (Android intent filter /
/// iOS universal link / custom URL scheme) via the `app_links` package.
/// Must be called after [WidgetsFlutterBinding.ensureInitialized].
Future<void> _captureNativeDeepLink() async {
  if (kIsWeb) return; // web handled by _captureWebDeepLink
  try {
    final appLinks = AppLinks();
    final uri = await appLinks.getInitialLink();
    if (uri == null) return;
    debugPrint('Native deep-link on launch: $uri');
    _parseActivationUri(uri);
  } catch (e) {
    debugPrint('Native deep-link capture failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture activation params before the first frame so MaterialApp.home can
  // fork correctly. Web reads Uri.base; native reads the launch intent / URL.
  _captureWebDeepLink();
  await _captureNativeDeepLink();

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
      // The chat overlay lives above every route so the WebView (and the CES
      // session inside it) survives navigation and minimise / restore.
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const ChatOverlay(),
          ],
        );
      },
      // Fork on launch: if the URL brought SSO hand-off params, validate the
      // customer id against the backend and go straight to AppShell. Otherwise
      // (or on any validation failure) fall back to the standard login screen.
      home: AppStartup.pendingCustomerId != null
          ? _SsoBootstrap(customerId: AppStartup.pendingCustomerId!)
          : const LoginScreen(),
    );
  }
}

/// Splash-style widget shown for the brief moment we call the backend to
/// confirm the SSO customer id is real. On success it swaps itself for
/// AppShell (and pushes CardActivationScreen if a card id was also handed
/// off). On failure it falls back to LoginScreen so the user isn't stranded.
class _SsoBootstrap extends StatefulWidget {
  final String customerId;
  const _SsoBootstrap({required this.customerId});

  @override
  State<_SsoBootstrap> createState() => _SsoBootstrapState();
}

class _SsoBootstrapState extends State<_SsoBootstrap> {
  @override
  void initState() {
    super.initState();
    // Consume once — a subsequent hot-reload / rebuild shouldn't retry the
    // hand-off. The rest of the app already treats these as one-shot values.
    AppStartup.pendingCustomerId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final api = ApiService();
    final pendingCardId = AppStartup.pendingCardId;
    try {
      final data = await api.getHomeData(widget.customerId);
      if (!mounted) return;
      if (!data.customer.found) {
        _fallbackToLogin();
        return;
      }

      // Mirror the post-success side effects that LoginScreen._login runs so
      // the FCM device is registered and biometrics can pick up next launch.
      FcmService.setCustomerId(widget.customerId);
      // ignore: unawaited_futures
      FcmService.requestPermissionAndGetToken().then((token) async {
        if (token == null) return;
        try {
          await api.registerDevice(widget.customerId, token);
        } catch (e) {
          debugPrint('Device registration failed: $e');
        }
      });
      // ignore: unawaited_futures
      BiometricAuthService.instance.remember(widget.customerId);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AppShell(customerId: widget.customerId),
        ),
      );

      if (pendingCardId != null) {
        AppStartup.pendingCardId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => CardActivationScreen(cardId: pendingCardId),
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('SSO hand-off failed: $e');
      if (mounted) _fallbackToLogin();
    }
  }

  void _fallbackToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Same background gradient as LoginScreen so the swap doesn't flash.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.9),
              AppColors.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.4, 0.7],
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
        ),
      ),
    );
  }
}
