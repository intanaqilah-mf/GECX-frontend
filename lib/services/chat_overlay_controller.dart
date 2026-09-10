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

  /// Reference count tracking how many screens currently want the chat bubble
  /// hidden. Use [pushSuppressBubble] in initState and [popSuppressBubble] in
  /// dispose — never toggle [suppressChatBubble] directly.
  ///
  /// Why a counter instead of a plain bool: Flutter's [Navigator.pushReplacement]
  /// calls the *new* screen's initState before it calls the *old* screen's
  /// dispose. A simple bool toggle therefore races: the new screen sets true,
  /// then the old screen's dispose sets it back to false. The counter survives
  /// that overlap — it goes 1 → 2 (new screen) → 1 (old dispose) → 0 (new
  /// dispose), never reaching 0 prematurely.
  int _suppressRefCount = 0;

  /// Notifier that [ChatOverlay] listens to. True when at least one screen has
  /// called [pushSuppressBubble] without a matching [popSuppressBubble].
  /// An already-expanded panel is NOT suppressed — if the user explicitly
  /// opened the chat before navigating to an activation screen the panel stays
  /// visible until they dismiss it.
  final ValueNotifier<bool> suppressChatBubble = ValueNotifier<bool>(false);

  /// Call from a screen's [State.initState] to hide the chat bubble while that
  /// screen is on the stack.
  void pushSuppressBubble() {
    _suppressRefCount++;
    if (!suppressChatBubble.value) suppressChatBubble.value = true;
  }

  /// Call from a screen's [State.dispose] to release its suppress hold. The
  /// bubble reappears only when every active screen has released its hold.
  void popSuppressBubble() {
    if (_suppressRefCount > 0) _suppressRefCount--;
    if (_suppressRefCount == 0 && suppressChatBubble.value) {
      suppressChatBubble.value = false;
    }
  }

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
