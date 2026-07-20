import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, SystemUiOverlayStyle;
import 'package:flutter/foundation.dart' show kIsWeb, compute, defaultTargetPlatform, TargetPlatform;
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:image_picker/image_picker.dart';

import '../services/platform_utils.dart'
    if (dart.library.html) '../services/platform_utils_web.dart';
import '../theme/app_colors.dart';

List<Map<String, String>> _encodeCardImages(Map<String, Uint8List> byteMap) {
  return byteMap.entries.map((e) => {
    'name': e.key,
    'image_url': 'data:image/png;base64,${base64Encode(e.value)}',
    'description': 'Premium benefits for your lifestyle.',
  }).toList();
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, required this.customerId});
  final String customerId;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  late final WebViewController _webController;
  bool _isWebViewReady = false;
  bool _hasInjectedCards = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      registerWebViewFactory('acn-chat-iframe', '${Uri.base.origin}/chat.html');
      _isWebViewReady = true;
    } else {
      _initWebViewController();
    }
  }

  Future<void> _initWebViewController() async {
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    }

    _webController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidController = _webController.platform as AndroidWebViewController;
      await androidController.setOnShowFileSelector(_onShowFileChooser);
      await androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    if (!kIsWeb) {
      _webController.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (!_hasInjectedCards) {
              _hasInjectedCards = true;
              _injectCardData();
            }
          },
        ),
      );
      _webController.loadHtmlString(_getChatHtml(), baseUrl: 'https://acnbank.ca');
    } else {
      final String origin = Uri.base.origin;
      final String path = origin.endsWith('/') ? 'chat.html' : '/chat.html';
      _webController.loadRequest(Uri.parse('$origin$path'));
    }

    setState(() => _isWebViewReady = true);
  }

  Future<List<String>> _onShowFileChooser(FileSelectorParams params) async {
    if (!mounted) return [];

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return [];
    final XFile? file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (file == null) return [];
    return [file.path];
  }

  Future<void> _injectCardData() async {
    const cardImages = {
      'Visa Platinum': 'lib/assets/ChatGPT Image May 24, 2026, 06_03_30 PM.png',
      'World Elite Mastercard': 'lib/assets/ChatGPT Image May 24, 2026, 06_05_06 PM.png',
      'Infinite Cashback': 'lib/assets/ChatGPT Image May 24, 2026, 06_06_18 PM.png',
      'Student Rewards': 'lib/assets/ChatGPT Image May 24, 2026, 06_07_55 PM.png',
      'Business Gold': 'lib/assets/ChatGPT Image May 24, 2026, 06_09_25 PM.png',
    };

    final Map<String, Uint8List> byteMap = {};
    for (final entry in cardImages.entries) {
      try {
        final data = await rootBundle.load(entry.value);
        byteMap[entry.key] = data.buffer.asUint8List();
      } catch (e) {
        debugPrint('Error loading asset ${entry.value}: $e');
      }
    }

    final cards = await compute(_encodeCardImages, byteMap);
    final String jsonCards = jsonEncode(cards);
    await _webController.runJavaScript(
      'window.ACN_AVAILABLE_CARDS = $jsonCards; console.log("ACN Cards injected");',
    );
  }

  String _getChatHtml() {
    return r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0,
    maximum-scale=1.0, user-scalable=no">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <script src="https://www.gstatic.com/chat-messenger/sdk/prod/v1.16/chat-messenger.js"></script>
  <style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0;}
