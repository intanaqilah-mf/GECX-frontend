import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'chat_overlay_controller.dart';

/// A single Quick Action tile spec — icon + label + the CES utterance we fire
/// through the persistent chat overlay when the user taps it. Utterances are
/// intentionally chosen to match the phrasing the Lead Orchestrator listens
/// for (see ACN_Bank_Lead_Orchestrator/instruction.txt and each Daily_Banking
/// sub-agent) so intent routing succeeds on the very first turn.
class QuickAction {
  final String label;
  final String utterance;
  final IconData icon;
  final Color? badgeColor;
  final String? badgeText;
  final Color background;
  final Color foreground;

  const QuickAction({
    required this.label,
    required this.utterance,
    required this.icon,
    this.background = const Color(0xFFF5EEFF),
    this.foreground = AppColors.primary,
    this.badgeColor,
    this.badgeText,
  });
}

/// v1 headline quick actions — the four the user picked. Wired to the CES
/// intents the Daily Banking Router and Personal Lending Router already
/// listen for. The PROMO badge is a visual echo of the reference design.
const List<QuickAction> kQuickActionsPrimary = [
  QuickAction(
    label: 'Pay Bills',
    utterance: 'Pay a bill',
    icon: Icons.receipt_long,
    badgeColor: Color(0xFFE21B24),
    badgeText: 'PROMO',
  ),
  QuickAction(
    label: 'Transfer',
    utterance: 'Make a transfer',
    icon: Icons.swap_horiz,
  ),
  QuickAction(
    label: 'Card\nManagement',
    utterance: 'Block or unblock my card',
    icon: Icons.credit_card,
  ),
  QuickAction(
    label: 'Apply Card',
    utterance: 'Card recommendations',
    icon: Icons.add_card,
    badgeColor: Color(0xFFE21B24),
    badgeText: 'NEW',
  ),
];

/// v2 secondary tiles — round-out row 2 with the other utterances the CES
/// orchestrator already handles.
const List<QuickAction> kQuickActionsSecondary = [
  QuickAction(
    label: 'Balance',
    utterance: 'Check my balance',
    icon: Icons.account_balance,
  ),
  QuickAction(
    label: 'Pay a friend',
    // Fund_Transfer_Agent accepts "@username" P2P utterances directly. The
    // Home tile launches a small sheet that prompts for the handle, then
    // fires "pay @{handle}" so the agent walks through amount + OTP.
    utterance: 'pay @friend',
    icon: Icons.person_add_alt_1,
  ),
  QuickAction(
    label: 'My Offers',
    utterance: 'View my offers',
    icon: Icons.local_offer,
    badgeColor: Color(0xFFE21B24),
    badgeText: 'PROMO',
  ),
  QuickAction(
    label: 'Statements',
    utterance: 'Show my mini statement',
    icon: Icons.description,
  ),
];

/// Fires the action through the app-wide persistent chat overlay. Callers
/// pass the current customer id (the shell already knows it).
void runQuickAction(QuickAction a, String customerId) {
  final chat = ChatOverlayController.instance;
  chat.open(customerId);
  // We can't send text directly today — the chat.html JS is what talks to CES.
  // A follow-up would add a `sendMessage(text)` method on the controller that
  // calls webController.runJavaScript(`window._gecxSend('${text}')`). For now
  // opening the panel is the shared behavior for both native + web.
  chat.pendingUtterance = a.utterance;
}
