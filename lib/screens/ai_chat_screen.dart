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
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; background-color: transparent; overflow: hidden; height: 100vh; }
    .acn-widget-root { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; width: 100%; box-sizing: border-box; }
    chat-messenger {
      position: absolute !important;
      top: 0 !important; left: 0 !important;
      width: 100% !important; height: 100% !important;
      --chat-messenger-color--primary: #A100FF;
      --chat-messenger-color--primary-container: #7500C0;
      --chat-messenger-color--on-primary: #ffffff;
      --chat-messenger-color--secondary: #7000BB;
      --chat-messenger-color--surface: #ffffff;
    }
    /* ACN-branded user message bubbles */
    chat-messenger-container::part(user-message) {
      background: linear-gradient(135deg, #A100FF, #7500C0) !important;
      color: #ffffff !important;
    }
  </style>
  <style>
    /* Load Material Icons from jsDelivr (avoids fonts.gstatic.com SSL issues on Android emulator) */
    @font-face {
      font-family: 'Material Icons';
      font-style: normal;
      font-weight: 400;
      src: url('https://cdn.jsdelivr.net/npm/material-icons@1.13.12/iconfont/MaterialIcons-Regular.woff2') format('woff2'),
           url('https://cdn.jsdelivr.net/npm/material-icons@1.13.12/iconfont/MaterialIcons-Regular.woff') format('woff');
    }
    .material-icons {
      font-family: 'Material Icons';
      font-weight: normal;
      font-style: normal;
      font-size: 24px;
      line-height: 1;
      letter-spacing: normal;
      text-transform: none;
      display: inline-block;
      white-space: nowrap;
      word-wrap: normal;
      direction: ltr;
      font-feature-settings: 'liga';
      -webkit-font-feature-settings: 'liga';
      -webkit-font-smoothing: antialiased;
    }
  </style>
  <script defer src="https://www.gstatic.com/chat-messenger/sdk/prod/v1.16/chat-messenger.js"></script>
  <link rel="stylesheet" href="https://www.gstatic.com/chat-messenger/sdk/prod/v1.16/themes/chat-messenger-default.css">
  <link rel="stylesheet" href="https://www.gstatic.com/chat-messenger/sdk/prod/v1.16/themes/chat-messenger-layout.css">
</head>
<body>
  <script>
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

    function getChatParts() {
      const chat = document.querySelector("chat-messenger");
      const chatContainer =
        chat?.shadowRoot?.querySelector("df-messenger-chat") ||
        chat?.shadowRoot?.querySelector("chat-messenger-chat");
      const userInput =
        chatContainer?.shadowRoot?.querySelector("df-messenger-user-input") ||
        chatContainer?.shadowRoot?.querySelector("chat-messenger-user-input");
      const messageList =
        chatContainer?.shadowRoot?.querySelector("df-messenger-message-list") ||
        chatContainer?.shadowRoot?.querySelector("chat-messenger-message-list");
      const textarea =
        userInput?.shadowRoot?.querySelector("textarea") ||
        userInput?.shadowRoot?.querySelector("input");
      const sendBtn =
        userInput?.shadowRoot?.querySelector("button") ||
        userInput?.shadowRoot?.querySelector(".send-icon");
      return { chat, chatContainer, userInput, messageList, textarea, sendBtn };
    }

    function normalizeFlattenedMarkdownTables(text) {
      let value = String(text ?? "");
      if (!value.includes("|")) return value;
      value = value.replace(/\||\s+\|/g, "|\n|");
      value = value.replace(/([^|\n])\s+(\|[^|]+\|)/g, (match, pre, tableRow) => {
        if ((tableRow.match(/\|/g) || []).length >= 2) return pre + "\n" + tableRow;
        return match;
      });
      value = value.replace(/(\|)\s+([A-Z][^|])/g, "$1\n$2");
      return value;
    }

    function looksLikeMarkdownTableRow(line) {
      const trimmed = line.trim();
      return trimmed.startsWith("|") && trimmed.endsWith("|") && trimmed.split("|").length >= 3;
    }

    function isMarkdownSeparatorRow(line) {
      return /^\s*\|\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$/.test(line.trim());
    }

    function renderMarkdownTable(headerLine, separatorLine, bodyLines) {
      const headers = headerLine.split("|").slice(1, -1).map(h => h.trim());
      const rows = bodyLines
        .filter(looksLikeMarkdownTableRow)
        .map(row => row.split("|").slice(1, -1).map(cell => cell.trim()));
      const ths = headers.map(h =>
        `<th style="padding:7px 12px;border:1px solid #e0e4ea;background:#f4f6f9;font-weight:600;text-align:left;font-size:13px;">${h}</th>`
      ).join("");
      const trs = rows.map(cells => {
        const tds = cells.map(d =>
          `<td style="padding:7px 12px;border:1px solid #e0e4ea;font-size:13px;">${d}</td>`
        ).join("");
        return `<tr>${tds}</tr>`;
      }).join("");
      return `<div style="overflow-x:auto;width:100%;margin:8px 0;">`
        + `<table style="border-collapse:collapse;width:100%;border-radius:8px;overflow:hidden;">`
        + `<thead><tr>${ths}</tr></thead><tbody>${trs}</tbody></table></div>`;
    }

    function renderMarkdownTablesByLines(text) {
      const lines = text.split("\n");
      const out = [];
      let i = 0;
      while (i < lines.length) {
        if (i + 1 < lines.length && looksLikeMarkdownTableRow(lines[i]) && isMarkdownSeparatorRow(lines[i + 1])) {
          const header = lines[i];
          const separator = lines[i + 1];
          const body = [];
          i += 2;
          while (i < lines.length && looksLikeMarkdownTableRow(lines[i])) { body.push(lines[i]); i += 1; }
          out.push(renderMarkdownTable(header, separator, body));
        } else { out.push(lines[i]); i += 1; }
      }
      return out.join("\n");
    }

    function renderMarkdown(raw) {
      let html = normalizeFlattenedMarkdownTables(raw);
      html = escapeHtml(html);
      html = renderMarkdownTablesByLines(html);
      html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
      html = html.replace(/(^|[^*])\*(?!\*)(.+?)(?<!\*)\*(?!\*)/g, "$1<em>$2</em>");
      html = html.replace(/`([^`]+)`/g,
        `<code style="background:#f0f4ff;padding:2px 6px;border-radius:4px;font-size:0.88em;font-family:monospace;color:#1a1a2e;">$1</code>`
      );
      html = html.replace(/((?:^[\*\-] .+\n?)+)/gm, block => {
        const items = block.trim().split("\n").map(line =>
          `<li style="margin:3px 0;">${line.replace(/^[\*\-] /, "").trim()}</li>`
        ).join("");
        return `<ul style="margin:6px 0;padding-left:18px;">${items}</ul>`;
      });
      html = html.replace(/((?:^\d+\. .+\n?)+)/gm, block => {
        const items = block.trim().split("\n").map(line =>
          `<li style="margin:3px 0;">${line.replace(/^\d+\. /, "").trim()}</li>`
        ).join("");
        return `<ol style="margin:6px 0;padding-left:18px;">${items}</ol>`;
      });
      html = html.replace(/\n/g, "<br>");
      html = html.replace(/<br>\s*(<div style="overflow-x:auto;)/g, "$1");
      html = html.replace(/(<\/div>)\s*<br>/g, "$1");
      return html;
    }

    const MD_SELECTORS = [
      ".message-text", ".bot-message .text", ".bot-message p", ".response-text",
      ".chat-message--bot .message", "df-messenger-message p", "chat-messenger-message p",
      ".message p", "p"
    ];
    const MD_HAS_SYNTAX = /\*\*|__|\*[^*]|`|\|\s*:?-{3,}:?\s*\||\|\s+\|/;

    function patchMarkdownInShadow(root) {
      if (!root) return;
      for (const selector of MD_SELECTORS) {
        const els = root.querySelectorAll(`${selector}:not([data-md-done])`);
        if (els.length === 0) continue;
        els.forEach(el => {
          const raw = el.innerText ?? el.textContent ?? "";
          if (MD_HAS_SYNTAX.test(raw)) {
            el.innerHTML = renderMarkdown(raw);
            el.setAttribute("data-md-done", "true");
          }
        });
        if (root.querySelectorAll(`${selector}[data-md-done]`).length > 0) break;
      }
      root.querySelectorAll("*").forEach(el => { if (el.shadowRoot) patchMarkdownInShadow(el.shadowRoot); });
    }

    function patchAllMarkdown() {
      const { messageList } = getChatParts();
      if (!messageList) return;
      patchMarkdownInShadow(messageList);
      if (messageList.shadowRoot) patchMarkdownInShadow(messageList.shadowRoot);
    }

    function buildPaymentCarousel(payload) {
      const payments = payload.payments || [];
      const wid = registerWidget(payments);
      const cards = payments.map((p, index) => {
        const status = (p.status || "").toLowerCase();
        const badgeClass = status === "processing" ? "acn-badge-processing" : status === "cancelled" ? "acn-badge-cancelled" : "acn-badge-scheduled";
        const badgeLabel = p.status ? p.status.charAt(0).toUpperCase() + p.status.slice(1) : "Scheduled";
        const logoUrl = p.logo_url || getPayeeLogo(p.payee_name);
        const iconHtml = logoUrl
          ? `<img src="${escapeHtml(logoUrl)}" alt="${escapeHtml(p.payee_name)}" style="width:100%;height:100%;object-fit:contain;border-radius:50%;pointer-events:none;">`
          : `<span style="font-size:20px;pointer-events:none;">${getPayeeEmoji(p.payee_name)}</span>`;
        const badgeColors = {
          "acn-badge-scheduled": "background:#e7f3e8;color:#2d6a2f;",
          "acn-badge-processing": "background:#fef3cd;color:#8a5a00;",
          "acn-badge-cancelled": "background:#fde8e8;color:#9b1c1c;"
        };
        const btnHtml = p.cancellable
          ? `<div class="acn-action-cancel" style="width:100%;padding:9px 0;border:1px solid #b9c1cf;border-radius:8px;background:#fff;font-size:13px;font-weight:600;color:#1a1a2e;cursor:pointer;margin-top:auto;text-align:center;display:flex;justify-content:center;transition:background 0.15s,border-color 0.15s;position:relative;z-index:20;pointer-events:auto;">${escapeHtml(p.cta_label || "Cancel payment")}</div>`
          : `<div class="acn-action-cancel acn-disabled" style="width:100%;padding:9px 0;border:1px solid #e5e7eb;border-radius:8px;background:#f8fafc;font-size:13px;font-weight:500;color:#9ca3af;cursor:default;pointer-events:none;text-align:center;display:flex;justify-content:center;margin-top:auto;position:relative;z-index:20;">${escapeHtml(p.cta_label || badgeLabel)}</div>`;
        return `
          <div class="acn-card acn-item-${index}" style="background:#fff;border:1px solid #e0e4ea;border-radius:16px;padding:16px;width:220px;flex:0 0 auto;scroll-snap-align:start;display:flex;flex-direction:column;gap:10px;box-sizing:border-box;position:relative;">
            <div style="display:flex;align-items:center;gap:10px;min-height:48px;pointer-events:none;">
              <div style="width:44px;height:44px;border-radius:50%;background:#fff;border:1px solid #e5e7eb;display:flex;align-items:center;justify-content:center;flex-shrink:0;overflow:hidden;box-sizing:border-box;padding:3px;">${iconHtml}</div>
              <div style="font-size:14px;font-weight:600;color:#1a1a2e;line-height:1.2;white-space:normal;word-break:break-word;">${escapeHtml(p.payee_name || "")}</div>
            </div>
            <span style="display:inline-block;padding:3px 10px;border-radius:20px;font-size:12px;font-weight:500;width:fit-content;${badgeColors[badgeClass] || badgeColors["acn-badge-scheduled"]}pointer-events:none;">${escapeHtml(badgeLabel)}</span>
            <div style="font-size:13px;color:#374151;display:flex;align-items:center;gap:5px;margin-top:2px;pointer-events:none;">📅 ${escapeHtml(p.display_date || "")}</div>
            <div style="font-size:13px;font-weight:700;color:#374151;display:flex;align-items:center;gap:5px;pointer-events:none;">💲 ${escapeHtml(p.currency || "CAD")} ${escapeHtml(p.amount || "")}</div>
            ${btnHtml}
          </div>`;
      }).join("");
      const leftArrow = payments.length > 2 ? `
        <div class="acn-arrow-wrapper acn-arrow-left-wrapper" style="position:absolute;left:-5px;top:45%;transform:translateY(-50%);z-index:30;opacity:0;pointer-events:none;transition:opacity 0.2s;">
          <div class="acn-arrow-btn left-arrow" style="width:36px;height:36px;border-radius:50%;background:#fff;border:1px solid #d1d5db;box-shadow:2px 0 8px rgba(0,0,0,0.1);cursor:pointer;display:flex;align-items:center;justify-content:center;color:#1a56db;font-weight:bold;font-size:16px;padding-right:3px;pointer-events:auto;">❮</div>
        </div>` : "";
      const rightArrow = payments.length > 2 ? `
        <div class="acn-arrow-wrapper acn-arrow-right-wrapper" style="position:absolute;right:0px;top:45%;transform:translateY(-50%);z-index:30;opacity:1;pointer-events:auto;transition:opacity 0.2s;">
          <div class="acn-arrow-btn right-arrow" style="width:36px;height:36px;border-radius:50%;background:#fff;border:1px solid #d1d5db;box-shadow:-2px 0 8px rgba(0,0,0,0.1);cursor:pointer;display:flex;align-items:center;justify-content:center;color:#1a56db;font-weight:bold;font-size:16px;padding-left:3px;pointer-events:auto;">❯</div>
        </div>` : "";
      return `
        <div class="acn-widget-root ${wid}" style="width:100%;box-sizing:border-box;overflow:hidden;padding:5px 0;">
          <div style="font-size:15px;font-weight:600;color:#1a1a2e;margin-bottom:4px;">📅 ${escapeHtml(payload.title || "Upcoming scheduled payments")}</div>
          <div style="font-size:13px;color:#6b7280;margin-bottom:12px;">${escapeHtml(payload.subtitle || "")}</div>
          <div style="position:relative;width:100%;">
            ${leftArrow}
            <div class="acn-carousel-track" style="display:flex;gap:12px;overflow-x:auto;scroll-snap-type:x mandatory;scrollbar-width:none;padding-bottom:10px;padding-right:45px;padding-left:5px;scroll-behavior:smooth;">
              ${cards}
            </div>
            ${rightArrow}
          </div>
        </div>`;
    }

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
      const { messageList } = getChatParts();
      const tracks = messageList?.querySelectorAll?.(".acn-carousel-track") || [];
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

    document.addEventListener("click", handleWidgetInteractions, true);
    document.addEventListener("touchend", handleWidgetInteractions, { passive: false, capture: true });

    function hideTitlebar() {
      const chat = document.querySelector("chat-messenger");
      if (!chat || !chat.shadowRoot) return false;

      const chatChat =
        chat.shadowRoot.querySelector("chat-messenger-chat") ||
        chat.shadowRoot.querySelector("df-messenger-chat");
      if (!chatChat || !chatChat.shadowRoot) return false;

      const sr = chatChat.shadowRoot;
      if (sr.querySelector("style[data-acn-tb]")) return true;

      const s = document.createElement("style");
      s.setAttribute("data-acn-tb", "1");
      s.textContent = `
        [part="titlebar"],
        [part="header"],
        .titlebar,
        .chat-title-bar,
        df-messenger-chat-title,
        chat-messenger-title,
        :host > div:first-child {
          display: none !important;
          height: 0 !important;
          min-height: 0 !important;
          max-height: 0 !important;
          overflow: hidden !important;
          padding: 0 !important;
          margin: 0 !important;
        }
      `;
      sr.appendChild(s);
      console.log("ACN: titlebar hidden in chatChat shadow root");
      return true;
    }

    let _tbAttempts = 0;
    const _tbInterval = setInterval(() => {
      const done = hideTitlebar();
      _tbAttempts++;
      if (done || _tbAttempts >= 20) clearInterval(_tbInterval);
    }, 500);

    window.addEventListener("chat-messenger-loaded", () => {
      hideTitlebar();
      setTimeout(hideTitlebar, 200);
      setTimeout(hideTitlebar, 600);
      setTimeout(hideTitlebar, 1200);

      chatSdk.registerContext(
        chatSdk.prebuilts.ces.createContext({
          deploymentName: "projects/emvnzir-canada-song/locations/us/apps/27be6c70-74dc-4e50-a3e8-25b032e7c965/deployments/7cbb68f9-147f-4698-be02-e7ea5fa5d1a3",
          tokenBroker: { enableTokenBroker: true, enableRecaptcha: false }
        }),
      );

      const chatEl = document.querySelector("chat-messenger");
      chatEl.addEventListener("chat-messenger-response-received", (event) => {
        const outputs = event.detail?.raw?.outputs || [];
        outputs.forEach(output => {
          const messages = output?.diagnosticInfo?.messages || [];
          messages.forEach(message => {
            const chunks = message.chunks || [];
            chunks.forEach(chunk => {
              const toolCall = chunk.toolCall;
              if (!toolCall) return;
              const cleanArgs = sanitizeLiveArgs(toolCall.args);
              const payload = cleanArgs?.payload;
              if (!payload) return;
              const widgetName = payload.name || toolCall.displayName || toolCall.name || "";
              if (widgetName === "acn-payment-carousel") {
                chatEl.renderCustomCard([{ type: "html", html: buildPaymentCarousel(payload) }]);
              } else if (widgetName === "acn-payee-selector") {
                chatEl.renderCustomCard([{ type: "html", html: buildPayeeSelector(payload) }]);
              } else if (widgetName === "acn-payment-receipt") {
                chatEl.renderCustomCard([{ type: "html", html: buildPaymentReceipt(payload) }]);
              }
            });
          });
        });
        setTimeout(patchAllMarkdown, 250);
        setTimeout(patchAllMarkdown, 700);
        setTimeout(bindCarouselScrollListeners, 150);
        setTimeout(bindCarouselScrollListeners, 500);
      });
    });
  </script>
  <chat-messenger url-allowlist="*">
    <chat-messenger-container
        chat-title="ACN Bank Assistant"
        chat-title-icon="https://gstatic.com/dialogflow-console/common/assets/ccai-favicons/conversational_agents.png"
        enable-file-upload
        enable-audio-input
    >
      <chat-reset-session-button slot="titlebar-actions" title-text="Start new chat"></chat-reset-session-button>
      <chat-toggle-dialog-button slot="titlebar-actions" title-text-expanded="Collapse" title-text-collapsed="Expand"></chat-toggle-dialog-button>
      <chat-messenger-close-button slot="titlebar-actions" title-text="Close"></chat-messenger-close-button>
    </chat-messenger-container>
  </chat-messenger>
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
