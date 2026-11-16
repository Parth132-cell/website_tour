# Dynamic Tour Engine and FlowDesk

This workspace contains a reusable Flutter onboarding engine and its FlowDesk SaaS demo application.

## Project phases

- Phase 1 package research: `PHASE1_PACKAGE_RESEARCH.md`.
- Phase 2 architecture and design system: `PHASE2_ARCHITECTURE_AND_DESIGN_SYSTEM.md`.
- Phase 3 FlowDesk UI and navigation: `PHASE3_FLOWDESK_UI.md`.
- Phase 4 mock data and interactions: `PHASE4_INTERACTIONS.md`.
- Phase 5 reusable engine: `PHASE5_ENGINE.md`.
- Phase 6 module tours: `PHASE6_MODULE_TOURS.md`.
- Phase 7 navigation and persistence: `PHASE7_DYNAMIC_NAVIGATION_PERSISTENCE.md`.

## Run the demo

From `dynamic_tour_engine/example`, run:

```powershell
flutter pub get
flutter run -d chrome
```

The app includes Dashboard, Users, Alumni, Messages, Events, Reports, Notifications, Settings and Profile routes. Each route has an independent tour. The Help menu also starts an optional cross-route workspace tour. SharedPreferences stores local progress and restores the last active tour after reload.

## Integrate the engine

Create a `TourTargetRegistry`, register configurations in `TourRegistry`, and create a `TourController` at the application root. Place `TourOverlayHost` above routed content and register semantic targets with `TourTarget`. Implement `TourProgressStore` for progress; implement optional `TourSessionStore` as well when the app needs last-active tour restoration.