body{font-family:'DM Sans',-apple-system,BlinkMacSystemFont,'Segoe UI','Segoe UI Emoji','Apple Color Emoji','Noto Color Emoji',sans-serif;background:#fff;color:#140025;overflow-x:hidden;}
button{font-family:inherit;cursor:pointer;border:none;outline:none;}
#acn-chat-window{position:fixed;bottom:24px;right:24px;width:400px;height:680px;background:#fff;border-radius:20px;box-shadow:0 8px 48px rgba(161,0,255,.18),0 2px 16px rgba(0,0,0,.08);display:none;flex-direction:column;overflow:hidden;z-index:10000;font-family:'DM Sans',-apple-system,sans-serif;}
#acn-chat-window.open{display:flex;}
#acn-chat-header{background:#fff;border-bottom:1px solid #EBEBEB;padding:12px 15px;display:flex;align-items:center;gap:10px;flex-shrink:0;}
#acn-chat-avatar{width:36px;height:36px;border-radius:50%;background:#A100FF;color:#fff;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:800;flex-shrink:0;}
#acn-chat-title-wrap{flex:1;}
#acn-chat-title{font-size:15px;font-weight:800;color:#140025;letter-spacing:-.3px;}
#acn-chat-status{font-size:11px;color:#1A6E3C;display:flex;align-items:center;gap:4px;margin-top:2px;}
#acn-chat-status-dot{width:6px;height:6px;border-radius:50%;background:#1A6E3C;}
#acn-chat-close{width:30px;height:30px;border-radius:50%;background:transparent;border:none;font-size:20px;color:#6B5B8A;display:flex;align-items:center;justify-content:center;cursor:pointer;transition:background .15s;line-height:1;}
#acn-chat-close:hover{background:#F5EEFF;color:#A100FF;}
#acn-chat-reset:hover{background:#F5EEFF !important;color:#A100FF !important;}
#acn-chat-messages{flex:1;overflow-y:auto;padding:14px 13px;background:#F7F4FC;display:flex;flex-direction:column;gap:10px;scroll-behavior:smooth;}
#acn-chat-messages::-webkit-scrollbar{width:4px;}
#acn-chat-messages::-webkit-scrollbar-thumb{background:#D0B8F0;border-radius:4px;}
.acn-bot-bubble{background:#fff;border:1px solid #EBEBEB;border-top:3px solid #A100FF;border-radius:4px 18px 18px 18px;padding:15px 17px;font-size:14px;font-weight:400;color:#2D2D2D;line-height:1.65;max-width:94%;align-self:flex-start;}
.acn-bot-bubble strong{font-weight:800;color:#140025;}
.acn-bot-bubble em{color:#6B6B6B;font-style:italic;font-weight:400;}
.acn-combo-card{background:#fff;border:1px solid #EBEBEB;border-top:3px solid #A100FF;border-radius:4px 18px 18px 18px;max-width:98%;align-self:flex-start;overflow:hidden;}
.acn-combo-card .acn-combo-text{padding:15px 17px 10px;font-size:14px;color:#2D2D2D;line-height:1.65;}
.acn-combo-card .acn-combo-tiles{padding:4px 12px 12px;}
.acn-combo-card .acn-tile{background:#fff;border:1px solid #EBEBEB;border-radius:10px;padding:13px 16px;margin-bottom:7px;cursor:pointer;display:block;width:100%;text-align:left;transition:border-color .18s,background .18s;}
.acn-combo-card .acn-tile:last-child{margin-bottom:0;}
.acn-combo-card .acn-tile:hover{border-color:#C070FF;background:#FDFAFF;}
.acn-combo-card .acn-tile-title{font-size:14px;font-weight:700;color:#140025;display:block;margin-bottom:3px;line-height:1.3;}
.acn-combo-card .acn-tile-desc{font-size:12.5px;color:#6E6E80;display:block;line-height:1.4;}
.acn-user-bubble{background:#A100FF;color:#fff;border-radius:18px 4px 18px 18px;padding:11px 16px;font-size:14px;font-weight:500;line-height:1.5;max-width:80%;align-self:flex-end;box-shadow:0 2px 12px rgba(161,0,255,.3);}
.acn-typing{background:#fff;border:1px solid #EBEBEB;border-top:3px solid #A100FF;border-radius:4px 18px 18px 18px;padding:14px 18px;align-self:flex-start;display:flex;gap:5px;align-items:center;}
.acn-typing span{width:7px;height:7px;border-radius:50%;background:#D0B8F0;animation:acnTyping 1.2s infinite;}
.acn-typing span:nth-child(2){animation-delay:.2s;}
.acn-typing span:nth-child(3){animation-delay:.4s;}
@keyframes acnTyping{0%,60%,100%{transform:translateY(0)}30%{transform:translateY(-6px);background:#A100FF;}}
.acn-tiles-wrap{background:transparent;padding:0;margin-top:2px;}
.acn-tile{background:#fff;border:1px solid #EBEBEB;border-radius:12px;padding:15px 18px;margin-bottom:8px;cursor:pointer;transition:border-color .18s,background .18s,box-shadow .18s;display:block;width:100%;text-align:left;box-shadow:none;}
.acn-tile:last-child{margin-bottom:0;}
.acn-tile:hover{border-color:#C070FF;background:#FDFAFF;box-shadow:0 2px 12px rgba(161,0,255,0.08);}
.acn-tile:active{background:#F5EEFF;border-color:#A100FF;}
.acn-tile-title{font-size:15px;font-weight:700;color:#140025;display:block;margin-bottom:4px;line-height:1.3;font-family:'DM Sans',-apple-system,sans-serif;}
.acn-tile-desc{font-size:13px;color:#6E6E80;display:block;line-height:1.45;font-weight:400;font-family:'DM Sans',-apple-system,sans-serif;}
.acn-carousel-wrap{background:#fff;border:1px solid #EDE5F8;border-top:3px solid #A100FF;border-radius:16px;overflow:hidden;margin-top:4px;}
.acn-carousel-header{padding:14px 16px;border-bottom:1px solid #EDE5F8;display:flex;justify-content:space-between;align-items:flex-start;}
.acn-carousel-title{font-size:14px;font-weight:700;color:#140025;}
.acn-carousel-sub{font-size:11px;color:#6B5B8A;margin-top:2px;}
.acn-cards-track{display:flex;gap:12px;padding:14px 16px;overflow-x:auto;scrollbar-width:thin;scrollbar-color:#D0B0F0 transparent;}
.acn-card{min-width:160px;max-width:180px;flex-shrink:0;background:#fff;border:1px solid #EDE5F8;border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:8px;}
.acn-card-name{font-size:12px;font-weight:700;color:#140025;line-height:1.3;}
.acn-card-amount{font-size:20px;font-weight:800;color:#140025;letter-spacing:-.5px;}
.acn-card-currency{font-size:11px;color:#6B5B8A;margin-right:2px;}
.acn-card-date{font-size:10px;color:#A090C0;}
.acn-badge{display:inline-block;padding:3px 10px;border-radius:20px;font-size:10px;font-weight:600;border:1px solid transparent;}
.acn-badge-active,.acn-badge-paid{background:#EAFBF0;color:#1A6E3C;border-color:#90D8A8;}
.acn-badge-frozen,.acn-badge-blocked{background:#FFF1F1;color:#8A1C1C;border-color:#F0A0A0;}
.acn-badge-pending,.acn-badge-processing{background:#FFF8E8;color:#7A5A00;border-color:#F0CC60;}
.acn-badge-available{background:#F5EEFF;color:#7000BB;border-color:#D0B0F0;}
.acn-badge-scheduled{background:#E5F6FA;color:#0E6070;border-color:#80CCE0;}
.acn-cta-btn{margin-top:auto;padding:8px 12px;border-radius:8px;font-size:12px;font-weight:600;cursor:pointer;border:none;font-family:inherit;transition:background .15s;}
.acn-cta-active{background:#A100FF;color:#fff;}
.acn-cta-active:hover{background:#7500C0;}
.acn-cta-inactive{background:#F5F5F5;color:#A090C0;cursor:default;}
.acn-carousel-footer{padding:8px 14px;border-top:1px solid #EDE5F8;background:#FDFAFF;display:flex;justify-content:center;align-items:center;gap:5px;}
.acn-powered-dot{width:5px;height:5px;border-radius:50%;background:#A100FF;}
.acn-powered-text{font-size:9px;color:#A090C0;}
#acn-chat-input-bar{background:#fff;border-top:1px solid #EBEBEB;padding:10px 12px;display:flex;align-items:center;gap:6px;flex-shrink:0;}
#acn-chat-input{flex:1;background:#F4F1F9;border:1px solid #E8E3F0;border-radius:20px;padding:10px 15px;font-size:13.5px;font-family:'DM Sans',-apple-system,sans-serif;color:#140025;outline:none;transition:border-color .15s,background .15s;}
#acn-chat-input:focus{border-color:#A100FF;background:#fff;}
#acn-chat-input::placeholder{color:#A090C0;}
#acn-chat-send{width:36px;height:36px;border-radius:50%;background:#A100FF;border:none;display:flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0;box-shadow:0 2px 8px rgba(161,0,255,.3);transition:background .15s,transform .1s;}
#acn-chat-send:hover{background:#8800DD;transform:scale(1.05);}
#acn-chat-send:active{transform:scale(0.96);}
html, body {
  height: 100%; width: 100%;
  overflow: hidden; margin: 0; padding: 0;
}
#acn-chat-window {
  position: static !important;
  width: 100% !important;
  height: 100vh !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  display: flex !important;
  bottom: auto !important;
  right: auto !important;
}
#acn-chat-header { display: none; }
  </style>
</head>
<body>

<!-- Hidden SDK — API bridge only, no visible UI -->
<div style="position:fixed;bottom:0;right:0;width:0;height:0;overflow:hidden;">
  <chat-messenger id="gecx-messenger" url-allowlist="*"
    language-code="en" max-query-length="-1">
    <chat-messenger-container chat-title="ACN Bank AI">
      <chat-reset-session-button slot="titlebar-actions">
      </chat-reset-session-button>
    </chat-messenger-container>
  </chat-messenger>
</div>

<!-- Fullscreen chat UI — Flutter AppBar replaces the header -->
<div id="acn-chat-window">
  <div id="acn-chat-messages"></div>
  <div id="acn-chat-input-bar">
    <button onclick="document.getElementById('acn-file-input').click()"
      style="width:34px;height:34px;border-radius:50%;background:transparent;
             border:none;color:#A090C0;display:flex;align-items:center;
             justify-content:center;cursor:pointer;flex-shrink:0;">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" stroke-width="2" stroke-linecap="round"
        stroke-linejoin="round">
        <path d="M21.44 11.05l-9.19 9.19a6 6 0 01-8.49-8.49l9.19-9.19a4 4 0 015.66 5.66l-9.2 9.19a2 2 0 01-2.83-2.83l8.49-8.48"/>
      </svg>
    </button>
    <input id="acn-file-input" type="file" style="display:none;"
      onchange="handleFileUpload(this)"/>
    <input id="acn-chat-input" type="text"
      placeholder="Ask something..." autocomplete="off"/>
    <button id="acn-voice-btn" onclick="toggleVoice()"
      style="width:34px;height:34px;border-radius:50%;background:transparent;
             border:none;color:#A090C0;display:flex;align-items:center;
             justify-content:center;cursor:pointer;flex-shrink:0;">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" stroke-width="2" stroke-linecap="round"
        stroke-linejoin="round">
        <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/>
        <path d="M19 10v2a7 7 0 0 1-14 0v-2"/>
        <line x1="12" y1="19" x2="12" y2="23"/>
        <line x1="8" y1="23" x2="16" y2="23"/>
      </svg>
    </button>
    <button id="acn-chat-send" onclick="sendMessage()">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
        stroke="#fff" stroke-width="2.5" stroke-linecap="round"
        stroke-linejoin="round">
        <line x1="22" y1="2" x2="11" y2="13"/>
        <polygon points="22 2 15 22 11 13 2 9 22 2"/>
      </svg>
    </button>
  </div>
</div>

<script>
var _msgs = document.getElementById('acn-chat-messages');
var _input = document.getElementById('acn-chat-input');
var _sessionStarted = false;
var _gecxInitDone = false;

window.ACN_WIDGET_REGISTRY = {};

const BASE = "https://raw.githubusercontent.com/embadillo/acn-bank-assets/refs/heads/main/";
const PAYEE_LOGOS = {
  "hydro one":             BASE + "Hydro-Logo-from-web-558.jpeg",
  "rogers communications": BASE + "rogerssocial-1.jpg",
  "enbridge gas":          BASE + "enbridge.png",
  "bell canada":           BASE + "aHR0cHM6Ly9pbWFnZXMuY29udGVudHN0YWNrLmlvL3YzL2Fzc2V0cy9ibHRmYTgyMjcxYzllZDAxMDBiL2JsdDQzMTQyZjFjODQ0NjQ5MjUvNjllNjk0NDcwODEyMGIwZTUyMTRkZmE2L0JlbGxHUENhbmFkYV9WZXJfUkdCLmpwZw%3D%3D.jpg",
  "toronto property tax":  BASE + "Captura%20de%20pantalla%202026-06-07%20141855.png"
};

function sanitizeLiveArgs(args) {
  if (!args || typeof args !== "object") return args;
  try {
    const cleaned = JSON.stringify(args).replace(/<ctrl(\d+)>/g, (_, n) =>
      String.fromCharCode(parseInt(n, 10))
    );
    return JSON.parse(cleaned);
  } catch (e) {
    console.warn("ACN sanitizeLiveArgs: failed to clean args, returning original", e);
    return args;
  }
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function getPayeeLogo(payeeName) {
  const key = (payeeName || "").toLowerCase().trim();
  for (const [name, url] of Object.entries(PAYEE_LOGOS)) {
    if (key.includes(name)) return url;
  }
  return null;
}

function getPayeeEmoji(payeeName) {
  const p = (payeeName || "").toLowerCase();
  if (p.includes("hydro") || p.includes("electric") || p.includes("power")) return "⚡";
  if (p.includes("rogers") || p.includes("bell") || p.includes("telus")) return "📱";
  if (p.includes("gas") || p.includes("enbridge")) return "🔥";
  if (p.includes("tax") || p.includes("government") || p.includes("city")) return "🏛️";
  return "🏦";
}

function cleanupRegistry() {
  const maxAge = 10 * 60 * 1000;
  const now = Date.now();
  Object.entries(window.ACN_WIDGET_REGISTRY).forEach(([key, value]) => {
    if (!value || !value.createdAt || now - value.createdAt > maxAge) {
      delete window.ACN_WIDGET_REGISTRY[key];
    }
  });
}

function registerWidget(items) {
  cleanupRegistry();
  const wid = "w_" + Date.now() + "_" + Math.floor(Math.random() * 1000);
  window.ACN_WIDGET_REGISTRY[wid] = { items: Array.isArray(items) ? items : [], createdAt: Date.now() };
  return wid;
}

function getWidgetItems(widClass) {
  return window.ACN_WIDGET_REGISTRY?.[widClass]?.items || [];
}

function getItemIndexFromClass(el) {
  if (!el || !el.classList) return -1;
  const itemClass = Array.from(el.classList).find(c => c.startsWith("acn-item-"));
  if (!itemClass) return -1;
  const index = Number(itemClass.replace("acn-item-", ""));
  return Number.isFinite(index) ? index : -1;
}

(function() {
  var _orig = window.fetch;
  window.fetch = function(url, opts) {
    var p = _orig.apply(this, arguments);
    if (url && url.toString().indexOf('runSession') >= 0) {
      p.then(function(r) {
        r.clone().json().then(function(d) {
          _processRunSession(d);
        }).catch(function(){});
      }).catch(function(){});
    }
    return p;
  };
})();

/* Mod C */
function _processRunSession(data) {
  if (!data || !data.outputs) return;
  removeTyping();
  data.outputs.forEach(function(output) {
    if (output.text) addBotBubble(output.text);
    if (output.payload) _handlePayload(sanitizeLiveArgs(output.payload));
    if (output.richContent) {
      (output.richContent || []).forEach(function(group) {
        (group || []).forEach(function(item) {
          if (item && item.payload) _handlePayload(item.payload);
        });
      });
    }
  });
}

/* Mod A */
function _initGecx() {
  if (_gecxInitDone) return;
  _gecxInitDone = true;
  try {
    chatSdk.registerContext(
      chatSdk.prebuilts.ces.createContext({
        deploymentName: 'projects/483471568825/locations/us/apps/27be6c70-74dc-4e50-a3e8-25b032e7c965/deployments/7cbb68f9-147f-4698-be02-e7ea5fa5d1a3',
        tokenBroker: {enableTokenBroker: true, enableRecaptcha: false}
      })
    );
    console.log('[ACN] GECX registered');
  } catch(e) { console.error('[ACN] init error:', e); }
}

if (window.chatSdk) {
  _initGecx();
  showTyping();
} else {
  window.addEventListener('chat-messenger-loaded', function() {
    _initGecx();
    showTyping();
  });
}

window._gecxSend = function(text) {
  var m = document.querySelector('chat-messenger');
  if (m && typeof m.sendRequest === 'function') m.sendRequest('query', text);
};

['df-response-received','ces-response-received','chat-response-received'].forEach(function(n) {
  window.addEventListener(n, function(e) {
    if (e.detail && e.detail.outputs) _processRunSession(e.detail);
  });
});

function _handlePayload(p) {
  if (!p) return;
  if (p.type === 'quick_actions' && p.actions) {
    showTiles(p.actions, p.summary); return;
  }
  if (p.name === 'acn-payment-carousel') { renderCarousel(p); return; }
  if (p.name === 'acn-payee-selector') {
    var html = buildPayeeSelector(p);
    var d = document.createElement('div');
    d.innerHTML = html;
    _msgs.appendChild(d.firstChild);
    scrollToBottom(); return;
  }
  if (p.name === 'acn-payment-receipt') {
    var html = buildPaymentReceipt(p);
    var d = document.createElement('div');
    d.innerHTML = html;
    _msgs.appendChild(d.firstChild);
    scrollToBottom(); return;
  }
}

/* Mod B */
function addBotBubble(text) {
  if (!text || !text.trim()) return;
  text = text.replace(/\*\*([^*]+)\*\*/g,'$1')
             .replace(/\*([^*]+)\*/g,'$1')
             .replace(/^#{1,3}\s+/gm,'').trim();
  if (/I'll call:|quick_actions\{|"actions":\[|payload:\{/.test(text)) return;
  if (!text) return;
  var d = document.createElement('div');
  d.className = 'acn-bot-bubble';
  d.textContent = text;
  _msgs.appendChild(d);
  scrollToBottom();
}

function addUserBubble(text) {
  var d = document.createElement('div');
  d.className = 'acn-user-bubble';
  d.textContent = text;
  _msgs.appendChild(d);
  scrollToBottom();
}

function showTyping() {
  removeTyping();
  var d = document.createElement('div');
  d.className = 'acn-typing';
  d.id = 'acn-typing-indicator';
  d.innerHTML = '<span></span><span></span><span></span>';
  _msgs.appendChild(d);
  scrollToBottom();
}

function removeTyping() {
  var t = document.getElementById('acn-typing-indicator');
  if (t) t.remove();
}

function showTiles(actions, summary) {
  var oldWrap = _msgs.querySelector('.acn-tiles-wrap');
  if (oldWrap) oldWrap.remove();
  if (!actions || !actions.length) return;
  var combo = document.createElement('div');
  combo.className = 'acn-combo-card';
  var textDiv = document.createElement('div');
  textDiv.className = 'acn-combo-text';
  var lastBubble = _msgs.querySelector('.acn-bot-bubble:last-child');
  if (lastBubble) {
    textDiv.innerHTML = lastBubble.innerHTML;
    lastBubble.remove();
  } else {
    textDiv.textContent = summary || 'How would you like to proceed?';
  }
  combo.appendChild(textDiv);
  var tilesDiv = document.createElement('div');
  tilesDiv.className = 'acn-combo-tiles';
  actions.forEach(function(action) {
    var btn = document.createElement('button');
    btn.className = 'acn-tile';
    btn.innerHTML = '<span class="acn-tile-title">' + escHtml(action.content || '') + '</span>' +
      (action.description ? '<span class="acn-tile-desc">' + escHtml(action.description) + '</span>' : '');
    btn.addEventListener('click', function() {
      combo.remove();
      addUserBubble(action.content || action.utterance);
      showTyping();
      window._gecxSend(action.utterance || action.content);
    });
    tilesDiv.appendChild(btn);
  });
  combo.appendChild(tilesDiv);
  _msgs.appendChild(combo);
  scrollToBottom();
}

function sendMessage() {
  var text = _input.value.trim();
  if (!text) return;
  _input.value = '';
  addUserBubble(text);
  showTyping();
  window._gecxSend(text);
}

_input.addEventListener('keydown', function(e) { if (e.key === 'Enter') sendMessage(); });
function scrollToBottom() { _msgs.scrollTop = _msgs.scrollHeight; }
function escHtml(s) { return escapeHtml(s); }

function resetChat() {
  _msgs.innerHTML = '';
  _sessionStarted = false;
  _gecxInitDone = false;
  showTyping();
  _initGecx();
}

var _voiceActive = false, _recognition = null;
function toggleVoice() {
  var btn = document.getElementById('acn-voice-btn');
  if (!('webkitSpeechRecognition' in window || 'SpeechRecognition' in window)) {
    alert('Voice input not supported in this browser.'); return;
  }
  if (_voiceActive) {
    if (_recognition) _recognition.stop();
    _voiceActive = false; btn.style.color = '#A090C0'; return;
  }
  var SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  _recognition = new SR();
  _recognition.lang = 'en-CA';
  _recognition.interimResults = false;
  _recognition.onresult = function(e) { _input.value = e.results[0][0].transcript; sendMessage(); };
  _recognition.onend = function() { _voiceActive = false; btn.style.color = '#A090C0'; };
  _recognition.start();
  _voiceActive = true; btn.style.color = '#A100FF';
}

function handleFileUpload(input) {
  var file = input.files[0];
  if (!file) return;
  addUserBubble('📎 ' + file.name);
  showTyping();
  window._gecxSend('I am uploading a file: ' + file.name);
  input.value = '';
}

function fmtAmt(a,c){if(a==null)return'';var n=parseFloat(a).toLocaleString('en-CA',{minimumFractionDigits:2,maximumFractionDigits:2});return(c?"<span class='acn-card-currency'>"+c+"</span>&nbsp;":"")+n;}
function badgeClass(s){s=(s||'').toLowerCase();if(['active','paid'].indexOf(s)>=0)return'acn-badge acn-badge-'+s;if(['frozen','blocked'].indexOf(s)>=0)return'acn-badge acn-badge-'+s;if(['pending','processing'].indexOf(s)>=0)return'acn-badge acn-badge-'+s;if(s==='available')return'acn-badge acn-badge-available';if(s==='scheduled')return'acn-badge acn-badge-scheduled';return'acn-badge acn-badge-active';}
function cardTheme(p){var n=(p.payee_name||'').toLowerCase(),id=(p.payment_id||'').toLowerCase();if(n.indexOf('chequing')>=0||id.indexOf('chq')>=0)return'border-left:3px solid #A100FF;background:#F5EEFF;';if(n.indexOf('saving')>=0||id.indexOf('sav')>=0)return'border-left:3px solid #1E9E50;background:#EAFBF0;';if(n.indexOf('visa')>=0||n.indexOf('card')>=0||id.indexOf('card')>=0)return'border-left:3px solid #7000BB;background:#F5EEFF;';if(n.indexOf('bill')>=0)return'border-left:3px solid #F0CC60;background:#FFF8E8;';return'';}
window._ctaValues=[];
function renderCarouselCard(p){var theme=cardTheme(p);var amtHTML=p.amount!=null?'<div class="acn-card-amount">'+fmtAmt(p.amount,p.currency)+'</div>':'';var dateHTML=p.display_date?'<div class="acn-card-date">'+p.display_date+'</div>':'';var badgeHTML=p.status?'<div class="'+badgeClass(p.status)+'">'+p.status.charAt(0).toUpperCase()+p.status.slice(1)+'</div>':'';var btnClass,btnAttr;if(p.cancellable&&p.cta_value){var idx=window._ctaValues.length;window._ctaValues.push(p.cta_value);btnClass='acn-cta-btn acn-cta-active';btnAttr='onclick="carouselClick('+idx+')"';}else{btnClass='acn-cta-btn acn-cta-inactive';btnAttr='disabled';}return'<div class="acn-card" style="'+theme+'"><div class="acn-card-name">'+(p.payee_name||'')+'</div>'+amtHTML+dateHTML+badgeHTML+'<button class="'+btnClass+'" '+btnAttr+'>'+(p.cta_label||'Select')+'</button></div>';}
function renderCarousel(data) {
  window._ctaValues = [];
  var html = '<div class="acn-carousel-wrap">'
    + '<div class="acn-carousel-header"><div>'
    + '<div class="acn-carousel-title">' + (data.title || '') + '</div>'
    + (data.subtitle ? '<div class="acn-carousel-sub">' + data.subtitle + '</div>' : '')
    + '</div></div>'
    + '<div class="acn-cards-track">' + (data.payments || []).map(renderCarouselCard).join('') + '</div>'
    + '<div class="acn-carousel-footer"><div class="acn-powered-dot"></div>'
    + '<span class="acn-powered-text">Powered by Accenture × Google GECX</span></div></div>';
  var d = document.createElement('div');
  d.innerHTML = html;
  _msgs.appendChild(d.firstChild);
  scrollToBottom();
}
function carouselClick(idx) { var val = window._ctaValues[idx]; if (val) { showTyping(); window._gecxSend(val); } }

function buildPayeeSelector(payload) {
  const payees = payload.payees || [];
  const wid = registerWidget(payees);
  const rows = payees.map((p, index) => {
    const logoUrl = p.logo_url || getPayeeLogo(p.payee_name);
    const iconHtml = logoUrl
      ? `<img src="${escapeHtml(logoUrl)}" alt="${escapeHtml(p.payee_name)}" style="width:100%;height:100%;object-fit:contain;border-radius:50%;pointer-events:none;">`
      : `<span style="font-size:16px;pointer-events:none;">${getPayeeEmoji(p.payee_name)}</span>`;
    return `
      <div class="acn-action-select acn-row acn-item-${index}" style="background:#fff;border-bottom:1px solid #e0e4ea;padding:12px;display:flex;align-items:center;gap:12px;cursor:pointer;transition:background 0.15s;position:relative;z-index:20;pointer-events:auto;">
        <div style="width:36px;height:36px;border-radius:50%;background:#f4f6f9;border:1px solid #e5e7eb;display:flex;align-items:center;justify-content:center;flex-shrink:0;overflow:hidden;padding:2px;pointer-events:none;">${iconHtml}</div>
        <div style="flex-grow:1;pointer-events:none;">
          <div style="font-size:14px;font-weight:600;color:#1a1a2e;pointer-events:none;">${escapeHtml(p.payee_name || "")}</div>
          <div style="font-size:12px;color:#6b7280;pointer-events:none;">Acct: ${escapeHtml(p.account_number || "****")}</div>
        </div>
        <div style="color:#1a56db;font-size:14px;pointer-events:none;">❯</div>
      </div>`;
  }).join("");
  return `
    <div class="acn-widget-root ${wid}" style="width:100%;box-sizing:border-box;">
      <div style="font-size:15px;font-weight:600;color:#1a1a2e;margin-bottom:4px;">💳 ${escapeHtml(payload.title || "Your Saved Payees")}</div>
      <div style="font-size:13px;color:#6b7280;margin-bottom:12px;">${escapeHtml(payload.subtitle || "Select a payee to continue.")}</div>
      <div class="acn-list-track" style="border:1px solid #e0e4ea;border-radius:12px;overflow:hidden;">${rows}</div>
    </div>`;
}

function buildPaymentReceipt(payload) {
  const logoUrl = payload.logo_url || getPayeeLogo(payload.payee_name);
  const iconHtml = logoUrl
    ? `<img src="${escapeHtml(logoUrl)}" alt="${escapeHtml(payload.payee_name)}" style="width:100%;height:100%;object-fit:contain;border-radius:50%;">`
    : `<span style="font-size:24px">${getPayeeEmoji(payload.payee_name)}</span>`;
  const status = (payload.status || "success").toLowerCase();
  const statusColor = status === "cancelled" ? "#9b1c1c" : "#2d6a2f";
  const statusBg = status === "cancelled" ? "#fde8e8" : "#e7f3e8";
  return `
    <div style="width:100%;box-sizing:border-box;">
      <div style="background:#fff;border:1px solid #e0e4ea;border-radius:16px;padding:20px;text-align:center;box-shadow:0 4px 12px rgba(0,0,0,0.05);">
        <div style="width:56px;height:56px;margin:0 auto 12px;border-radius:50%;background:#f4f6f9;border:1px solid #e5e7eb;display:flex;align-items:center;justify-content:center;overflow:hidden;padding:3px;">${iconHtml}</div>
        <div style="font-size:18px;font-weight:600;color:#1a1a2e;margin-bottom:4px;">${escapeHtml(payload.title || "Transaction Receipt")}</div>
        <div style="display:inline-block;padding:3px 12px;border-radius:20px;font-size:12px;font-weight:500;background:${statusBg};color:${statusColor};margin-bottom:16px;">${escapeHtml(payload.status ? payload.status.toUpperCase() : "SUCCESS")}</div>
        <div style="border-top:1px dashed #e0e4ea;border-bottom:1px dashed #e0e4ea;padding:16px 0;margin-bottom:16px;text-align:left;">
          <div style="display:flex;justify-content:space-between;margin-bottom:8px;"><span style="color:#6b7280;font-size:13px;">Payee</span><span style="font-weight:600;color:#1a1a2e;font-size:13px;">${escapeHtml(payload.payee_name || "")}</span></div>
          <div style="display:flex;justify-content:space-between;margin-bottom:8px;"><span style="color:#6b7280;font-size:13px;">Amount</span><span style="font-weight:600;color:#1a1a2e;font-size:13px;">${escapeHtml(payload.currency || "CAD")} ${escapeHtml(payload.amount || "")}</span></div>
          <div style="display:flex;justify-content:space-between;margin-bottom:8px;"><span style="color:#6b7280;font-size:13px;">Date / Freq</span><span style="font-weight:600;color:#1a1a2e;font-size:13px;">${escapeHtml(payload.date_or_frequency || "")}</span></div>
          <div style="display:flex;justify-content:space-between;"><span style="color:#6b7280;font-size:13px;">Ref ID</span><span style="font-family:monospace;color:#1a1a2e;font-size:12px;background:#f4f6f9;padding:2px 6px;border-radius:4px;">${escapeHtml(payload.receipt_id || "")}</span></div>
        </div>
        <div style="font-size:11px;color:#9ca3af;">Thank you for using ACN Bank.</div>
      </div>
    </div>`;
}

function deepQuerySelector(selector, root = document) {
  const found = root.querySelector?.(selector);
  if (found) return found;
  const all = root.querySelectorAll?.("*") || [];
  for (const el of all) {
    if (el.shadowRoot) {
      const nested = deepQuerySelector(selector, el.shadowRoot);
      if (nested) return nested;
    }
  }
  return null;
}

function setNativeValue(element, value) {
  const prototype = Object.getPrototypeOf(element);
  const valueSetter = Object.getOwnPropertyDescriptor(prototype, "value")?.set;
  if (valueSetter) valueSetter.call(element, value);
  else element.value = value;
}

function acnSendMessage(text) {
  const chat = document.querySelector("chat-messenger");
  try {
    const textarea =
      deepQuerySelector("textarea") ||
      deepQuerySelector("input[type='text']") ||
      deepQuerySelector("input");
    if (!textarea) {
      console.warn("No textarea/input found inside Shadow DOM");
      if (chat?.sendQuery) chat.sendQuery(text);
      return;
    }
    textarea.focus();
    setNativeValue(textarea, text);
    textarea.dispatchEvent(new InputEvent("input", { bubbles: true, composed: true, inputType: "insertText", data: text }));
    textarea.dispatchEvent(new Event("change", { bubbles: true, composed: true }));
    setTimeout(() => {
      textarea.dispatchEvent(new KeyboardEvent("keydown", {
        key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true, composed: true
      }));
      const sendBtn =
        deepQuerySelector("button[aria-label='Send']") ||
        deepQuerySelector("button[title='Send']") ||
        deepQuerySelector(".send-icon") ||
        deepQuerySelector("button");
      if (sendBtn && !sendBtn.disabled) sendBtn.click();
    }, 150);
  } catch (err) {
    console.warn("Visible send failed. Falling back to silent sendQuery.", err);
    if (chat?.sendQuery) chat.sendQuery(text);
  }
}

function updateCarouselArrows(track) {
  const root = track?.closest?.(".acn-widget-root");
  if (!root) return;
  const leftArrowWrapper = root.querySelector(".acn-arrow-left-wrapper");
  const rightArrowWrapper = root.querySelector(".acn-arrow-right-wrapper");
  const isAtStart = track.scrollLeft <= 5;
  const isAtEnd = track.scrollWidth - track.scrollLeft <= track.clientWidth + 5;
  if (leftArrowWrapper) {
    leftArrowWrapper.style.opacity = isAtStart ? "0" : "1";
    leftArrowWrapper.style.pointerEvents = isAtStart ? "none" : "auto";
  }
  if (rightArrowWrapper) {
    rightArrowWrapper.style.opacity = isAtEnd ? "0" : "1";
    rightArrowWrapper.style.pointerEvents = isAtEnd ? "none" : "auto";
  }
}

function bindTrackScroll(track) {
  if (!track || track.dataset.scrollBound) return;
  track.dataset.scrollBound = "true";
  track.addEventListener("scroll", () => updateCarouselArrows(track), { passive: true });
  updateCarouselArrows(track);
}

function bindCarouselScrollListeners() {
  var tracks = _msgs.querySelectorAll(".acn-carousel-track");
  tracks.forEach(bindTrackScroll);
}

function bindScrollListenerLazy(e) {
  const path = e.composedPath ? e.composedPath() : [];
  const track = path.find(el => el.classList && el.classList.contains("acn-carousel-track"));
  if (track) bindTrackScroll(track);
}

document.addEventListener("mouseover", bindScrollListenerLazy, { capture: true, passive: true });
document.addEventListener("touchstart", bindScrollListenerLazy, { capture: true, passive: true });

function handleWidgetInteractions(e) {
  const path = e.composedPath ? e.composedPath() : [];
  const findInPath = (cls) => path.find(el => el.classList && el.classList.contains(cls));
  const arrowBtn = findInPath("acn-arrow-btn");
  if (arrowBtn) {
    e.preventDefault();
    e.stopPropagation();
    const root = findInPath("acn-widget-root");
    const track = root?.querySelector?.(".acn-carousel-track");
    if (track) {
      const card = track.firstElementChild;
      const scrollAmount = card ? card.offsetWidth + 12 : 232;
      const isLeft = arrowBtn.classList.contains("left-arrow");
      track.scrollBy({ left: isLeft ? -scrollAmount : scrollAmount, behavior: "smooth" });
      setTimeout(() => updateCarouselArrows(track), 350);
    }
    return;
  }
  const cancelBtn = findInPath("acn-action-cancel");
  if (cancelBtn && !cancelBtn.classList.contains("acn-disabled")) {
    e.preventDefault();
    e.stopPropagation();
    const card = findInPath("acn-card");
    const root = findInPath("acn-widget-root");
    const index = getItemIndexFromClass(card);
    const widClass = Array.from(root?.classList || []).find(c => c.startsWith("w_"));
    const item = widClass ? getWidgetItems(widClass)[index] : null;
    if (item) {
      cancelBtn.textContent = "Cancelled";
      cancelBtn.classList.add("acn-disabled");
      cancelBtn.style.background = "#f8fafc";
      cancelBtn.style.color = "#9b1c1c";
      cancelBtn.style.borderColor = "#fca5a5";
      cancelBtn.style.pointerEvents = "none";
      cancelBtn.style.cursor = "default";
      const cta = item.cta_value || `cancel_payment:${item.payment_id || item.payee_name}`;
      acnSendMessage(cta);
    }
    return;
  }
  const selectBtn = findInPath("acn-action-select");
  if (selectBtn) {
    e.preventDefault();
    e.stopPropagation();
    const root = findInPath("acn-widget-root");
    const index = getItemIndexFromClass(selectBtn);
    const widClass = Array.from(root?.classList || []).find(c => c.startsWith("w_"));
    const item = widClass ? getWidgetItems(widClass)[index] : null;
    if (item) {
      selectBtn.style.background = "#f0f4ff";
      const cta = item.cta_value || `select_payee:${item.payee_id || item.payee_name}`;
      acnSendMessage(cta);
    }
  }
}

document.addEventListener('click', handleWidgetInteractions, true);
document.addEventListener('touchend', handleWidgetInteractions, { passive: false, capture: true });
</script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF140025),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
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
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: _isWebViewReady
          ? (kIsWeb
              ? const HtmlElementView(viewType: 'acn-chat-iframe')
              : WebViewWidget(controller: _webController))
          : const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
    );
  }
}
