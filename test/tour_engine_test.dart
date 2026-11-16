import 'dart:async';

import 'package:dynamic_tour_engine/dynamic_tour_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TourConfiguration', () {
    test('round trips route, styling, conditions, and fallback policy', () {
      final tour = TourConfiguration(
        id: 'workspace',
        title: 'Workspace',
        showWelcome: true,
        overlayColor: const Color(0xAA123456),
        steps: const [
          TourStep(
            id: 'analytics',
            route: '/dashboard',
            targetId: 'dashboard.analytics',
            title: 'Analytics',
            description: 'Your activity.',
            roles: {'admin'},
            permissions: {'analytics.read'},
            tooltipPosition: TooltipPosition.right,
            missingTargetPolicy: MissingTargetPolicy.pause,
            targetTimeout: Duration(milliseconds: 450),
          ),
        ],
      );

      final restored = TourConfiguration.decode(tour.encode());
      expect(restored.id, tour.id);
      expect(restored.overlayColor, tour.overlayColor);
      expect(restored.showWelcome, isTrue);
      expect(restored.steps.single.route, '/dashboard');
      expect(restored.steps.single.roles, {'admin'});
      expect(restored.steps.single.permissions, {'analytics.read'});
      expect(restored.steps.single.tooltipPosition, TooltipPosition.right);
      expect(
        restored.steps.single.missingTargetPolicy,
        MissingTargetPolicy.pause,
      );
      expect(
        restored.steps.single.targetTimeout,
        const Duration(milliseconds: 450),
      );
    });

    test('reports duplicate steps and malformed required fields', () {
      final invalid = TourConfiguration(
        id: '',
        title: 'Bad',
        steps: const [
          TourStep(
            id: 'same',
            route: '',
            targetId: '',
            title: '',
            description: '',
          ),
          TourStep(
            id: 'same',
            route: '/users',
            targetId: 'users.search',
            title: 'Again',
            description: 'Duplicate.',
          ),
        ],
      );
      expect(invalid.validate(), contains('Tour id must not be empty.'));
      expect(invalid.validate(), contains('Duplicate step id "same".'));
      expect(invalid.validate(), contains('Step "same" has no route.'));
      expect(invalid.validate(), contains('Step "same" has no target id.'));
    });
  });

  group('TourRegistry and target lifecycle', () {
    test('indexes tours by id and all configured routes', () {
      final registry = TourRegistry();
      final tour = TourConfiguration(
        id: 'workspace',
        title: 'Workspace',
        steps: const [
          TourStep(
            id: 'home',
            route: '/dashboard',
            targetId: 'dashboard.metrics',
            title: 'Home',
            description: 'Overview.',
          ),
          TourStep(
            id: 'people',
            route: '/users',
            targetId: 'users.table',
            title: 'People',
            description: 'Directory.',
          ),
        ],
      );
      registry.register(tour);
      expect(registry.byId('workspace'), same(tour));
      expect(registry.forRoute('/dashboard'), [tour]);
      expect(registry.forRoute('/users'), [tour]);
      expect(registry.forRoute('/reports'), isEmpty);
      expect(() => registry.register(tour), throwsArgumentError);
      expect(registry.remove('workspace'), isTrue);
      expect(registry.all, isEmpty);
    });

    test('a stale unregister cannot remove a replacement target key', () {
      final registry = TourTargetRegistry();
      final oldKey = GlobalKey();
      final replacement = GlobalKey();
      registry.register('target', key: oldKey);
      registry.register('target', key: replacement);
      registry.unregister('target', oldKey);
      expect(registry.keyFor('target'), same(replacement));
    });

    testWidgets('rejects duplicate mounted target ids', (tester) async {
      final registry = TourTargetRegistry();
      await tester.pumpWidget(
        MaterialApp(
          home: TourTarget(
            id: 'duplicate',
            registry: registry,
            child: const Text('First'),
          ),
        ),
      );
      expect(
        () => registry.register('duplicate', key: GlobalKey()),
        throwsA(isA<FlutterError>()),
      );
    });
  });

  group('TourController', () {
    late TourTargetRegistry registry;
    late _MemoryProgressStore store;
    late String route;
    late Future<void> Function(String) onNavigate;
    late TourController controller;

    setUp(() {
      registry = TourTargetRegistry();
      store = _MemoryProgressStore();
      route = '/dashboard';
      onNavigate = (nextRoute) async {
        route = nextRoute;
      };
      controller = TourController(
        registry: registry,
        progressStore: store,
        currentRoute: () => route,
        navigate: (nextRoute) => onNavigate(nextRoute),
      );
    });

    tearDown(() async => controller.close());

    testWidgets('starts a target tour and completes from its last step', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TourTarget(
            id: 'analytics',
            registry: registry,
            child: const Text('Analytics'),
          ),
        ),
      );
      await controller.start(
        _tour([
          const TourStep(
            id: 'analytics',
            route: '/dashboard',
            targetId: 'analytics',
            title: 'Analytics',
            description: 'Activity.',
          ),
        ]),
      );

      expect(controller.state.status, TourStatus.active);
      expect(controller.state.currentStep?.id, 'analytics');
      await controller.next();
      expect(controller.state.status, TourStatus.completed);
      expect(await store.isCompleted('test_tour'), isTrue);
    });

    test('skips a target after its configured wait timeout', () async {
      await controller.start(
        _tour([
          const TourStep(
            id: 'not-mounted',
            route: '/dashboard',
            targetId: 'missing',
            title: 'Missing',
            description: 'Not built.',
            targetTimeout: Duration(milliseconds: 1),
            missingTargetPolicy: MissingTargetPolicy.waitThenSkip,
          ),
        ]),
      );

      expect(controller.state.status, TourStatus.completed);
      expect(await store.isCompleted('test_tour'), isTrue);
    });

    test('filters steps that do not match the user role', () async {
      controller.userContext = const TourUserContext(roles: {'member'});
      await controller.start(
        _tour([
          const TourStep(
            id: 'admin-only',
            route: '/dashboard',
            targetId: 'admin.target',
            title: 'Admin',
            description: 'Admins only.',
            roles: {'admin'},
          ),
        ]),
      );

      expect(controller.state.status, TourStatus.failed);
      expect(controller.state.steps, isEmpty);
    });

    testWidgets('a throwing condition predicate excludes only that step', (
      tester,
    ) async {
      controller.userContext = TourUserContext(
        predicates: {'broken': () => throw StateError('condition failed')},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TourTarget(
            id: 'available',
            registry: registry,
            child: const Text('Ready'),
          ),
        ),
      );
      await controller.start(
        _tour(const [
          TourStep(
            id: 'conditional',
            route: '/dashboard',
            targetId: 'missing',
            title: 'Conditional',
            description: 'Should be excluded.',
            conditionKey: 'broken',
          ),
          TourStep(
            id: 'available',
            route: '/dashboard',
            targetId: 'available',
            title: 'Available',
            description: 'Can still run.',
          ),
        ]),
      );
      expect(controller.state.status, TourStatus.active);
      expect(controller.state.currentStep?.id, 'available');
    });

    test('fallback policy keeps a targetless step active', () async {
      await controller.start(
        _tour(const [
          TourStep(
            id: 'fallback',
            route: '/dashboard',
            targetId: 'not-mounted',
            title: 'General tip',
            description: 'This remains useful without a target.',
            targetTimeout: Duration.zero,
            missingTargetPolicy: MissingTargetPolicy.fallback,
          ),
        ]),
      );
      expect(controller.state.status, TourStatus.active);
      expect(controller.state.fallbackTarget, isTrue);
      expect(controller.state.currentStep?.id, 'fallback');
    });

    testWidgets('pause policy can resume after a target is mounted', (
      tester,
    ) async {
      final tour = _tour(const [
        TourStep(
          id: 'delayed',
          route: '/dashboard',
          targetId: 'late',
          title: 'Loaded late',
          description: 'Resume when available.',
          targetTimeout: Duration.zero,
          missingTargetPolicy: MissingTargetPolicy.pause,
        ),
      ]);
      await controller.start(tour);
      expect(controller.state.status, TourStatus.paused);
      await tester.pumpWidget(
        MaterialApp(
          home: TourTarget(
            id: 'late',
            registry: registry,
            child: const Text('Late target'),
          ),
        ),
      );
      await controller.resume();
      expect(controller.state.status, TourStatus.active);
      expect(controller.state.currentStep?.id, 'delayed');
    });

    test('stop policy fails when a target is missing', () async {
      await controller.start(
        _tour(const [
          TourStep(
            id: 'required',
            route: '/dashboard',
            targetId: 'missing',
            title: 'Required',
            description: 'Cannot continue.',
            targetTimeout: Duration.zero,
            missingTargetPolicy: MissingTargetPolicy.stop,
          ),
        ]),
      );
      expect(controller.state.status, TourStatus.failed);
      expect(
        controller.state.message,
        contains('Target missing was not found'),
      );
      expect(store.lastActiveTour, isNull);
    });

    testWidgets('disposing the active target pauses the tour', (tester) async {
      await tester.pumpWidget(_routeApp('/dashboard', registry));
      await controller.start(
        _tour(const [
          TourStep(
            id: 'dashboard',
            route: '/dashboard',
            targetId: 'dashboard',
            title: 'Dashboard',
            description: 'Overview.',
          ),
        ]),
      );
      expect(controller.state.status, TourStatus.active);
      await tester.pumpWidget(const MaterialApp(home: Text('Target removed')));
      expect(controller.state.status, TourStatus.paused);
    });

    testWidgets(
      'wait policy observes a target registered after the tour starts',
      (tester) async {
        final tour = _tour(const [
          TourStep(
            id: 'late',
            route: '/dashboard',
            targetId: 'late',
            title: 'Delayed target',
            description: 'Mounted after loading.',
            targetTimeout: Duration(seconds: 2),
            missingTargetPolicy: MissingTargetPolicy.pause,
          ),
        ]);
        await tester.pumpWidget(
          MaterialApp(
            home: TourTarget(
              id: 'late',
              registry: registry,
              registrationDelay: const Duration(milliseconds: 120),
              child: const Text('Loaded'),
            ),
          ),
        );
        final start = controller.start(tour);
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump();
        await start;
        expect(controller.state.status, TourStatus.active);
        expect(controller.state.currentStep?.id, 'late');
      },
    );

    testWidgets('resume ignores a persisted step removed from configuration', (
      tester,
    ) async {
      store.steps['test_tour'] = 'removed-step';
      await tester.pumpWidget(_routeApp('/dashboard', registry));
      await controller.start(
        _tour(const [
          TourStep(
            id: 'current',
            route: '/dashboard',
            targetId: 'dashboard',
            title: 'Current',
            description: 'First valid step.',
          ),
        ]),
        resume: true,
      );
      expect(controller.state.status, TourStatus.active);
      expect(controller.state.currentStep?.id, 'current');
    });

    testWidgets(
      'external route changes select the next configured route step',
      (tester) async {
        await tester.pumpWidget(_routeApp('/dashboard', registry));
        await controller.start(
          _tour(const [
            TourStep(
              id: 'dashboard',
              route: '/dashboard',
              targetId: 'dashboard',
              title: 'Dashboard',
              description: 'Overview.',
            ),
            TourStep(
              id: 'chat',
              route: '/chat',
              targetId: 'chat',
              title: 'Chat',
              description: 'Messages.',
            ),
          ]),
        );
        route = '/chat';
        await tester.pumpWidget(_routeApp('/chat', registry));
        await controller.handleRouteChanged();
        expect(controller.state.status, TourStatus.active);
        expect(controller.state.currentStep?.id, 'chat');
      },
    );

    testWidgets('pause invalidates an in-flight route transition', (
      tester,
    ) async {
      final navigationStarted = Completer<void>();
      final finishNavigation = Completer<void>();
      await tester.pumpWidget(_routeApp('/dashboard', registry));
      await controller.start(
        _tour(const [
          TourStep(
            id: 'dashboard',
            route: '/dashboard',
            targetId: 'dashboard',
            title: 'Dashboard',
            description: 'Overview.',
          ),
          TourStep(
            id: 'chat',
            route: '/chat',
            targetId: 'chat',
            title: 'Chat',
            description: 'Messages.',
          ),
        ]),
      );
      onNavigate = (nextRoute) {
        route = nextRoute;
        navigationStarted.complete();
        return finishNavigation.future;
      };
      final advancing = controller.next();
      await navigationStarted.future;
      await controller.pause();
      await tester.pumpWidget(_routeApp('/chat', registry));
      finishNavigation.complete();
      await advancing;
      expect(controller.state.status, TourStatus.paused);
    });

    testWidgets('saved active tour resumes at the saved eligible step', (
      tester,
    ) async {
      final tour = _tour(const [
        TourStep(
          id: 'one',
          route: '/dashboard',
          targetId: 'dashboard',
          title: 'One',
          description: 'First.',
        ),
        TourStep(
          id: 'two',
          route: '/dashboard',
          targetId: 'dashboard',
          title: 'Two',
          description: 'Second.',
        ),
      ]);
      await tester.pumpWidget(_routeApp('/dashboard', registry));
      await controller.start(tour);
      await controller.next();
      expect(store.lastActiveTour, 'test_tour');
      expect(store.steps['test_tour'], 'two');
      await controller.close();
      controller = TourController(
        registry: registry,
        progressStore: store,
        currentRoute: () => route,
        navigate: (r) async {
          route = r;
        },
      );
      await controller.start(tour, resume: true);
      expect(controller.state.status, TourStatus.active);
      expect(controller.state.currentStep?.id, 'two');
    });

    testWidgets('navigates to the route declared by the next step', (
      tester,
    ) async {
      await tester.pumpWidget(_routeApp('/dashboard', registry));
      await controller.start(
        _tour([
          const TourStep(
            id: 'dashboard',
            route: '/dashboard',
            targetId: 'dashboard',
            title: 'Dashboard',
            description: 'Home.',
          ),
          const TourStep(
            id: 'chat',
            route: '/chat',
            targetId: 'chat',
            title: 'Chat',
            description: 'Messages.',
          ),
        ]),
      );
      expect(controller.state.currentStep?.id, 'dashboard');

      onNavigate = (nextRoute) async {
        route = nextRoute;
        await tester.pumpWidget(_routeApp(nextRoute, registry));
      };
      await controller.next();

      expect(route, '/chat');
      expect(controller.state.status, TourStatus.active);
      expect(controller.state.currentStep?.id, 'chat');
    });
  });
}

