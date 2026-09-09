import 'package:flutter/foundation.dart';

/// Broadcasts application-lifecycle signals across the app. FcmService bumps
/// [ApplicationEvents.instance] whenever a push arrives with
/// `action == "application_updated"`; the Apply tab listens and re-fetches.
///
/// This is a `ChangeNotifier` (not a stream) so any StatefulWidget can just
/// `addListener` in initState / `removeListener` in dispose without pulling
/// in a state-management package.
class ApplicationEvents extends ChangeNotifier {
  ApplicationEvents._();
  static final ApplicationEvents instance = ApplicationEvents._();

  String? _lastApplicationId;
  String? get lastApplicationId => _lastApplicationId;

  String? _lastStatus;
  String? get lastStatus => _lastStatus;

  /// Called by FcmService when a lifecycle push lands. Payload keys we look
  /// at: `application_id`, `status`.
  void notifyUpdate({String? applicationId, String? status}) {
    _lastApplicationId = applicationId;
    _lastStatus = status;
    notifyListeners();
  }
}
