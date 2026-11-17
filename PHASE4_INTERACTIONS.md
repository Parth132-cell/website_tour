# Phase 4 — Mock data and interactions

**Status:** Implemented for the current demo workflows  
**Date:** 12 November 2026

## Delivered

- Added `demo_store.dart` with a `FlowDeskCubit`, `DemoState`, and in-memory `DemoUserRepository`; the provider is placed above routed pages and the tour host.
- User Management now searches by name/email, filters by role and status, and supports validated add/edit dialogs, detail view, confirmed delete, and dynamic result counts.
- Messages can be typed and sent into the visible conversation; attachment and conversation options provide demo feedback.
- Event creation opens a date picker and adds created events to session state for display in the event module.
- Notifications can be marked read; the header badge updates from Cubit state.
- Dashboard date range opens a date-range picker and reflects the chosen dates in demo feedback.
- Reports can show a CSV preview and copy the generated CSV to the clipboard. PDF generation remains an explicit simulation.
- Settings permission switches now update their state. Profile checklist items can be toggled.
- Common action feedback uses snackbars; destructive user deletion uses a confirmation dialog.

## Files

- `lib/demo_store.dart` contains demo user models, repository and Cubit state.
- `lib/main.dart` contains screens and interaction wiring.

## Validation and boundaries

- Dart formatter parsed and formatted both changed Dart files successfully.
- Static analysis could not run because the installed SDK's cache lock and analyzer process are inaccessible under the current filesystem permissions. No tests were added or run in this phase.
- State is intentionally in-memory and resets on reload. CSV content is copied to the clipboard rather than downloaded as a file. PDF/report generation is simulated. Some secondary page controls remain presentational; Phase 4 work is centered on core demo workflows.
