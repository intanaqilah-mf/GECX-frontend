# UI Workflows

Documentation of key user journeys and screen interactions.

## 1. Card Activation Success
**File**: [[lib/screens/activation_success_screen.dart]]

### Workflow
1. User successfully activates their card.
2. Navigates to `ActivationSuccessScreen`.
3. An elastic scale animation triggers on the checkmark icon.
4. Displays card summary (Last 4 digits, Credit Limit).
5. Provides quick actions to add to Apple Wallet or Google Pay.
6. Primary action: "Go to Dashboard" (pops navigation stack to root).

## 2. Payments & Billing
**File**: [[lib/screens/payments_screen.dart]]

### Workflow
1. User navigates to the **Payments** tab.
2. **Current Amount Due**: Displayed at the top for immediate visibility of the next bill and "Make a Payment" action.
3. **Move Money**: Options for internal transfers and external payments.
4. **Statement History**: List of past monthly statements available for download (moved from Support).

## 3. Support & AI Assistant
**File**: [[lib/screens/statements_screen.dart]]

### Workflow
1. User navigates to the **Support** tab (formerly Statements).
2. **Billing Inquiries**: Access to FAQs and direct support channels (Chat/Call).
3. **AI Assistant**: A chat-like interface for automated help with banking queries.
4. **Green Rewards**: Enrollment for paperless statements.
