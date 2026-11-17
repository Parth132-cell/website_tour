import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Location preference for a step's card. [auto] selects the side with most room.
enum TooltipPosition { auto, top, bottom, left, right }

enum MissingTargetPolicy { waitThenSkip, skip, pause, stop, fallback }

enum TourStatus {
  idle,
  welcome,
  loading,
  active,
  paused,
  completed,
  skipped,
  failed,
}

class TourStep {
  const TourStep({
    required this.id,
    required this.route,
    required this.targetId,
    required this.title,
    required this.description,
    this.tooltipPosition = TooltipPosition.auto,
    this.optional = false,
    this.roles = const {},
    this.permissions = const {},
    this.conditionKey,
    this.missingTargetPolicy = MissingTargetPolicy.waitThenSkip,
    this.targetTimeout = const Duration(seconds: 3),
    this.highlightPadding = 8,
  });
  final String id, route, targetId, title, description;
  final TooltipPosition tooltipPosition;
  final bool optional;
  final Set<String> roles, permissions;
  final String? conditionKey;
  final MissingTargetPolicy missingTargetPolicy;
  final Duration targetTimeout;
  final double highlightPadding;

  factory TourStep.fromJson(Map<String, dynamic> json) => TourStep(
    id: json['id'] as String,
    route: json['route'] as String,
    targetId: json['target'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    tooltipPosition: TooltipPosition.values.byName(
      json['tooltipPosition'] as String? ?? 'auto',
    ),
    optional: json['optional'] as bool? ?? false,
    roles: Set<String>.from(json['roles'] as List? ?? const []),
    permissions: Set<String>.from(json['permissions'] as List? ?? const []),
    conditionKey: json['conditionKey'] as String?,
    missingTargetPolicy: MissingTargetPolicy.values.byName(
      json['onMissing'] as String? ?? 'waitThenSkip',
    ),
    targetTimeout: Duration(milliseconds: json['timeoutMs'] as int? ?? 3000),
    highlightPadding: (json['highlightPadding'] as num?)?.toDouble() ?? 8,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'route': route,
    'target': targetId,
    'title': title,
    'description': description,
    'tooltipPosition': tooltipPosition.name,
    'optional': optional,
    'roles': roles.toList(),
    'permissions': permissions.toList(),
    if (conditionKey != null) 'conditionKey': conditionKey,
    'onMissing': missingTargetPolicy.name,
    'timeoutMs': targetTimeout.inMilliseconds,
    'highlightPadding': highlightPadding,
  };
}

class TourConfiguration {
  const TourConfiguration({
    required this.id,
    required this.title,
    required this.steps,
    this.allowRouteChanges = true,
    this.showWelcome = false,
    this.overlayColor = const Color(0xB8000000),
  });
  final String id, title;
  final List<TourStep> steps;
  final bool allowRouteChanges, showWelcome;
  final Color overlayColor;
  factory TourConfiguration.fromJson(Map<String, dynamic> json) =>
      TourConfiguration(
        id: json['tourId'] as String,
        title: json['title'] as String? ?? '',
        allowRouteChanges: json['allowRouteChanges'] as bool? ?? true,
        showWelcome: json['showWelcome'] as bool? ?? false,
        overlayColor: Color(json['overlayColor'] as int? ?? 0xB8000000),
        steps: (json['steps'] as List)
            .map((e) => TourStep.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
  Map<String, Object?> toJson() => {
    'tourId': id,
    'title': title,
    'allowRouteChanges': allowRouteChanges,
    'showWelcome': showWelcome,
    'overlayColor': overlayColor.toARGB32(),
    'steps': steps.map((e) => e.toJson()).toList(),
  };
  factory TourConfiguration.decode(String source) =>
      TourConfiguration.fromJson(jsonDecode(source) as Map<String, dynamic>);
  String encode() => jsonEncode(toJson());

  /// Returns configuration errors before a tour is started.
  List<String> validate() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('Tour id must not be empty.');
    if (steps.isEmpty) errors.add('Tour must contain at least one step.');
    final ids = <String>{};
    for (final step in steps) {
      if (step.id.trim().isEmpty) errors.add('Step id must not be empty.');
      if (!ids.add(step.id)) errors.add('Duplicate step id "${step.id}".');
      if (step.route.trim().isEmpty)
        errors.add('Step "${step.id}" has no route.');
      if (step.targetId.trim().isEmpty)
        errors.add('Step "${step.id}" has no target id.');
      if (step.targetTimeout.isNegative)
        errors.add('Step "${step.id}" has a negative timeout.');
      if (step.highlightPadding.isNegative)
        errors.add('Step "${step.id}" has negative highlight padding.');
    }
    return errors;
  }
}

/// Holds application-independent tour definitions by id and route.
class TourRegistry {
  final Map<String, TourConfiguration> _tours = {};

