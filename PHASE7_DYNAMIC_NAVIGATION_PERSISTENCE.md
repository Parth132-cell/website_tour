# Phase 7 — Dynamic navigation and persistence

**Status:** Implemented  
**Date:** 13 November 2026

## Delivered

- Added a separate `FlowDesk workspace tour`: Dashboard metrics → Users invite → Reports export → Settings permissions. The controller uses the injected GoRouter navigation callback and each step's configured route; users can navigate directly to any module tour independently.
- Added a Help menu with “Tour this page” and “Workspace tour” actions.
- Added optional `TourSessionStore` metadata without changing the existing `TourProgressStore` contract. The SharedPreferences adapter records the last active tour ID; the controller updates and clears it at start, completion and skip.
- On startup, FlowDesk resumes a valid incomplete last-active tour at its saved step. If there is no valid active tour, it checks the current URL's route tour and starts the welcome flow only when that tour is neither completed nor skipped.
- Resume validates the saved step against the current configuration and role/permission eligibility. If configuration changed, the tour starts from its first eligible step.
- Reports show role-specific guidance: Admins receive filter/chart/export steps; Members receive a report overview step. The cross-route tour omits its Reports step for Members.
- Existing progress uses stable tour and step IDs. Completion, skipped status and active session metadata remain separate, and local manual restart clears the selected tour's previous progress.

## Persistence model

`TourProgressStore` remains the minimal app/backend persistence port for step, completion and skipped state. `TourSessionStore` is an optional capability for last-active tour metadata. Existing custom stores continue to work without implementing session restore; apps that implement both interfaces can opt into reload recovery.

SharedPreferences stores browser-local demo progress. A future account-aware app can provide a remote `TourProgressStore` and `TourSessionStore` implementation.

## Files

- `lib/dynamic_tour_engine.dart` adds `TourSessionStore` and last-active handling in the SharedPreferences adapter/controller.
- `lib/main.dart` registers the workspace tour, adds the Help menu choices, restores the route/session tour, and configures role-specific Reports guidance.

## Validation and boundaries

Flutter package and demo tests plus static analysis were run in Phase 8; see [PHASE8_TESTING.md](PHASE8_TESTING.md). Interactive browser navigation, refresh/resume, and manual role switching remain outside the automated coverage.
