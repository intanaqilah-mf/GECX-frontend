import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Platform utilities for Web/Mobile compatibility
import '../services/platform_utils.dart'
    if (dart.library.html) '../services/platform_utils_web.dart';
import '../theme/app_colors.dart';
import '../models/banking_models.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import 'card_activation_screen.dart';
import '../main.dart';

// Runs in a background isolate — rootBundle cannot be called here, only encoding.
List<Map<String, String>> _encodeCardImages(Map<String, Uint8List> byteMap) {
  return byteMap.entries.map((e) => {
    'name': e.key,
    'image_url': 'data:image/png;base64,${base64Encode(e.value)}',
    'description': 'Premium benefits for your lifestyle.',
  }).toList();
}

class DashboardScreen extends StatefulWidget {
  final String customerId;
  const DashboardScreen({super.key, required this.customerId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<HomeData> _homeDataFuture;
  bool _isAiExpanded = false;
  
  late final WebViewController _webController;
  bool _isWebViewReady = false;
  bool _isPageLoaded = false;
  bool _hasInjectedCards = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
    
    if (kIsWeb) {
      // Register a native iframe factory for Web to avoid 'data:' URL security issues.
      // We use the absolute origin to ensure the browser doesn't treat it as a data URL.
      registerWebViewFactory('acn-chat-iframe', '${Uri.base.origin}/chat.html');
      _isWebViewReady = true;
      _isPageLoaded = true;
    } else {
      _initWebViewController();
    }
  }

  Future<void> _initWebViewController() async {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));