  void register(TourConfiguration tour, {bool replace = false}) {
    final errors = tour.validate();
    if (errors.isNotEmpty)
      throw ArgumentError('Invalid tour "${tour.id}": ${errors.join(' ')}');
    if (_tours.containsKey(tour.id) && !replace) {
      throw ArgumentError('A tour with id "${tour.id}" is already registered.');
    }
    _tours[tour.id] = tour;
  }

  TourConfiguration? byId(String id) => _tours[id];

  List<TourConfiguration> forRoute(String route) => List.unmodifiable(
    _tours.values.where(
      (tour) => tour.steps.any((step) => step.route == route),
    ),
  );

  List<TourConfiguration> get all => List.unmodifiable(_tours.values);

  bool remove(String id) => _tours.remove(id) != null;
  void clear() => _tours.clear();
}

class TourUserContext {
  const TourUserContext({
    this.roles = const {},
    this.permissions = const {},
    this.predicates = const {},
  });
  final Set<String> roles, permissions;
  final Map<String, bool Function()> predicates;
}

class TourTargetRegistry extends ChangeNotifier {
  final Map<String, GlobalKey> _targets = {};

  void _notifyTargetsChanged() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!hasListeners) return;
        notifyListeners();
      });
    }
  }

  GlobalKey register(String id, {GlobalKey? key}) {
    if (id.trim().isEmpty)
      throw ArgumentError.value(id, 'id', 'Target id must not be empty.');
    final next = key ?? GlobalKey();
    final current = _targets[id];
    if (current != null &&
        !identical(current, next) &&
        current.currentContext?.mounted == true) {
      throw FlutterError(
        'More than one mounted TourTarget uses id "$id". Target ids must be unique.',
      );
    }
    _targets[id] = next;
    _notifyTargetsChanged();
    return next;
  }

  void unregister(String id, GlobalKey key) {
    if (identical(_targets[id], key)) {
      _targets.remove(id);
      _notifyTargetsChanged();
    }
  }

  GlobalKey? keyFor(String id) => _targets[id];
  bool isMounted(String id) => _targets[id]?.currentContext?.mounted == true;
  bool isReady(String id) {
    final context = _targets[id]?.currentContext;
    if (context == null || !context.mounted) return false;
    final object = context.findRenderObject();
    return object is RenderBox &&
        object.attached &&
        object.hasSize &&
        object.size.width > 0 &&
        object.size.height > 0;
  }

  /// Waits for a mounted registration. Layout geometry is checked after registration
  /// by the controller on a subsequent frame.
  Future<GlobalKey?> waitForTarget(String id, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final key = _targets[id];
      if (isReady(id)) return key;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    final key = _targets[id];
    return isReady(id) ? key : null;
  }
}

