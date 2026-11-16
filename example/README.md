# Dynamic Tour Engine and FlowDesk

This workspace contains a reusable Flutter onboarding engine and its FlowDesk SaaS demo application.

## Project phases

- Phase 1 package research: `PHASE1_PACKAGE_RESEARCH.md`.
- Phase 2 architecture and design system: `PHASE2_ARCHITECTURE_AND_DESIGN_SYSTEM.md`.
- Phase 3 FlowDesk UI and navigation: `PHASE3_FLOWDESK_UI.md`.
- Phase 4 mock data and interactions: `PHASE4_INTERACTIONS.md`.

## Run the demo

From `dynamic_tour_engine/example`, run:

```powershell
flutter pub get
flutter run -d chrome
```

The app includes Dashboard, Users, Alumni, Messages, Events, Reports, Notifications, Settings and Profile routes, a responsive app shell, theme toggle, account role switch and tour help action. The Users module has session-based CRUD and filters; messages can be sent; new events appear in the session; notifications and profile completion controls update locally.

## Integrate the engine

Create a `TourTargetRegistry` and `TourController` at the application root, then place `TourOverlayHost` above routed content. Register UI anchors using stable IDs with `TourTarget`. Define tours using `TourConfiguration` and `TourStep`; replace `TourProgressStore` to connect another persistence backend.
