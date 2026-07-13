import 'package:flutter/material.dart';

// Shared navigator and scaffold-messenger keys so FcmService can push routes
// and show SnackBars without holding a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