/// Wrap a widget with this anchor. A delay can model targets that mount after data loads.
class TourTarget extends StatefulWidget {
  const TourTarget({
    super.key,
    required this.id,
    required this.registry,
    required this.child,
    this.registrationDelay = Duration.zero,
  });
  final String id;
  final TourTargetRegistry registry;
  final Widget child;
  final Duration registrationDelay;
  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  late GlobalKey _key;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _register(widget);
  }

  void _register(TourTarget target) {
    _key = GlobalKey();
    if (target.registrationDelay == Duration.zero) {
      target.registry.register(target.id, key: _key);
    } else {
      _timer = Timer(target.registrationDelay, () {
        if (mounted) target.registry.register(target.id, key: _key);
      });
    }
  }

  @override
  void didUpdateWidget(covariant TourTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry ||
        oldWidget.id != widget.id ||
        oldWidget.registrationDelay != widget.registrationDelay) {
      _timer?.cancel();
      oldWidget.registry.unregister(oldWidget.id, _key);
      _register(widget);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.registry.unregister(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

class TourState {
  const TourState({
    this.status = TourStatus.idle,
    this.tour,
    this.steps = const [],
    this.index = 0,
    this.message,
    this.fallbackTarget = false,
  });
  final TourStatus status;
  final TourConfiguration? tour;
  final List<TourStep> steps;
  final int index;
  final String? message;
  final bool fallbackTarget;
  TourStep? get currentStep =>
      index >= 0 && index < steps.length ? steps[index] : null;
  TourState copyWith({
    TourStatus? status,
    TourConfiguration? tour,
    List<TourStep>? steps,
    int? index,
    String? message,
    bool clearMessage = false,
    bool? fallbackTarget,
  }) => TourState(
    status: status ?? this.status,
    tour: tour ?? this.tour,
    steps: steps ?? this.steps,
    index: index ?? this.index,
    message: clearMessage ? null : message ?? this.message,
    fallbackTarget: fallbackTarget ?? this.fallbackTarget,
  );
}

abstract interface class TourProgressStore {
  Future<String?> readStep(String tourId);
  Future<void> saveStep(String tourId, String stepId);
  Future<void> markCompleted(String tourId);
  Future<void> markSkipped(String tourId);
  Future<bool> isCompleted(String tourId);
  Future<bool> wasSkipped(String tourId);
  Future<void> clear(String tourId);
}

/// Optional session metadata for restoring the tour that was active at reload.
abstract interface class TourSessionStore {
  Future<String?> readLastActiveTour();
  Future<void> saveLastActiveTour(String tourId);
  Future<void> clearLastActiveTour(String tourId);
}

class SharedPreferencesTourProgressStore
    implements TourProgressStore, TourSessionStore {
  static const _prefix = 'dynamic_tour.';
  static const _lastActiveKey = '${_prefix}last_active_tour';
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> readLastActiveTour() async =>
      (await _prefs).getString(_lastActiveKey);

  @override
  Future<void> saveLastActiveTour(String tourId) async {
    await (await _prefs).setString(_lastActiveKey, tourId);
  }

  @override
  Future<void> clearLastActiveTour(String tourId) async {
    final prefs = await _prefs;
    if (prefs.getString(_lastActiveKey) == tourId) {
      await prefs.remove(_lastActiveKey);
    }
  }

  @override
  Future<String?> readStep(String id) async =>
      (await _prefs).getString('$_prefix$id.step');
  @override
  Future<void> saveStep(String id, String step) async {
    await (await _prefs).setString('$_prefix$id.step', step);
  }

  @override
  Future<void> markCompleted(String id) async {
    final p = await _prefs;
    await p.setBool('$_prefix$id.completed', true);
    await p.remove('$_prefix$id.skipped');
    await p.remove('$_prefix$id.step');
    if (p.getString(_lastActiveKey) == id) await p.remove(_lastActiveKey);
  }

  @override
  Future<void> markSkipped(String id) async {
    final p = await _prefs;
    await p.setBool('$_prefix$id.skipped', true);
    await p.remove('$_prefix$id.completed');
    await p.remove('$_prefix$id.step');
    if (p.getString(_lastActiveKey) == id) await p.remove(_lastActiveKey);
  }

  @override
  Future<bool> isCompleted(String id) async =>
      (await _prefs).getBool('$_prefix$id.completed') ?? false;
  @override
  Future<bool> wasSkipped(String id) async =>
      (await _prefs).getBool('$_prefix$id.skipped') ?? false;
  @override
  Future<void> clear(String id) async {
    final p = await _prefs;
    await p.remove('$_prefix$id.step');
    await p.remove('$_prefix$id.completed');
    await p.remove('$_prefix$id.skipped');
    if (p.getString(_lastActiveKey) == id) await p.remove(_lastActiveKey);
  }
}

typedef TourNavigate = Future<void> Function(String route);
typedef TourRouteReader = String Function();

class TourController extends Cubit<TourState> {
  TourController({
    required this.registry,
    required this.navigate,
    required this.currentRoute,
    TourProgressStore? progressStore,
    this.userContext = const TourUserContext(),
  }) : progressStore = progressStore ?? SharedPreferencesTourProgressStore(),
       super(const TourState()) {
    registry.addListener(_onTargetsChanged);
  }

  final TourTargetRegistry registry;
  final TourNavigate navigate;
  final TourRouteReader currentRoute;
  final TourProgressStore progressStore;
  TourUserContext userContext;
  bool _disposed = false;
  int _operation = 0;

  List<TourStep> _eligible(TourConfiguration tour) => tour.steps.where((step) {
    if (step.roles.isNotEmpty &&
        step.roles.intersection(userContext.roles).isEmpty)
      return false;
    if (!userContext.permissions.containsAll(step.permissions)) return false;
    if (step.conditionKey == null) return true;
    try {
      return userContext.predicates[step.conditionKey]?.call() ?? false;
    } catch (_) {
      return false;
    }
  }).toList();

  bool _isCurrent(int operation) => !_disposed && operation == _operation;

  Future<void> _saveLastActive(String tourId) async {
    final store = progressStore;
    if (store is TourSessionStore) {
      await (store as TourSessionStore).saveLastActiveTour(tourId);
    }
  }

  Future<void> _clearLastActive(String tourId) async {
    final store = progressStore;
    if (store is TourSessionStore) {
      await (store as TourSessionStore).clearLastActiveTour(tourId);
    }
  }

  void _onTargetsChanged() {
    final step = state.currentStep;
    if (state.status == TourStatus.active &&
        !state.fallbackTarget &&
        step != null &&
        currentRoute() == step.route &&
        !registry.isReady(step.targetId)) {
      unawaited(pause());
    }
  }

  Future<void> start(TourConfiguration tour, {bool resume = false}) async {
    if (_disposed) return;
    final operation = ++_operation;
    final errors = tour.validate();
    if (errors.isNotEmpty) {
      await _clearLastActive(tour.id);
      if (!_isCurrent(operation)) return;
      emit(
        TourState(
          status: TourStatus.failed,
          tour: tour,
          message: errors.join('\n'),
        ),
      );
      return;
    }
    if (!resume) await progressStore.clear(tour.id);
    if (!_isCurrent(operation)) return;
    await _saveLastActive(tour.id);
    if (!_isCurrent(operation)) return;
    final steps = _eligible(tour);
    if (steps.isEmpty) {
      await _clearLastActive(tour.id);
      if (!_isCurrent(operation)) return;
      emit(
        TourState(
          status: TourStatus.failed,
          tour: tour,
          message: 'No steps apply to this user.',
        ),
      );
      return;
    }
    var index = 0;
    var restored = false;
    if (resume) {
      final saved = await progressStore.readStep(tour.id);
      if (!_isCurrent(operation)) return;
      final found = steps.indexWhere((step) => step.id == saved);
      if (found >= 0) {
        index = found;
        restored = true;
      }
    }
    if (tour.showWelcome && !restored) {
      emit(
        TourState(
          status: TourStatus.welcome,
          tour: tour,
          steps: steps,
          index: index,
        ),
      );
      return;
    }
    emit(
      TourState(
        status: TourStatus.loading,
        tour: tour,
        steps: steps,
        index: index,
      ),
    );
    await _showAt(index, operation);
  }

  Future<void> continueFromWelcome() async {
    if (state.status != TourStatus.welcome) return;
    final operation = ++_operation;
    await _showAt(state.index, operation);
  }

  Future<void> next() async {
    if (state.status != TourStatus.active) return;
    final operation = ++_operation;
    if (state.index + 1 >= state.steps.length) {
      await _finish(operation);
      return;
    }
    await _showAt(state.index + 1, operation);
  }

  Future<void> previous() async {
    if (state.status != TourStatus.active || state.index <= 0) return;
    final operation = ++_operation;
    await _showAt(state.index - 1, operation);
  }

  Future<void> goToStep(String id) async {
    final index = state.steps.indexWhere((step) => step.id == id);
    if (index < 0 || state.tour == null) return;
    final operation = ++_operation;
    await _showAt(index, operation);
  }

  /// Returns true when the missing-target policy ended or paused this attempt.
  /// A false return means the caller should skip the step and continue planning.
  Future<bool> _handleMissingTarget(
    TourStep step,
    int index,
    int operation,
  ) async {
    switch (step.missingTargetPolicy) {
      case MissingTargetPolicy.skip:
      case MissingTargetPolicy.waitThenSkip:
        return false;
      case MissingTargetPolicy.pause:
        emit(
          state.copyWith(
            status: TourStatus.paused,
            index: index,
            message: 'Waiting for target ${step.targetId}.',
          ),
        );
        return true;
      case MissingTargetPolicy.stop:
        final id = state.tour?.id;
        if (id != null) await _clearLastActive(id);
        if (_isCurrent(operation)) {
          emit(
            state.copyWith(
              status: TourStatus.failed,
              index: index,
              message: 'Target ${step.targetId} was not found.',
            ),
          );
        }
        return true;
      case MissingTargetPolicy.fallback:
        final id = state.tour?.id;
        if (id != null) await progressStore.saveStep(id, step.id);
        if (_isCurrent(operation)) {
          emit(
            state.copyWith(
              status: TourStatus.active,
              index: index,
              fallbackTarget: true,
              message:
                  'Target unavailable; showing this step without a spotlight.',
            ),
          );
        }
        return true;
    }
  }

  Future<void> _showAt(int initial, int operation) async {
    var index = initial;
    while (index < state.steps.length && _isCurrent(operation)) {
      final step = state.steps[index];
      emit(
        state.copyWith(
          status: TourStatus.loading,
          index: index,
          clearMessage: true,
          fallbackTarget: false,
        ),
      );
      if (currentRoute() != step.route) {
        if (!(state.tour?.allowRouteChanges ?? false)) {
          emit(
            state.copyWith(
              status: TourStatus.paused,
              message: 'Step belongs to ${step.route}.',
            ),
          );
          return;
        }
        try {
          await navigate(step.route);
        } catch (error) {
          final id = state.tour?.id;
          if (id != null) await _clearLastActive(id);
          if (_isCurrent(operation))
            emit(
              state.copyWith(
                status: TourStatus.failed,
                message: 'Could not navigate to ${step.route}: $error',
              ),
            );
          return;
        }
        if (!_isCurrent(operation)) return;
      }

      final key = await registry.waitForTarget(
        step.targetId,
        step.missingTargetPolicy == MissingTargetPolicy.skip
            ? Duration.zero
            : step.targetTimeout,
      );
      if (!_isCurrent(operation)) return;
      if (key == null) {
        if (await _handleMissingTarget(step, index, operation)) return;
        index++;
        continue;
      }

      final targetContext = key.currentContext;
      if (targetContext == null ||
          !targetContext.mounted ||
          !registry.isReady(step.targetId)) {
        if (await _handleMissingTarget(step, index, operation)) return;
        index++;
        continue;
      }
      try {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 320),
          alignment: 0.28,
        );
      } catch (_) {
        // A target outside a Scrollable is already addressable.
      }
      if (!_isCurrent(operation)) return;
      if (!registry.isReady(step.targetId)) {
        if (await _handleMissingTarget(step, index, operation)) return;
        index++;
        continue;
      }
      await progressStore.saveStep(state.tour!.id, step.id);
      if (!_isCurrent(operation)) return;
      emit(
        state.copyWith(
          status: TourStatus.active,
          index: index,
          clearMessage: true,
          fallbackTarget: false,
        ),
      );
      return;
    }
    if (_isCurrent(operation)) await _finish(operation);
  }

  Future<void> handleRouteChanged() async {
    if (state.status != TourStatus.active ||
        state.currentStep?.route == currentRoute())
      return;
    final operation = ++_operation;
    if (!(state.tour?.allowRouteChanges ?? false)) {
      emit(
        state.copyWith(
          status: TourStatus.paused,
          message: 'Tour paused after navigation.',
        ),
      );
      return;
    }
    final route = currentRoute();
    var nextOnRoute = -1;
    for (var i = state.index + 1; i < state.steps.length; i++) {
      if (state.steps[i].route == route) {
        nextOnRoute = i;
        break;
      }
    }
    if (nextOnRoute < 0)
      nextOnRoute = state.steps.indexWhere((step) => step.route == route);
    if (nextOnRoute < 0) {
      emit(
        state.copyWith(
          status: TourStatus.paused,
          message: 'No tour step is configured for $route.',
        ),
      );
    } else {
      await _showAt(nextOnRoute, operation);
    }
  }

  Future<void> pause() async {
    if (state.status != TourStatus.active && state.status != TourStatus.loading)
      return;
    ++_operation;
    emit(state.copyWith(status: TourStatus.paused, message: 'Tour paused.'));
  }

  Future<void> resume() async {
    if (state.status != TourStatus.paused) return;
    final operation = ++_operation;
    await _showAt(state.index, operation);
  }

  Future<void> skip() async {
    final operation = ++_operation;
    final tour = state.tour;
    if (tour != null) {
      await progressStore.markSkipped(tour.id);
      await _clearLastActive(tour.id);
    }
    if (_isCurrent(operation))
      emit(state.copyWith(status: TourStatus.skipped, fallbackTarget: false));
  }

  Future<void> _finish(int operation) async {
    final tour = state.tour;
    if (tour != null) {
      await progressStore.markCompleted(tour.id);
      await _clearLastActive(tour.id);
    }
    if (_isCurrent(operation))
      emit(state.copyWith(status: TourStatus.completed, fallbackTarget: false));
  }

  Future<void> finish() async {
    final operation = ++_operation;
    await _finish(operation);
  }

  Future<void> restart(TourConfiguration tour) async {
    final operation = ++_operation;
    await progressStore.clear(tour.id);
    if (_isCurrent(operation)) await start(tour);
  }

  @override
  Future<void> close() {
    _disposed = true;
    ++_operation;
    registry.removeListener(_onTargetsChanged);
    return super.close();
  }
}

