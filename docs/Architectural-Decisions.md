# Architectural Decisions

This document records the key architectural choices made for the GECX Banking ACN project.

## Frontend (Flutter)
- **Theming**: Centralized theme management using `lib/theme/app_colors.dart`.
- **Animations**: Prefer explicit animations (`AnimationController`) for critical UI feedback (e.g., success states) to ensure a high-quality user experience.
- **Project Structure**: Feature-based organization within `lib/screens/` and `lib/backend/`.

## Backend (Python/FastAPI)
- **Framework**: FastAPI for high performance and automatic OpenAPI documentation.
- **Modular Routing**: Logic is split into specialized routers (applications, cards, home, etc.) to maintain scalability.
- **CORS**: Enabled for all origins to support Flutter Web development.