    if (!kIsWeb) {
      _webController.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _isPageLoaded = true;
            if (_isAiExpanded && !_hasInjectedCards) {
              _hasInjectedCards = true;
              _injectCardData();
            }
          },
        ),
      );
      _webController.loadHtmlString(_getMessengerHtml());
    } else {
      _isPageLoaded = true; 
      // On Web, we MUST load from a real URL to enable sessionStorage.
      // We'll construct the absolute URL manually to ensure no 'data:' URL fallback.
      final String origin = Uri.base.origin;
      // Ensure we don't have double slashes if origin ends with /
      final String path = origin.endsWith('/') ? 'chat.html' : '/chat.html';
      final String fullUrl = '$origin$path';
      debugPrint("ACN Web: Loading messenger from $fullUrl");
      _webController.loadRequest(Uri.parse(fullUrl));
    }

    setState(() => _isWebViewReady = true);
  }

  String _getMessengerHtml() {
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
    chat-messenger-container::part(titlebar) {
      background: linear-gradient(to right, #140025, #A100FF, #7500C0) !important;
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

    window.addEventListener("chat-messenger-loaded", () => {
      chatSdk.registerContext(
        chatSdk.prebuilts.ces.createContext({
          deploymentName: "projects/483471568825/locations/us/apps/27be6c70-74dc-4e50-a3e8-25b032e7c965/deployments/7cbb68f9-147f-4698-be02-e7ea5fa5d1a3",
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

  Future<void> _injectCardData() async {
    const cardImages = {
      'Visa Platinum': 'lib/assets/ChatGPT Image May 24, 2026, 06_03_30 PM.png',
      'World Elite Mastercard': 'lib/assets/ChatGPT Image May 24, 2026, 06_05_06 PM.png',
      'Infinite Cashback': 'lib/assets/ChatGPT Image May 24, 2026, 06_06_18 PM.png',
      'Student Rewards': 'lib/assets/ChatGPT Image May 24, 2026, 06_07_55 PM.png',
      'Business Gold': 'lib/assets/ChatGPT Image May 24, 2026, 06_09_25 PM.png',
    };

    // Load raw bytes on the main isolate (rootBundle requires it).
    final Map<String, Uint8List> byteMap = {};
    for (final entry in cardImages.entries) {
      try {
        final data = await rootBundle.load(entry.value);
        byteMap[entry.key] = data.buffer.asUint8List();
      } catch (e) {
        debugPrint("Error loading asset ${entry.value}: $e");
      }
    }

    // base64Encode on ~10 MB of PNG data is CPU-heavy — run it in a background isolate.
    final cards = await compute(_encodeCardImages, byteMap);

    final String jsonCards = jsonEncode(cards);
    await _webController.runJavaScript(
      'window.ACN_AVAILABLE_CARDS = $jsonCards; console.log("ACN Cards injected");',
    );
  }

  void _refreshData() {
    setState(() {
      _homeDataFuture = _apiService.getHomeData(widget.customerId);
    });
  }

  void _openAiChat() {
    setState(() => _isAiExpanded = true);
    // runJavaScript is not implemented in webview_flutter_web 0.2.x
    if (!kIsWeb && _isPageLoaded && !_hasInjectedCards) {
      _hasInjectedCards = true;
      _injectCardData();
    }
  }

  Future<void> _requestNotificationsAndShowToken(BuildContext context) async {
    final token = await FcmService.requestPermissionAndGetToken();
    if (!context.mounted) return;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Notification permission denied. Enable it in your browser site settings.'),
      ));
      return;
    }

    FcmService.setCustomerId(widget.customerId);
    try {
      await _apiService.registerDevice(widget.customerId, token);
    } catch (e) {
      debugPrint('Device registration failed: $e');
    }
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Your FCM Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this token with your backend developer:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            SelectableText(
              token,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: token));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Token copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAIButton(BuildContext context) {
    return GestureDetector(
      onTap: _openAiChat,
      child: Container(
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFA100FF), Color(0xFF7500C0), Color(0xFFD0B0F0)],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            color: AppColors.onSurface.withValues(alpha: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'Ask ACN Bank',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiExpandedSection() {
    final double screenHeight = MediaQuery.of(context).size.height;
    // Calculate a height that leaves room for the bottom nav but shows the chat clearly
    final double expandedHeight = screenHeight * 0.8; 

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      height: _isAiExpanded ? expandedHeight : 0,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
        ],
      ),
      child: SingleChildScrollView(
        // Prevent internal scroll physics from fighting with the column layout
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          height: expandedHeight,
          child: Column(
            children: [
              // Header
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.onSurface, AppColors.primary, AppColors.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _isAiExpanded = false),
                      ),
                      Text(
                        'ACN Bank Assistant',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
              // The Chat Area
              Expanded(
                child: _isWebViewReady 
                  ? (kIsWeb 
                      ? const HtmlElementView(viewType: 'acn-chat-iframe')
                      : WebViewWidget(controller: _webController))
                  : const Center(child: CircularProgressIndicator(color: Colors.blue)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
      future: _homeDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${snapshot.error}'),
                ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
              ],
            ),
          );
        } else if (!snapshot.hasData) {
          return const Center(child: Text('No data found'));
        }

        final data = snapshot.data!;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async => _refreshData(),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 1,
                  automaticallyImplyLeading: false,
                  flexibleSpace: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.onSurface, AppColors.primary, AppColors.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Center(
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        child: Text(
                          data.customer.displayName.isNotEmpty
                              ? data.customer.displayName.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  centerTitle: true,
                  title: _isAiExpanded ? null : _buildAIButton(context),
                  actions: [
                    if (!_isAiExpanded)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                            onPressed: () => _requestNotificationsAndShowToken(context),
                          ),
                          if (data.summary['total_notifications'] > 0)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: _buildAiExpandedSection(),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildBalanceCard(),
                      const SizedBox(height: 12),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      if (data.summary['has_card_ready_for_activation'] == true) ...[
                        _buildActivationBanner(context, data.latestCard?.cardId),
                        const SizedBox(height: 24),
                      ],
                      _buildApplicationsSection(data),
                      _buildTransactions(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Net Worth',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('\$142,560.00',
                  style: GoogleFonts.inter(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _balanceTile('Checking', '\$12,450.00')),
                  const SizedBox(width: 12),
                  Expanded(child: _balanceTile('Savings', '\$130,110.00')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceTile(String label, String amount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(amount,
              style: GoogleFonts.inter(
                  fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    const actions = [
      (Icons.send_outlined, 'Send'),
      (Icons.payments_outlined, 'Pay'),
      (Icons.account_balance_wallet_outlined, 'Deposit'),
      (Icons.more_horiz, 'More'),
    ];
    return Row(
      children: actions
          .map((a) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Icon(a.$1, color: AppColors.secondary, size: 22),
                            const SizedBox(height: 4),
                            Text(a.$2,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildActivationBanner(BuildContext context, String? cardId) {
    return GestureDetector(
      onTap: () {
        if (cardId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CardActivationScreen(cardId: cardId),
            ),
          ).then((_) {
            _refreshData();
            MainShell.of(context)?.refresh();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.onSurface, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Credit Card is Approved!',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Start using your virtual card now.',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Activate Card',
                        style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.credit_card, color: Colors.white38, size: 56),
          ],
        ),
      ),
    );
  }



  Widget _buildApplicationsSection(HomeData data) {
    // If user already has an active card, we don't show the tracking section
    // unless they have a NEW application that is not yet fully activated.
    if (data.customer.hasCard && data.summary['total_applications'] == 0) {
      return const SizedBox.shrink();
    }

    if (data.summary['total_applications'] == 0) {
      return _buildNoApplicationCard();
    }

    final app = data.latestApplication;
    if (app == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Applications',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
            TextButton(
              onPressed: () => MainShell.of(context)?.setIndex(2),
              child: Text('View Details',
                  style: GoogleFonts.inter(
                      color: AppColors.secondary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => MainShell.of(context)?.setIndex(2),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_outlined,
                      color: AppColors.secondary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app['selected_product_name'] ?? 'Credit Card Application',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      const SizedBox(height: 2),
                      Text('Status: ${app['status']?.toUpperCase() ?? 'PENDING'}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: app['status'] == 'approved'
                                  ? Colors.green
                                  : AppColors.onSurfaceVariant,
                              fontWeight: app['status'] == 'approved'
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoApplicationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card, color: AppColors.secondary),
              const SizedBox(width: 12),
              Text('Looking for a Card?',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'You haven\'t applied for any credit cards yet. Ask our AI assistant to help you find the best card for your needs.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _openAiChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Ask ACN Bank',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactions() {
    const txns = [
      (Icons.shopping_cart_outlined, 'Apple Store', 'Today, 2:45 PM', '-\$1,299.00', 'Electronics', true),
      (Icons.coffee_outlined, 'Starbucks', 'Yesterday, 9:12 AM', '-\$6.45', 'Dining', true),
      (Icons.local_shipping_outlined, 'Amazon.com', 'Oct 24, 2023', '-\$42.10', 'Shopping', true),
      (Icons.account_balance_outlined, 'Monthly Salary', 'Oct 20, 2023', '+\$8,500.00', 'Deposit', false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Transactions',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
            TextButton(
              onPressed: () {},
              child: Text('View All',
                  style: GoogleFonts.inter(
                      color: AppColors.secondary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: txns.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1, color: AppColors.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: t.$6
                                ? AppColors.surfaceContainerHigh
                                : AppColors.secondaryContainer.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(t.$1, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.$2,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                              Text(t.$3,
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(t.$4,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: t.$6
                                        ? AppColors.error
                                        : AppColors.secondary)),
                            Text(t.$5,
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
