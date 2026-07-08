# UI Workflows

Documentation of key user journeys and screen interactions.

## 1. Card Activation Success
**File**: `lib/screens/activation_success_screen.dart`

### Workflow
1. User successfully activates their card.
2. Navigates to `ActivationSuccessScreen`.
3. An elastic scale animation triggers on the checkmark icon.
4. Displays card summary (Last 4 digits, Credit Limit).
5. Provides quick actions to add to Apple Wallet or Google Pay.
6. Primary action: "Go to Dashboard" (pops navigation stack to root).

### Visual Components
- **Card Preview**: Dark theme card visual with contactless icon.
- **Summary Row**: Quick glance at credit limit and card identity.
- **Bottom Nav**: standard banking navigation persistent across the app.
