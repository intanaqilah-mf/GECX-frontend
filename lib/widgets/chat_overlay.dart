import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../services/chat_overlay_controller.dart';
import '../services/fcm_service.dart';
import '../services/platform_utils.dart'
    if (dart.library.html) '../services/platform_utils_web.dart';
import '../theme/app_colors.dart';

/// Persistent chat overlay mounted once at the app root via
/// [MaterialApp.builder]. Owns the WebViewController for the whole app
/// lifetime so the GECX session survives navigation between screens and
/// survives minimising the chat.
///
/// Modes come from [ChatOverlayController.mode]:
///   hidden    → nothing rendered (WebView not yet mounted)
///   minimized → small bubble bottom-right; WebView still mounted (Offstage)
///   expanded  → full chat panel over the current route
class ChatOverlay extends StatefulWidget {
  const ChatOverlay({super.key});

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay> {
  WebViewController? _webController;

  /// True after the WebView has been created for this session. Reset to false
  /// when the controller closes the overlay so [close] gives a fresh session
  /// on the next open.
  bool _webInited = false;

  /// True once the Flutter-web `HtmlElementView` factory has been registered.
  /// Registering twice with the same viewType throws; skipping registration
  /// makes the panel's HtmlElementView throw a TypeError instead of rendering.
  /// So we register exactly once, eagerly, on first mount.
  bool _webFactoryRegistered = false;

  @override
  void initState() {
    super.initState();
    // Rebuild whenever the overlay mode changes so we can lazy-init the
    // WebView the first time it's actually needed.
    ChatOverlayController.instance.mode.addListener(_onModeChanged);

    // On Flutter web the panel now lives permanently in the tree (Offstage
    // when not expanded), so its HtmlElementView is asked to build before
    // the panel ever opens. Register the iframe factory here so it always
    // exists by the time the tree is walked.
    if (kIsWeb && !_webFactoryRegistered) {
      registerWebViewFactory(
        'acn-chat-iframe',
        'https://emvnzir-canada-song.web.app/chat.html',
      );
      _webFactoryRegistered = true;
    }
  }

  @override
  void dispose() {
    ChatOverlayController.instance.mode.removeListener(_onModeChanged);
    super.dispose();
  }

  void _onModeChanged() {
    final mode = ChatOverlayController.instance.mode.value;
    if (mode == ChatOverlayMode.hidden) {
      // Full close: drop the WebView so the next open builds a fresh CES
      // session. Setting the controller to null unmounts the WebViewWidget.
      setState(() {
        _webController = null;
        _webInited = false;
      });
      return;
    }
    if (!_webInited) {
      _initWebView();
    } else if (mode == ChatOverlayMode.expanded) {
      // WebView already loaded from a previous open — the onPageFinished
      // trigger won't fire again, so flush any queued utterance directly.
      _flushPendingIfLoaded();
    }
    // Any expanded/minimized transition still needs a rebuild to swap the
    // panel/bubble UI.
    if (mounted) setState(() {});
  }

  void _initWebView() {
    _webInited = true;

    if (kIsWeb) {
      // Factory was already registered eagerly in initState; nothing to do
      // here on web — the HtmlElementView will pick it up automatically.
      return;
    }

    var params = const PlatformWebViewControllerCreationParams();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // Bridge back from chat.html — activation deep links + external URLs
      // (Explore Travel Store etc.) hop out through here.
      ..addJavaScriptChannel(
        'ActivationBridge',
        onMessageReceived: _onActivationBridgeMessage,
      )
      // Lets JS notify the controller that a new bot bubble arrived while the
      // overlay is minimised, so the bubble shows an unread dot.
      ..addJavaScriptChannel(
        'ChatOverlayBridge',
        onMessageReceived: (m) {
          if (m.message == 'incoming') {
            ChatOverlayController.instance.noteIncomingWhileMinimized();
          }
        },
      );

    // Nav delegate is set AFTER the cascade so its closure can capture the
    // controller reference for the runJavaScript flush call.
    controller.setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
      final pending = ChatOverlayController.instance.pendingUtterance;
      if (pending == null || pending.isEmpty) return;
      ChatOverlayController.instance.pendingUtterance = null;
      // Give the welcome-event runSession a beat to land first — otherwise
      // it and our utterance race.
      Future.delayed(const Duration(milliseconds: 900), () {
        final safe = pending.replaceAll("'", r"\'");
        controller.runJavaScript(
          'try{addUserBubble("$safe");showTyping();window._gecxSend("$safe");}'
          'catch(e){console.warn("[ACN] quick-action send failed",e);}',
        );
      });
    }));

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = controller.platform as AndroidWebViewController;
      android.setMediaPlaybackRequiresUserGesture(false);
    }

    controller.loadRequest(
      Uri.parse('https://emvnzir-canada-song.web.app/chat.html'),
    );

    _webController = controller;
  }

  /// Called from the overlay's outer listener whenever mode goes to expanded
  /// and the WebView is already loaded — flushes a queued utterance instantly
  /// (no page-load event to wait for).
  void _flushPendingIfLoaded() {
    if (_webController == null) return;
    final pending = ChatOverlayController.instance.pendingUtterance;
    if (pending == null || pending.isEmpty) return;
    ChatOverlayController.instance.pendingUtterance = null;
    final safe = pending.replaceAll("'", r"\'");
    _webController!.runJavaScript(
      'try{addUserBubble("$safe");showTyping();window._gecxSend("$safe");}'
      'catch(e){console.warn("[ACN] quick-action send failed",e);}',
    );
  }

  void _onActivationBridgeMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';
      final value = data['value'] as String? ?? '';
      if (type == 'deep_link') {
        FcmService.navigateToActivation(value);
      } else if (type == 'open_url') {
        final uri = Uri.tryParse(value);
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('ActivationBridge error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever either mode OR customerId changes so the persistent
    // bubble appears the moment the shell hands us an id after login.
    final ctrl = ChatOverlayController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([ctrl.mode, ctrl.customerIdN]),
      builder: (context, _) {
        final mode = ctrl.mode.value;
        final cid = ctrl.customerId;
        final loggedIn = cid != null && cid.isNotEmpty;

        // Before login there's no reason to draw the overlay. After login,
        // if the panel isn't open we still render the bubble as a persistent
        // entry point at bottom-right — matches the web app's fc-fab.
        if (mode == ChatOverlayMode.hidden && !loggedIn) {
          return const SizedBox.shrink();
        }

        // IMPORTANT — do NOT use Offstage to hide the panel. On Flutter web
        // the panel contains HtmlElementView, and Offstage lets the platform
        // view create its <iframe> in the DOM at (0,0) even though the tree
        // says it's hidden. That's what greyed the whole app out. Instead
        // we conditionally include the panel ONLY when expanded. On web
        // this means the CES session doesn't survive close/minimise — a
        // deliberate trade-off to keep the app usable.
        final content = Stack(
          children: [
            if (mode == ChatOverlayMode.expanded)
              _ChatPanel(webController: _webController),
            if (mode != ChatOverlayMode.expanded) const _ChatBubble(),
          ],
        );

        // Positioned MUST be a direct child of the Stack in main.dart's
        // MaterialApp.builder. Returning it from inside LayoutBuilder.builder
        // makes it a child of LayoutBuilder instead, and Positioned then tries
        // to write StackParentData onto a render object that uses BoxParentData
        // -> "type X is not a subtype of type Y", which in a release build
        // paints the whole subtree as a grey ErrorWidget over the app.
        // So: Positioned on the OUTSIDE, LayoutBuilder on the inside.
        return Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Wide screens (tablet / desktop / Flutter web): constrain to
                // the same phone-shaped column AppShell uses so the chat sits
                // inside the app, not out in the browser gutter.
                if (constraints.maxWidth <= 520) return content;
                return Center(
                  child: SizedBox(
                    width: 460, // matches AppShell's maxWidth
                    height: constraints.maxHeight,
                    child: content,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Bottom-right floating chat panel — matches the acn-bank-demo web widget:
/// a compact phone-shaped card at bottom-right on wide screens; near-fullscreen
/// on phones. Light header (no dark chrome). Backdrop dimmed slightly so the
/// underlying app stays visible.
class _ChatPanel extends StatelessWidget {
  const _ChatPanel({required this.webController});
  final WebViewController? webController;

  void _resetConversation() {
    // Fires chat.html's own reset routine — clears the message list, drops
    // the GECX init flag, and re-registers the context so the welcome event
    // plays again. Works on native only (WebViewController); on web the
    // iframe has its own reset button available via #acn-chat-reset.
    webController?.runJavaScript(
      'try{resetChat();}catch(e){console.warn("[ACN] resetChat failed",e);}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 520;
    // Bottom-right anchored floating card on tablet/web.
    // On phones, take (almost) the full screen with side gutters.
    final panelWidth = isWide ? 400.0 : size.width - 24;
    final panelHeight = isWide
        ? (size.height - 80).clamp(400.0, 680.0)
        : size.height * 0.85;

    return Stack(
      children: [
        // Dim backdrop — tap-to-minimise so the user doesn't feel trapped.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ChatOverlayController.instance.minimize(),
            child: Container(color: Colors.black.withValues(alpha: 0.28)),
          ),
        ),
        Positioned(
          right: isWide ? 24 : 12,
          bottom: isWide ? 24 : 12,
          child: SafeArea(
            child: Material(
              elevation: 12,
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: Column(
                  children: [
                    _Header(onReset: _resetConversation),
                    Expanded(
                      child: kIsWeb
                          ? const HtmlElementView(viewType: 'acn-chat-iframe')
                          : webController == null
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary),
                                )
                              : WebViewWidget(controller: webController!),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onReset;
  const _Header({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Light chrome — no more dark bar. Matches the web widget header.
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              'A',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ACN Bank AI',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF140025),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A6E3C),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Online',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1A6E3C),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Reset the conversation (fires chat.html's resetChat() over the
          // JS bridge). Same icon as the web widget's "new conversation".
          _HeaderIcon(icon: Icons.autorenew, onTap: onReset),
          // Minimise → keep session, shrink to bubble. Uses a plain InkWell
          // (no Tooltip) so no Overlay ancestor is required.
          _HeaderIcon(
            icon: Icons.remove,
            onTap: () => ChatOverlayController.instance.minimize(),
          ),
          _HeaderIcon(
            icon: Icons.close,
            onTap: () => ChatOverlayController.instance.close(),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: const Color(0xFF6B5B8A), size: 18),
      ),
    );
  }
}

/// Draggable-looking chat bubble at bottom-right. Tap → re-expand.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      // Lifted above the ~62 px BottomAppBar in AppShell so the FAB always
      // sits clear of the tab strip (bar height + notch + safe-area).
      child: Padding(
        padding: const EdgeInsets.only(right: 18, bottom: 84),
        child: ValueListenableBuilder<int>(
          valueListenable: ChatOverlayController.instance.unread,
          builder: (context, unread, _) {
            return GestureDetector(
              onTap: () {
                final cid = ChatOverlayController.instance.customerId ?? '';
                ChatOverlayController.instance.open(cid);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chat_bubble,
                        color: Colors.white, size: 26),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 20, minHeight: 20),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