/// Small app-level setup for projects that do not need to manage the engine
/// registries and controller themselves.
///
/// Wrap the application once, use [TourAnchor] around guided widgets, and start
/// a tour with `TourExperience.of(context).start('tour_id')`.
class TourExperience extends StatefulWidget {
  const TourExperience({
    super.key,
    required this.tours,
    required this.child,
    this.currentRoute = _defaultTourRoute,
    this.navigate = _defaultTourNavigate,
    this.progressStore,
    this.userContext = const TourUserContext(),
    this.cardColor = Colors.white,
    this.accentColor = const Color(0xFF0B6B59),
  });

  final List<TourConfiguration> tours;
  final Widget child;
  final TourRouteReader currentRoute;
  final TourNavigate navigate;
  final TourProgressStore? progressStore;
  final TourUserContext userContext;
  final Color cardColor;
  final Color accentColor;

  static TourExperienceHandle of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_TourExperienceScope>();
    if (scope == null) {
      throw FlutterError(
        'TourExperience.of(context) was called outside a TourExperience.',
      );
    }
    return scope.handle;
  }

  @override
  State<TourExperience> createState() => _TourExperienceState();
}

String _defaultTourRoute() => '/';
Future<void> _defaultTourNavigate(String route) async {}

class _TourExperienceState extends State<TourExperience> {
  late final TourRegistry tourRegistry;
  late final TourTargetRegistry targetRegistry;
  late final TourController controller;

