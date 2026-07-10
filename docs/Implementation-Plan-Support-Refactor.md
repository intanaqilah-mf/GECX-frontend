# Refactor Support and Payments Screens (Completed)

Move the "Bill Payment" card and "Statement History" from the Support (Statements) screen to the Payments screen. Add an AI Chatbot interface to the Support screen.

## Changes Implemented

### [Screens]

#### [[lib/screens/statements_screen.dart]]
- Renamed title to "Support".
- Removed `_buildCurrentStatement()` and `_buildHistory()`.
- Added `_buildChatbot()` and `_chatBubble()` for the AI Assistant interface.
- Updated `SliverList` to display inquiries, chatbot, and the green banner.

#### [[lib/screens/payments_screen.dart]]
- Added `_homeDataFuture` and updated `initState` to fetch card details.
- Integrated `_buildCurrentStatement()` at the top.
- Integrated `_buildHistory(cardId)` at the bottom.
- Updated `build()` to use `Future.wait` for concurrent data fetching.

## Technical Implementation (Platform Compatibility)
### Web WebView Handling
- **Native Iframe Factory**: Created `lib/services/platform_utils_web.dart` using `dart:ui_web` to register `acn-chat-iframe`.
- **Same-Origin Hosting**: Served messenger from `web/chat.html` to enable `sessionStorage` (blocked in `data:` URLs).
- **Layout Shielding**: Used `SingleChildScrollView` with `NeverScrollableScrollPhysics` in `DashboardScreen` to prevent `RenderFlex` overflows during panel animations.

## Verification
- [x] "Current Amount Due" moved to Payments.
- [x] "Statement History" moved to Payments.
- [x] Support screen renamed and AI Chatbot added.
- [x] Web compatibility for AI Assistant verified (sessionStorage/CORS).
- [x] UI layout verified with `FutureBuilder` and `AnimatedContainer` fixes.
