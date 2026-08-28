import 'package:flutter/foundation.dart';

/// Where the persistent chat overlay is on screen.
enum ChatOverlayMode {
  /// Never opened this session — nothing rendered, WebView not yet mounted.
  hidden,

  /// Shrunk to a small draggable bubble at bottom-right. WebView stays mounted
  /// (behind Offstage) so the GECX session survives.
  minimized,

  /// Full chat panel overlaying the current route.
  expanded,
}

/// App-wide singleton driving [ChatOverlay]. Callers set the customer id once
/// (from login) then call [open] / [minimize] / [close] to move between modes.
///
/// State lives here instead of a StatefulWidget because we need it accessible
/// from anywhere in the tree (dashboard FAB, activation success screen, deep
/// links, etc.) without threading a ref through every widget.
class ChatOverlayController {
  ChatOverlayController._();
  static final ChatOverlayController instance = ChatOverlayController._();

  /// Current overlay position. UI code listens with [ValueListenableBuilder].
  final ValueNotifier<ChatOverlayMode> mode =
      ValueNotifier<ChatOverlayMode>(ChatOverlayMode.hidden);

  /// Bumped whenever a bot response arrives while the overlay is minimised, so
  /// the bubble can show a red dot. Cleared on [open].
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  /// Signed-in customer id, propagated so the WebView can pass it to CES.
  /// Backed by a ValueNotifier so the overlay can rebuild when the shell
  /// sets it on login (otherwise the persistent bubble wouldn't appear
  /// until the user opened the chat once).
  final ValueNotifier<String?> customerIdN = ValueNotifier<String?>(null);
  String? get customerId => customerIdN.value;
  set customerId(String? v) => customerIdN.value = v;

  /// Set by quick-action tiles: the utterance that should be sent to CES once
  /// the WebView is loaded. Consumed and cleared by [ChatOverlay] on flush.
  /// Held here (not passed via a method) so tiles can fire-and-forget without
  /// knowing anything about the WebView lifecycle.
  String? pendingUtterance;

  /// First-time entry: mount the WebView and expand the panel. Idempotent — if
  /// the overlay is already up in any mode, we just expand it and clear unread.
  void open(String cid) {
    customerId = cid;
    unread.value = 0;
    mode.value = ChatOverlayMode.expanded;
  }

  /// Shrink to the bubble without unmounting. Session persists.
  void minimize() {
    if (mode.value == ChatOverlayMode.expanded) {
      mode.value = ChatOverlayMode.minimized;
    }
  }

  /// Tear the overlay down completely. The next [open] will start a fresh GECX
  /// session (WebView is disposed and re-created by [ChatOverlay]).
  void close() {
    mode.value = ChatOverlayMode.hidden;
  }

  /// Called by the WebView JS bridge when a new bot bubble arrives and the
  /// panel isn't currently expanded. Increments the red-dot counter.
  void noteIncomingWhileMinimized() {
    if (mode.value != ChatOverlayMode.expanded) {
      unread.value = unread.value + 1;
    }
  }
}
