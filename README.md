# FlowDesk and Reusable Dynamic Tour Engine

This is one Flutter project. The reusable tour engine lives in `lib/dynamic_tour_engine.dart`; the FlowDesk app in `lib/main.dart` shows it in a complete routed product UI.

## Project phases

- Phase 1 package research: `PHASE1_PACKAGE_RESEARCH.md`.
- Phase 2 architecture and design system: `PHASE2_ARCHITECTURE_AND_DESIGN_SYSTEM.md`.
- Phase 3 FlowDesk UI and navigation: `PHASE3_FLOWDESK_UI.md`.
- Phase 4 mock data and interactions: `PHASE4_INTERACTIONS.md`.
- Phase 5 reusable engine: `PHASE5_ENGINE.md`.
- Phase 6 module tours: `PHASE6_MODULE_TOURS.md`.
- Phase 7 navigation and persistence: `PHASE7_DYNAMIC_NAVIGATION_PERSISTENCE.md`.

## Run the demo

From this project directory, run:

```powershell
flutter pub get
flutter run -d chrome
```

The app includes Dashboard, Users, Alumni, Messages, Events, Reports, Notifications, Settings and Profile routes. Each route has an independent tour. The Help menu also starts an optional cross-route workspace tour. SharedPreferences stores local progress and restores the last active tour after reload.

## Use it in another Flutter project

The engine and the app are kept together in this project. To reuse the engine from another project during local development, add this project to that app's `pubspec.yaml` (adjust the relative path to your folders):

```yaml
dependencies:
  dynamic_tour_engine:
    path: ../dynamic_tour_engine
```

For a typical app, add one `TourExperience` around your app, use `TourAnchor` on the widgets a tour should point to, and start a tour from any button. The wrapper creates and owns the registries, controller, and overlay for you.

```dart
import 'package:dynamic_tour_engine/dynamic_tour_engine.dart';
import 'package:flutter/material.dart';

TourExperience(
  tours: [
    TourConfiguration(
      id: 'first_run',
      title: 'Getting started',
      steps: [
        TourStep(
          id: 'save_button',
          route: '/',
          targetId: 'save_button',
          title: 'Save your work',
          description: 'Use this button to save your changes.',
        ),
      ],
    ),
  ],
  currentRoute: () => '/',
  child: MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('My app')),
        body: Column(
          children: [
            TourAnchor(
              id: 'save_button',
              child: FilledButton(onPressed: () {}, child: const Text('Save')),
            ),
            FilledButton(
              onPressed: () => TourExperience.of(context).start('first_run'),
              child: const Text('Start tour'),
            ),
          ],
        ),
      ),
    ),
  ),
)
```

For multi-route apps, provide `navigate` and `currentRoute` callbacks that connect to the app's router. Provide a custom `TourProgressStore` when progress should use app-specific or server storage. `TourController`, `TourRegistry`, `TourTargetRegistry`, and `TourOverlayHost` remain available for apps that need full control over setup.
