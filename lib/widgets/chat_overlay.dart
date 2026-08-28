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

  @override
  void initState() {
    super.initState();
    // Rebuild whenever the overlay mode changes so we can lazy-init the
    // WebView the first time it's actually needed.
    ChatOverlayController.instance.mode.addListener(_onModeChanged);
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
      registerWebViewFactory(
        'acn-chat-iframe',
        'https://emvnzir-canada-song.web.app/chat.html',
      );
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
    return ValueListenableBuilder<ChatOverlayMode>(
      valueListenable: ChatOverlayController.instance.mode,
      builder: (context, mode, _) {
        if (mode == ChatOverlayMode.hidden) return const SizedBox.shrink();

        // Both panel and bubble sit in one Stack. The panel is always in the
        // tree while mode != hidden (Offstage when minimized) so the WebView
        // is never torn down — CES session persists across minimise.
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: Stack(
              children: [
                Offstage(
                  offstage: mode != ChatOverlayMode.expanded,
                  child: _ChatPanel(webController: _webController),
                ),
                if (mode == ChatOverlayMode.minimized) const _ChatBubble(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen (with margins) chat panel. Renders the WebView.
class _ChatPanel extends StatelessWidget {
  const _ChatPanel({required this.webController});
  final WebViewController? webController;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildHeader(context),
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: const Color(0xFF140025),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'ACN AI Assistant',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Minimise → keep session, shrink to bubble.
          IconButton(
            tooltip: 'Minimise',
            icon: const Icon(Icons.minimize, color: Colors.white),
            onPressed: () => ChatOverlayController.instance.minimize(),
          ),
          // Close → destroy session, next open is fresh.
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => ChatOverlayController.instance.close(),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.only(right: 18, bottom: 24),
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