TourConfiguration _tour(List<TourStep> steps) =>
    TourConfiguration(id: 'test_tour', title: 'Test tour', steps: steps);

Widget _routeApp(String route, TourTargetRegistry registry) => MaterialApp(
  home: TourTarget(
    id: route == '/chat' ? 'chat' : 'dashboard',
    registry: registry,
    child: Text(route),
  ),
);

class _MemoryProgressStore implements TourProgressStore, TourSessionStore {
  final Map<String, String> steps = {};
  final Set<String> completed = {};
  final Set<String> skipped = {};
  String? lastActiveTour;

  @override
  Future<String?> readLastActiveTour() async => lastActiveTour;
  @override
  Future<void> saveLastActiveTour(String tourId) async {
    lastActiveTour = tourId;
  }

  @override
  Future<void> clearLastActiveTour(String tourId) async {
    if (lastActiveTour == tourId) lastActiveTour = null;
  }

  @override
  Future<String?> readStep(String id) async => steps[id];
  @override
  Future<void> saveStep(String id, String stepId) async {
    steps[id] = stepId;
  }

  @override
  Future<void> markCompleted(String id) async {
    completed.add(id);
    steps.remove(id);
    await clearLastActiveTour(id);
  }

  @override
  Future<void> markSkipped(String id) async {
    skipped.add(id);
    steps.remove(id);
    await clearLastActiveTour(id);
  }

  @override
  Future<bool> isCompleted(String id) async => completed.contains(id);
  @override
  Future<bool> wasSkipped(String id) async => skipped.contains(id);
  @override
  Future<void> clear(String id) async {
    steps.remove(id);
    completed.remove(id);
    skipped.remove(id);
    await clearLastActiveTour(id);
  }
}
