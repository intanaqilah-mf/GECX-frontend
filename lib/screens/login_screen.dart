import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/fcm_service.dart';
import '../services/navigation_service.dart';
import '../widgets/app_shell.dart';
import 'card_activation_screen.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _customerIdController = TextEditingController(text: 'CUST_DOC_7777');
  bool _isLoading = false;

  final _apiService = ApiService();

  // ── Biometric fast sign-in ───────────────────────────────────────────────
  bool _biometricReady = false;   // has hardware + enrolled + a stored id
  BiometricLabel _biometricLabel = BiometricLabel.generic;

  @override
  void initState() {
    super.initState();
    _probeBiometrics();
  }

  Future<void> _probeBiometrics() async {
    final svc = BiometricAuthService.instance;
    final available = await svc.isAvailable();
    final remembered = await svc.rememberedCustomerId();
    final label = await svc.preferredLabel();
    if (!mounted) return;
    setState(() {
      _biometricReady = available && (remembered != null && remembered.isNotEmpty);
      _biometricLabel = label;
    });
  }

  Future<void> _biometricLogin() async {
    setState(() => _isLoading = true);
    final id = await BiometricAuthService.instance.authenticateAndGetCustomerId();
    if (!mounted) return;
    if (id == null || id.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric sign-in cancelled.')),
      );
      return;
    }
    // Reuse the manual login path — same fetch + navigate.
    _customerIdController.text = id;
    _login();
  }

  void _registerDeviceSilently(String customerId) {
    FcmService.setCustomerId(customerId);
    FcmService.requestPermissionAndGetToken().then((token) async {
      if (token == null) return;
      try {
        await _apiService.registerDevice(customerId, token);
      } catch (e) {
        debugPrint('Device registration failed: $e');
      }
    });
  }

  void _login() async {
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Pre-fetch home data to ensure the ID is valid and backend is reachable
      final data = await _apiService.getHomeData(customerId);
      if (mounted) {
        if (data.customer.found) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AppShell(customerId: customerId),
            ),
          );
          // Fire-and-forget registration via a non-async helper to avoid the
          // unawaited_futures lint; login should not block on this.
          _registerDeviceSilently(customerId);
          // Remember for next launch so Face ID / Touch ID can sign back in
          // without re-typing the customer id. Fire-and-forget.
          // ignore: unawaited_futures
          BiometricAuthService.instance.remember(customerId);
          final pendingCardId = AppStartup.pendingCardId;
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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer ID not found in database.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection Error: Make sure your backend is running. ($e)')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
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
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: const Icon(Icons.account_balance, color: AppColors.primary, size: 40),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'ACN Bank',
                    style: GoogleFonts.inter(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Premier Banking Experience',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Sign In',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _customerIdController,
                          decoration: InputDecoration(
                            labelText: 'Customer ID',
                            hintText: 'Enter your ID',
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Text(
                                    'Sign In',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        if (_biometricReady) ...[
                          const SizedBox(height: 16),
                          _biometricDivider(),
                          const SizedBox(height: 12),
                          _biometricButton(),
                        ],
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton(
                            onPressed: () {},
                            child: Text(
                              'Forgot Customer ID?',
                              style: GoogleFonts.inter(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'v2.4.0 • Secured by ACN Shield',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Biometric UI helpers ───────────────────────────────────────────────
  Widget _biometricDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or',
              style: GoogleFonts.inter(
                  color: AppColors.onSurfaceVariant, fontSize: 12)),
        ),
        Expanded(child: Container(height: 1, color: AppColors.outlineVariant)),
      ],
    );
  }

  Widget _biometricButton() {
    late final IconData icon;
    late final String label;
    switch (_biometricLabel) {
      case BiometricLabel.face:
        icon = Icons.face_retouching_natural;
        label = 'Sign in with Face ID';
        break;
      case BiometricLabel.fingerprint:
        icon = Icons.fingerprint;
        label = 'Sign in with Touch ID';
        break;
      case BiometricLabel.generic:
        icon = Icons.lock_person;
        label = 'Sign in with biometrics';
        break;
    }
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _biometricLogin,
        icon: Icon(icon, color: AppColors.primary),
        label: Text(label,
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
