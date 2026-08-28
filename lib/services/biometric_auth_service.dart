import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small wrapper around `local_auth` + `flutter_secure_storage` that lets
/// the login screen offer Apple-style Face ID / Touch ID fast sign-in.
///
/// After a successful manual sign-in with a customer id, we store the id in
/// the platform Keychain / Keystore. On subsequent launches, if biometrics
/// is available, the login screen shows a "Sign in with Face ID" button.
/// Tapping it triggers the OS biometric prompt; on success we return the
/// stored customer id so the login screen can complete the flow with the
/// same code path as manual sign-in.
class BiometricAuthService {
  BiometricAuthService._();
  static final BiometricAuthService instance = BiometricAuthService._();

  final LocalAuthentication _auth = LocalAuthentication();

  // SharedPreferences instead of flutter_secure_storage: the customer id is
  // a lookup key, not a credential — Firestore rules gate the actual data.
  // Also keeps the app dart2wasm-compatible (secure_storage_web uses
  // deprecated dart:html which the wasm dry-run flags).
  static const _kCustomerIdKey = 'acn_biometric_customer_id';

  /// True if the device has hardware AND the user has enrolled at least one
  /// biometric. Web / macOS-not-configured return false and we hide the FAB.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    // macOS Studio simulator throws for local_auth; guard.
    if (defaultTargetPlatform == TargetPlatform.macOS) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final can = await _auth.canCheckBiometrics;
      if (!can) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Which icon / label to show on the login button. Face ID first, then
  /// fingerprint, then generic "Biometrics".
  Future<BiometricLabel> preferredLabel() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return BiometricLabel.face;
      if (types.contains(BiometricType.fingerprint)) {
        return BiometricLabel.fingerprint;
      }
      if (types.contains(BiometricType.strong) ||
          types.contains(BiometricType.weak)) {
        return BiometricLabel.generic;
      }
      return BiometricLabel.generic;
    } catch (_) {
      return BiometricLabel.generic;
    }
  }

  /// Reads the remembered customer id — null if the user has never enabled
  /// biometric login yet.
  Future<String?> rememberedCustomerId() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kCustomerIdKey);
    } catch (_) {
      return null;
    }
  }

  /// Persist the customer id so the next launch can offer biometric sign-in.
  Future<void> remember(String customerId) async {
    if (kIsWeb || customerId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCustomerIdKey, customerId);
    } catch (_) {/* non-fatal */}
  }

  /// Forget the remembered id (called on sign-out or by a Settings toggle).
  Future<void> forget() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCustomerIdKey);
    } catch (_) {/* non-fatal */}
  }

  /// Triggers the OS biometric prompt. Returns the customer id if the user
  /// authenticated AND we have one in storage, else null.
  Future<String?> authenticateAndGetCustomerId({
    String reason = 'Sign in to ACN Bank',
  }) async {
    final rememberedId = await rememberedCustomerId();
    if (rememberedId == null || rememberedId.isEmpty) return null;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return ok ? rememberedId : null;
    } catch (_) {
      return null;
    }
  }
}

enum BiometricLabel { face, fingerprint, generic }
