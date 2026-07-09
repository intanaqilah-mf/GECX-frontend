# Refactor Support and Payments Screens (Completed)

Move the "Bill Payment" card and "Statement History" from the Support (Statements) screen to the Payments screen. Add an AI Chatbot interface to the Support screen.

## Changes Implemented

### [Screens]

#### [statements_screen.dart](file:///C:/Users/intan.n.mohd.faddil/AndroidStudioProjects/GECXBankingACN/lib/screens/statements_screen.dart)
- Renamed title to "Support".
- Removed `_buildCurrentStatement()` and `_buildHistory()`.
- Added `_buildChatbot()` and `_chatBubble()` for the AI Assistant interface.
- Updated `SliverList` to display inquiries, chatbot, and the green banner.

#### [payments_screen.dart](file:///C:/Users/intan.n.mohd.faddil/AndroidStudioProjects/GECXBankingACN/lib/screens/payments_screen.dart)
- Added `_homeDataFuture` and updated `initState` to fetch card details.
- Integrated `_buildCurrentStatement()` at the top.
- Integrated `_buildHistory(cardId)` at the bottom.
- Updated `build()` to use `Future.wait` for concurrent data fetching.

## Verification
- [x] "Current Amount Due" moved to Payments.
- [x] "Statement History" moved to Payments.
- [x] Support screen renamed and AI Chatbot added.
- [x] UI layout verified with `FutureBuilder` updates.
