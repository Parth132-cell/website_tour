# Phase 5 — Reusable onboarding engine

**Status:** Implemented  
**Date:** 12 November 2026

## Engine capabilities delivered

- `TourConfiguration.validate()` checks empty IDs/routes/targets, duplicate step IDs, negative timeouts and negative highlight padding.
- `TourRegistry` validates and indexes tours by ID and route without importing FlowDesk modules.
- `TourTargetRegistry` now detects duplicate mounted target IDs, exposes mounted/geometry readiness, notifies overlay/controller listeners on registration changes, and ignores stale unregister calls.
- `TourTarget` registers and unregisters with its own identity, including delayed registration.
- `TourController` evaluates role, permission and named-predicate eligibility; supports welcome, next/previous/jump, pause/resume, skip, finish and restart; coordinates injected route navigation; waits for mounted, nonzero render geometry; scrolls targets into view; and persists the step.
- Async tour operations carry a generation token. A later start, pause, skip, finish or dispose invalidates earlier route/target waits so stale work cannot reactivate the old step.
- Missing target policies now include `fallback`. `waitThenSkip`, `skip`, `pause`, `stop` and `fallback` have distinct behaviors. The optional flag stays available for app-specific planning.
- The overlay host rebuilds when target registrations change, pauses if the active target is disposed, and shows fallback instructions without a spotlight when configured.
- SharedPreferences completion and skipped states are mutually exclusive.

## Integration boundary

The engine receives navigation and route reading as callbacks. It does not depend on FlowDesk, feature repositories or app roles. `TourUserContext`, string target IDs and route paths form the configuration boundary. Apps can replace `TourProgressStore` with API-backed persistence. The existing `GoRouterTourAdapter` is an optional helper.

Example setup:

```dart
final registry = TourTargetRegistry();
final tours = TourRegistry()..register(dashboardTour);
final controller = TourController(
  registry: registry,
  currentRoute: () => router.routeInformationProvider.value.uri.path,
  navigate: (route) async {
    router.go(route);
    await WidgetsBinding.instance.endOfFrame;
  },
);

TourOverlayHost(
  controller: controller,
  child: routedApp,
);
```

An app can request `tours.forRoute(currentRoute)` to show route-local tours in its Help menu, or start a cross-route configuration directly.

## Validation

Dart formatting parsed and formatted `lib/dynamic_tour_engine.dart`. Flutter/Dart static analysis and test execution were not run: the installed SDK cannot access its cache lock or start the analysis process under the current filesystem permissions. Phase 8 remains responsible for systematic unit, widget, browser and edge-case validation.