  @override
  void initState() {
    super.initState();
    tourRegistry = TourRegistry();
    targetRegistry = TourTargetRegistry();
    for (final tour in widget.tours) {
      tourRegistry.register(tour);
    }
    controller = TourController(
      registry: targetRegistry,
      currentRoute: () => widget.currentRoute(),
      navigate: (route) => widget.navigate(route),
      progressStore: widget.progressStore,
      userContext: widget.userContext,
    );
  }

  @override
  void didUpdateWidget(covariant TourExperience oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tours, widget.tours)) {
      tourRegistry.clear();
      for (final tour in widget.tours) {
        tourRegistry.register(tour);
      }
    }
    controller.userContext = widget.userContext;
  }

  @override
  void dispose() {
    unawaited(controller.close());
    targetRegistry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handle = TourExperienceHandle._(
      tourRegistry: tourRegistry,
      targetRegistry: targetRegistry,
      controller: controller,
    );
    return _TourExperienceScope(
      handle: handle,
      child: TourOverlayHost(
        controller: controller,
        cardColor: widget.cardColor,
        accentColor: widget.accentColor,
        child: widget.child,
      ),
    );
  }
}

/// Access to tours and anchors owned by the nearest [TourExperience].
class TourExperienceHandle {
  TourExperienceHandle._({
    required this.tourRegistry,
    required this.targetRegistry,
    required this.controller,
  });

