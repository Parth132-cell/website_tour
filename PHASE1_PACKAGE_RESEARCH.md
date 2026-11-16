# Phase 1 — Flutter onboarding package research

**Project:** FlowDesk reusable Dynamic Onboarding / Product Tour Engine  
**Research checked:** 12 November 2026  
**Scope:** Compare the four packages named in the brief against FlowDesk's Flutter Web, route-aware, dynamic-target, cross-page tour requirements. This phase is package research only; it does not select or add a dependency.

## Executive recommendation

No single reviewed package covers the required product-tour orchestration. FlowDesk needs route-independent tours, optional cross-route sequences, dynamic/conditional targets, timeout and fallback policies, persistence abstraction, role/permission filtering, and responsive overlays. The packages focus on in-screen feature showcases and tooltip presentation. Build a small reusable engine around a route-aware coordinator, target registry and persistence interface; implement the overlay/spotlight presentation as an independently replaceable renderer. Reconsider a package adapter only if it reduces renderer work without forcing its target model into the engine's public API.

`showcaseview` is the strongest candidate to prototype as an in-route renderer because it documents custom tooltip widgets and scrolling targets into view. It still does not document the FlowDesk route planner, target readiness policy, or backend-ready persistence abstraction. `tutorial_coach_mark` is a lower-level coachmark option with flexible target positions and navigation callbacks, but its caller would own target lifecycle and routing. `feature_discovery` is aimed at Material feature discovery and internally remembers feature completion; its wrapper-per-target model is not a natural fit for dynamic tour planning. `overlay_tooltip` offers custom tooltip widgets and controller operations, but expects ordered wrappers and a controller for each screen, leaving cross-route orchestration to the app.

## Current package snapshot

Versions and platform labels below are the pub.dev listings observed on the research date. Platform badges are package metadata, not validation of FlowDesk's browser/device matrix. All four listings include Web support. Preserve the selected package's license notices if one is used.

| Package | Listed version | License | Listing activity / ownership signal | Web listing | Initial fit |
|---|---:|---|---|---|---|
| `showcaseview` | 5.1.0 | MIT | Published about 4 months before check; verified Simform publisher | Yes | Best in-route showcase candidate |
| `tutorial_coach_mark` | 1.3.4 | MIT | Published about 2 months before check; publisher shown | Yes | Flexible low-level coachmark candidate |
| `feature_discovery` | 0.14.2 | MIT | Published about 23 months before check | Yes | Material feature hints, weak fit for the full tour engine |
| `overlay_tooltip` | 0.2.4 | BSD-3-Clause | Published about 18 months before check | Yes | Custom per-screen tooltip sequences |

## Detailed comparison

### `showcaseview` — 5.1.0

