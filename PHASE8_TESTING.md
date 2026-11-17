# Phase 8 — Edge case testing

**Status:** Complete  
**Date:** 13 November 2026

## Coverage

The engine tests cover configuration validation and serialization, route indexing, duplicate target IDs, stale target unregisters, role and predicate filtering, missing target policies, delayed target registration, target disposal, saved progress recovery, stale saved step IDs, route changes, and pause during an in-flight navigation.

The demo widget tests cover first-time onboarding and confirm that the active tour tooltip is mounted under an `Overlay`.

## Issues fixed while testing

- Target registration could notify the tour overlay while Flutter was building a page, triggering `setState() or markNeedsBuild() called during build`. Registry notifications now defer to the end of the frame when registration or removal happens during a frame; the target key is still registered immediately.
- Startup restore and controller persistence needed explicit casts to the optional `TourSessionStore` interface because Dart does not promote the base progress-store interface to that unrelated capability.
- The duplicate-target test now exercises a second registration against an already mounted first target without throwing from the widget tree during its build/teardown.
- Updated the FlowDesk widget test to assert the current app title.

## Validation results

- Before the single-project consolidation, the engine suite passed 19 tests and the demo suite passed 2 widget tests in their separate roots.
- After consolidation, `flutter test --no-pub --reporter expanded` from the root — **passed**, all 21 tests in one project.
- `flutter analyze --no-pub` — **completed with no errors or warnings**; it reported 29 informational lints, primarily existing style and deprecation notices. Two informational async-context notices are in the demo's existing dialog callbacks.

Interactive browser refresh, cross-route tour navigation, and manual role switching were not automated in this phase.