  final TourRegistry tourRegistry;
  final TourTargetRegistry targetRegistry;
  final TourController controller;

  Future<void> start(String tourId, {bool resume = false}) async {
    final tour = tourRegistry.byId(tourId);
    if (tour == null) {
      throw ArgumentError.value(tourId, 'tourId', 'No tour is registered.');
    }
    await controller.start(tour, resume: resume);
  }
}

class _TourExperienceScope extends InheritedWidget {
  const _TourExperienceScope({required this.handle, required super.child});
  final TourExperienceHandle handle;

  @override
  bool updateShouldNotify(_TourExperienceScope oldWidget) =>
      oldWidget.handle.controller != handle.controller ||
      oldWidget.handle.targetRegistry != handle.targetRegistry;
}

/// Marks a widget as a tour target without passing a registry around.
class TourAnchor extends StatelessWidget {
  const TourAnchor({
    super.key,
    required this.id,
    required this.child,
    this.registrationDelay = Duration.zero,
  });

  final String id;
  final Widget child;
  final Duration registrationDelay;

  @override
  Widget build(BuildContext context) => TourTarget(
    id: id,
    registry: TourExperience.of(context).targetRegistry,
    registrationDelay: registrationDelay,
    child: child,
  );
}

/// Root overlay host. Place above the routed app content to draw the spotlight and card.
class TourOverlayHost extends StatelessWidget {
  const TourOverlayHost({
    super.key,
    required this.controller,
    required this.child,
    this.cardColor = const Color(0xFFFFFFFF),
    this.accentColor = const Color(0xFF0B6B59),
  });
  final TourController controller;
  final Widget child;
  final Color cardColor, accentColor;
  @override
  Widget build(BuildContext context) => Overlay(
    initialEntries: [
      OverlayEntry(
        builder: (overlayContext) => AnimatedBuilder(
          animation: controller.registry,
          builder: (context, _) => BlocBuilder<TourController, TourState>(
            bloc: controller,
            builder: (context, state) => LayoutBuilder(
              builder: (context, constraints) {
                final step = state.currentStep;
                final key = step == null
                    ? null
                    : controller.registry.keyFor(step.targetId);
                if (state.status == TourStatus.welcome) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      child,
                      Positioned.fill(
                        child: ColoredBox(color: const Color(0x990E1720)),
                      ),
                      Center(
                        child: Material(
                          color: Colors.white,
                          elevation: 24,
                          borderRadius: BorderRadius.circular(24),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(32, 30, 32, 26),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6F5F1),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Color(0xFF0B6B59),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Welcome to ${state.tour?.title ?? 'the tour'}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF17212B),
                                      fontSize: 23,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -.35,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Take a quick guided look around. You can skip at any time.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF647180),
                                      height: 1.55,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton(
                                        onPressed: controller.skip,
                                        child: const Text('Skip tour'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed:
                                            controller.continueFromWelcome,
                                        child: const Text('Start tour'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                if (state.status == TourStatus.failed) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      child,
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 16,
                        child: Center(
                          child: Material(
                            color: const Color(0xFF172033),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      state.message ??
                                          'Tour could not continue.',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton(
                                    onPressed: controller.skip,
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                if (state.status == TourStatus.active &&
                    state.fallbackTarget &&
                    step != null) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      child,
                      Positioned.fill(
                        child: ColoredBox(
                          color:
                              (state.tour?.overlayColor ??
                                      const Color(0x990E1720))
                                  .withOpacity(.68),
                        ),
                      ),
                      Center(
                        child: Material(
                          color: cardColor,
                          elevation: 22,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(color: Color(0xFFE3E8EF)),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: math.min(
                                420,
                                constraints.maxWidth - 32,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          state.tour?.title ?? 'Quick tour',
                                          style: TextStyle(
                                            color: const Color(0xFF647180),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Close tour',
                                        onPressed: controller.skip,
                                        icon: const Icon(
                                          Icons.close,
                                          color: const Color(0xFF647180),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    step.title,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF17212B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    step.description,
                                    style: const TextStyle(
                                      height: 1.45,
                                      color: Color(0xFF536170),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    state.message ??
                                        'The target is not available. Showing this step without a spotlight.',
                                    style: const TextStyle(
                                      color: Color(0xFF647180),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  LinearProgressIndicator(
                                    value:
                                        (state.index + 1) / state.steps.length,
                                    color: accentColor,
                                    backgroundColor: const Color(0xFFE8EDF1),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${state.index + 1} / ${state.steps.length}',
                                        style: const TextStyle(
                                          color: Color(0xFF647180),
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: controller.skip,
                                        child: const Text('Skip'),
                                      ),
                                      if (state.index > 0)
                                        TextButton(
                                          onPressed: controller.previous,
                                          child: const Text('Back'),
                                        ),
                                      FilledButton(
                                        onPressed: controller.next,
                                        child: Text(
                                          state.index + 1 == state.steps.length
                                              ? 'Finish'
                                              : 'Next',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                if (state.status == TourStatus.paused) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      child,
                      Positioned(
                        top: 20,
                        left: 20,
                        right: 20,
                        child: Center(
                          child: Material(
                            color: const Color(0xFF172033),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      state.message ?? 'Tour paused',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton(
                                    onPressed: controller.skip,
                                    child: const Text('End'),
                                  ),
                                  FilledButton(
                                    onPressed: controller.resume,
                                    child: const Text('Resume'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                if (state.status != TourStatus.active ||
                    step == null ||
                    key?.currentContext == null) {
                  return child;
                }
                final box = context.findRenderObject() as RenderBox?;
                final targetBox =
                    key!.currentContext!.findRenderObject() as RenderBox?;
                if (box == null || targetBox == null || !targetBox.attached) {
                  return child;
                }
                final rect = Rect.fromPoints(
                  box.globalToLocal(targetBox.localToGlobal(Offset.zero)),
                  box.globalToLocal(
                    targetBox.localToGlobal(
                      targetBox.size.bottomRight(Offset.zero),
                    ),
                  ),
                ).inflate(step.highlightPadding);
                final width = constraints.maxWidth,
                    height = constraints.maxHeight;
                final remaining = state.steps.length - state.index;
                final spot = step.tooltipPosition == TooltipPosition.auto
                    ? (height - rect.bottom > 210
                          ? TooltipPosition.bottom
                          : TooltipPosition.top)
                    : step.tooltipPosition;
                final cardWidth = math.min(360.0, math.max(240.0, width - 32));
                final side =
                    spot == TooltipPosition.left ||
                    spot == TooltipPosition.right;
                final desiredLeft = spot == TooltipPosition.left
                    ? rect.left - cardWidth - 16
                    : spot == TooltipPosition.right
                    ? rect.right + 16
                    : rect.center.dx - cardWidth / 2;
                final left = desiredLeft
                    .clamp(16.0, math.max(16.0, width - cardWidth - 16))
                    .toDouble();
                final desiredTop = side
                    ? rect.center.dy - 100
                    : spot == TooltipPosition.bottom
                    ? rect.bottom + 18
                    : rect.top - 188;
                final top = desiredTop
                    .clamp(16.0, math.max(16.0, height - 220))
                    .toDouble();
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    child,
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: CustomPaint(
                          painter: _SpotlightPainter(
                            rect,
                            state.tour?.overlayColor ?? const Color(0x990E1720),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: rect,
                      child: IgnorePointer(child: const SizedBox.expand()),
                    ),
                    Positioned(
                      left: left,
                      top: top,
                      width: cardWidth,
                      child: Material(
                        color: cardColor,
                        elevation: 22,
                        shadowColor: const Color(0x330E1720),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Color(0xFFE3E8EF)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      state.tour?.title ?? 'Quick tour',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF647180),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6F5F1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${state.index + 1} OF ${state.steps.length}',
                                      style: const TextStyle(
                                        color: Color(0xFF0B6B59),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: .5,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Close tour',
                                    onPressed: controller.skip,
                                    icon: const Icon(
                                      Icons.close,
                                      color: Color(0xFF647180),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                step.title,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.25,
                                  color: Color(0xFF17212B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                step.description,
                                style: const TextStyle(
                                  height: 1.45,
                                  color: Color(0xFF536170),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.near_me_outlined,
                                    size: 15,
                                    color: Color(0xFF0B6B59),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      step.route,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF647180),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  minHeight: 5,
                                  value: (state.index + 1) / state.steps.length,
                                  color: accentColor,
                                  backgroundColor: const Color(0xFFE8EDF1),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  Text(
                                    'Step ${state.index + 1} of ${state.steps.length}',
                                    style: const TextStyle(
                                      color: Color(0xFF647180),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: controller.skip,
                                    child: const Text('Skip'),
                                  ),
                                  if (state.index > 0)
                                    TextButton(
                                      onPressed: controller.previous,
                                      child: const Text('Back'),
                                    ),
                                  FilledButton(
                                    onPressed: controller.next,
                                    child: Text(
                                      remaining == 1 ? 'Finish' : 'Next',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ],
  );
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.rect, this.color);
  final Rect rect;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()
        ..color = const Color(0xFF0B6B59)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.rect != rect || old.color != color;
}

/// GoRouter adapter helpers. Supply [router] and use [routeReader] to account for shell routes.
class GoRouterTourAdapter {
  const GoRouterTourAdapter(this.router);
  final GoRouter router;
  Future<void> go(String route) async {
    router.go(route);
    await WidgetsBinding.instance.endOfFrame;
  }

  String get currentRoute => router.routeInformationProvider.value.uri.path;
}
