# Architectural Decisions

This document records the key architectural choices made for the GECX Banking ACN project.

## Frontend (Flutter)
- **Theming**: Centralized theme management using `lib/theme/app_colors.dart`.
- **Animations**: Prefer explicit animations (`AnimationController`) for critical UI feedback (e.g., success states) to ensure a high-quality user experience.
- **Project Structure**: Feature-based organization within `lib/screens/` and `lib/backend/`.

## Platform Compatibility
- **Web-First WebView Handling**: To bypass browser security restrictions (CORS and `sessionStorage` blocks in `data:` URLs), the AI Assistant is integrated using a hybrid approach:
    - **Web**: Uses `dart:ui_web` to register a native `IFrameElement` factory. Content is served from a same-origin `web/chat.html` file to enable full Google Chat SDK functionality (including persistent sessions).
    - **Mobile**: Uses the standard `webview_flutter` plugin for Android/iOS.
- **Layout Robustness**: To prevent `RenderFlex` overflow errors during dynamic UI expansions (like the AI panel), containers use `SingleChildScrollView` with `NeverScrollableScrollPhysics` as a layout shield, allowing content to maintain its target dimensions during transition.