- **Targeting and lifecycle:** Step-by-step widget highlighting. Its public feature description supports scrolling a widget into view. The package's showcase target model is intended for visible widgets; the FlowDesk requirements for late registration, disposed targets, duplicate-key avoidance, conditional targets and missing-target retry policies remain application responsibilities unless confirmed in a focused prototype.
- **Overlay and tooltip:** Custom tooltip widgets, title/description/actions, styling, animation and simultaneous target highlighting are documented.
- **FlowDesk fit:** Good candidate if the engine only delegated the visual presentation of a tour already planned by FlowDesk. It does not provide the required GoRouter-aware configuration registry, route transitions, role/permission conditions, cross-route progress coordination or persistence port.
- **Risk:** A renderer adapter must handle route changes and target unmount/remount without coupling the engine to package-owned keys or lifecycle. Verify web scrolling, nested scrollables, resize and browser history in a prototype before adoption.
- **Sources:** [pub.dev package page](https://pub.dev/packages/showcaseview), [package README](https://pub.dev/packages/showcaseview#readme).

### `tutorial_coach_mark` — 1.3.4

- **Targeting and lifecycle:** Each `TargetFocus` accepts a `GlobalKey` or a manually supplied `TargetPosition`. The latter gives an escape hatch for non-key geometry, but the calling app must produce and refresh valid geometry and manage target readiness/disposal.
- **Overlay and tooltip:** Supports custom target content, circle/rounded-rectangle focus, shadow/animation configuration and callbacks. The controller exposes skip, finish, next, previous and go-to-index actions.
- **FlowDesk fit:** Useful if a custom spotlight renderer is desired and geometry can be resolved reliably. The package page documents visual steps, not route planning, scroll-to-target behavior, conditional filtering, target timeout behavior, or cross-route resume.
- **Risk:** Direct screen coordinates can become stale after responsive resizing, scrolling, route transitions or layout changes. Prefer a registry that resolves current render geometry at display time if prototyping this option.
- **Sources:** [pub.dev package page](https://pub.dev/packages/tutorial_coach_mark), [API reference](https://pub.dev/documentation/tutorial_coach_mark/latest/).

### `feature_discovery` — 0.14.2

- **Targeting and lifecycle:** Requires a `DescribedFeatureOverlay` around each described widget, a unique feature ID and a `FeatureDiscovery` wrapper around the application. Ordered discovery is driven with those IDs. The library saves shown/completed flags internally.
- **Overlay and tooltip:** Material Design feature-discovery presentation, with content placement controls and completion/dismiss callbacks. It documents an `EnsureVisible` helper for scrollables.
- **FlowDesk fit:** Appropriate for small, Material-style, one-feature-at-a-time hints. Less suitable for a reusable, dynamic tour engine where FlowDesk owns persistence, tour progress, route-level config, fallback policies and alternate presentations.
- **Risk:** The listed version is substantially older than the other candidates at research time. Test against the project's Flutter/Dart SDK and web renderer before considering it; platform badge alone does not establish current compatibility.
- **Sources:** [pub.dev package page](https://pub.dev/packages/feature_discovery), [API reference](https://pub.dev/documentation/feature_discovery/latest/).

### `overlay_tooltip` — 0.2.4

- **Targeting and lifecycle:** Each target is wrapped in `OverlayTooltipItem` with a numeric `displayIndex`; one `TooltipController` is created for each screen. The page documents start, dismiss, next/previous and pause operations.
- **Overlay and tooltip:** Allows custom tooltip widgets, overlay treatment, animation, and top/bottom plus horizontal alignment choices.
- **FlowDesk fit:** Good for custom per-screen tooltip sequences when all targets are already mounted and ordered. The per-screen controller makes cross-page continuity and route restoration an app-level responsibility. Its ordered wrapper approach is less suited to filtering steps dynamically by permissions or feature availability.
- **Risk:** Test conditional target removal, delayed target creation, scrolling, and controller teardown during route changes before adoption.
- **Sources:** [pub.dev package page](https://pub.dev/packages/overlay_tooltip), [API reference](https://pub.dev/documentation/overlay_tooltip/latest/).

## Requirements coverage

| FlowDesk requirement | ShowcaseView | Tutorial Coach Mark | Feature Discovery | Overlay Tooltip |
|---|---|---|---|---|
| Flutter Web listing | Yes | Yes | Yes | Yes |
| Custom tooltip content | Yes | Yes | Some customization | Yes |
| Scroll target into view | Documented | Not established from package overview | EnsureVisible helper documented | Not established from package overview |
| Dynamic target registry / wait and timeout policies | App work | App work | App work | App work |
| Independent tours by route | App work | App work | App work | App work |
| Cross-route continuation | App work | App work | App work | App work |
| Role/permission/feature conditions | App work | App work | App work | App work |
| Persistence abstraction / resume policy | App work | App work | Internal per-feature flags; not the required abstraction | App work |
| Full FlowDesk fit without orchestration layer | No | No | No | No |

“Not established” means the reviewed package documentation did not establish the capability; it is not a claim that the package can never support it.

## Build-versus-extend decision

**Decision for Phase 1:** Plan a custom, package-independent onboarding engine. Keep package use optional and behind an adapter boundary. Do not expose package-specific `GlobalKey`, `TargetFocus`, feature ID or `displayIndex` types in the engine configuration.

The reusable core should own:

1. Tour/step config and route matching.
2. Conditional step filtering using user, permissions and feature context.
3. Target registration and lifecycle notifications, including mounted/readiness state.
4. Missing-target policy, timeout/retry and fallback decisions.
5. Route transitions and optional cross-route progress.
6. Persistence interface and resume/restart policy.
7. A renderer interface for spotlight geometry, tooltip placement and input controls.

The FlowDesk app should provide GoRouter navigation, repository-backed user context and `SharedPreferences` persistence initially. Keep these app integrations outside the portable renderer/core so the engine can later be extracted for Flutter web and mobile.

## Phase 1 outcome

The four requested packages are researched and compared. The initial architecture direction is to **build the orchestration layer**, with `showcaseview` as the first package worth testing only as a replaceable in-route presentation adapter. Before final dependency selection in Phase 2, verify package API behavior against the project's pinned Flutter/Dart SDK and run focused web checks for late targets, nested scrolling, route changes, resizing and disposal.
