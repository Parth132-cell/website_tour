# Phase 6 — Integrate tours into FlowDesk modules

**Status:** Implemented  
**Date:** 13 November 2026

## Delivered

- Registered one independent configuration per FlowDesk route in the engine's `TourRegistry`.
- Connected the header Help control to the tour configuration for the current route. Direct route entry therefore starts that module's own tour without visiting Dashboard.
- Added `TourTarget` anchors for the primary content in every module. Target widgets mount only with their route and unregister when removed.
- Kept route strings, target IDs and tour copy in the app configuration. Feature widgets only declare semantic target anchors and do not own tour ordering.
- Added responsive settings section anchors for both wide and compact layouts.

## Tour target mapping

| Route | Configured targets |
|---|---|
| `/dashboard` | `dashboard.metrics`, `dashboard.revenue`, `dashboard.activity` |
| `/users` | `users.search`, `users.table`, `users.add` |
| `/alumni` | `alumni.filters`, `alumni.directory`, `alumni.profile` |
| `/messages` | `messages.conversations`, `messages.details`, `messages.composer` |
| `/events` | `events.filters`, `events.view_switcher`, `events.create` |
| `/reports` | `reports.report_filters`, `reports.report_charts`, `reports.export` |
| `/notifications` | `notifications.list`, `notifications.preferences` |
| `/settings` | `settings.sections`, `settings.permissions`, `settings.save` |
| `/profile` | `profile.edit`, `profile.completion`, `profile.security` |

## Files

- `lib/main.dart` defines the route-local tour configurations, registers them in `TourRegistry`, and places the target anchors.
- `PHASE5_ENGINE.md` documents the reusable registry/controller API.

## Validation and scope

Dart formatting parsed and formatted the modified FlowDesk screen source. Static analysis and browser interaction checks were not run because the local SDK cache and analyzer are inaccessible with the current filesystem permissions. Cross-route tour orchestration, first-visit auto-start and resume persistence remain Phase 7 work.
