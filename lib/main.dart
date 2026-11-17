import 'package:dynamic_tour_engine/dynamic_tour_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'demo_store.dart';

void main() => runApp(const FlowDeskApp());

const _teal = Color(0xFF0B6B59);
const _mint = Color(0xFF38CFA6);
const _ink = Color(0xFF17212B);
const _muted = Color(0xFF647180);
const _line = Color(0xFFE3E8EF);
const _canvas = Color(0xFFF5F7FA);

class _Destination {
  const _Destination(this.title, this.path, this.icon);
  final String title, path;
  final IconData icon;
}

const _destinations = [
  _Destination('Dashboard', '/dashboard', Icons.grid_view_rounded),
  _Destination('Users', '/users', Icons.people_alt_outlined),
  _Destination('Alumni', '/alumni', Icons.school_outlined),
  _Destination('Messages', '/messages', Icons.chat_bubble_outline_rounded),
  _Destination('Events', '/events', Icons.calendar_month_outlined),
  _Destination('Reports', '/reports', Icons.insert_chart_outlined_rounded),
  _Destination(
    'Notifications',
    '/notifications',
    Icons.notifications_none_rounded,
  ),
  _Destination('Settings', '/settings', Icons.settings_outlined),
];

class FlowDeskApp extends StatefulWidget {
  const FlowDeskApp({super.key});
  @override
  State<FlowDeskApp> createState() => _FlowDeskAppState();
}

class _FlowDeskAppState extends State<FlowDeskApp> {
  final registry = TourTargetRegistry();
  final tourRegistry = TourRegistry();
  late final GoRouter router;
  late final TourController tourController;
  late final FlowDeskCubit demoCubit;
  String role = 'Admin';
  bool dark = false;

  @override
  void initState() {
    super.initState();
    demoCubit = FlowDeskCubit();
    for (final destination in _destinations) {
      tourRegistry.register(_tourFor(destination.path));
    }
    tourRegistry.register(_tourFor('/profile'));
    tourRegistry.register(_crossTour);
    router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        for (final destination in _destinations)
          GoRoute(
            path: destination.path,
            builder: (_, __) =>
                FlowPage(title: destination.title, registry: registry),
          ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => FlowPage(title: 'My profile', registry: registry),
        ),
      ],
      errorBuilder: (_, state) => FlowPage(
        title: 'Page not found',
        registry: registry,
        detail: state.error?.toString(),
      ),
    );
    tourController = TourController(
      registry: registry,
      navigate: (path) async {
        router.go(path);
        await WidgetsBinding.instance.endOfFrame;
      },
      currentRoute: () => router.routeInformationProvider.value.uri.path,
      userContext: const TourUserContext(
        roles: {'admin'},
        permissions: {'analytics.read', 'users.read'},
      ),
    );
    router.routerDelegate.addListener(_routeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreTour());
  }

  Future<void> _restoreTour() async {
    final path = router.routeInformationProvider.value.uri.path;
    final store = tourController.progressStore;
    if (store is TourSessionStore) {
      final sessionStore = store as TourSessionStore;
      final lastId = await sessionStore.readLastActiveTour();
      if (!mounted) return;
      if (lastId != null) {
        final activeTour = tourRegistry.byId(lastId);
        if (activeTour != null &&
            !await store.isCompleted(lastId) &&
            !await store.wasSkipped(lastId)) {
          await tourController.start(activeTour, resume: true);
          return;
        }
        await sessionStore.clearLastActiveTour(lastId);
      }
    }

    final routeTour = tourRegistry
        .forRoute(path)
        .where((tour) => tour.id != 'workspace_path')
        .firstOrNull;
    if (routeTour == null || !mounted) return;
    if (await store.isCompleted(routeTour.id) ||
        await store.wasSkipped(routeTour.id))
      return;
    await tourController.start(routeTour, resume: true);
  }

  void _routeChanged() => tourController.handleRouteChanged();

  @override
  void dispose() {
    router.routerDelegate.removeListener(_routeChanged);
    router.dispose();
    tourController.close();
    demoCubit.close();
    super.dispose();
  }

  TourConfiguration _tourFor(String path) {
    final page = path == '/profile'
        ? 'My profile'
        : _destinations.where((d) => d.path == path).firstOrNull?.title ??
              'Dashboard';
    final key = page == 'My profile' ? 'profile' : page.toLowerCase();
    final items = switch (page) {
      'Dashboard' => [
        (
          'metrics',
          'Key metrics',
          'Review activity, growth, and outstanding work.',
        ),
        (
          'revenue',
          'Revenue trend',
          'Compare revenue performance across the selected period.',
        ),
        (
          'activity',
          'Recent activity',
          'Keep up with changes across your workspace.',
        ),
      ],
      'Users' => [
        ('search', 'Find a user', 'Search and filter the workspace directory.'),
        (
          'table',
          'User directory',
          'Review roles, statuses, and membership details.',
        ),
        (
          'add',
          'Invite a teammate',
          'Add someone to your workspace and set their access.',
        ),
      ],
      'Alumni' => [
        (
          'filters',
          'Find alumni',
          'Search by name and narrow by department or class year.',
        ),
        (
          'directory',
          'Alumni directory',
          'Browse alumni profiles and current roles.',
        ),
        (
          'profile',
          'Profile details',
          'Open a profile to review contact and career details.',
        ),
      ],
      'Messages' => [
        (
          'conversations',
          'Conversations',
          'Choose a conversation from your inbox.',
        ),
        (
          'details',
          'Conversation details',
          'See who you are messaging and their availability.',
        ),
        (
          'composer',
          'Message composer',
          'Write and send a message to your teammate.',
        ),
      ],
      'Events' => [
        (
          'filters',
          'Find events',
          'Search events and filter by their schedule.',
        ),
        (
          'view_switcher',
          'Calendar and list views',
          'Switch between event cards and the calendar view.',
        ),
        ('create', 'Create an event', 'Add an event for your workspace.'),
      ],
      'Reports' => [
        (
          'member_overview',
          'Reports overview',
          'Explore the reports available to your workspace role.',
        ),
        (
          'report_filters',
          'Report filters',
          'Choose the reporting period and department.',
        ),
        (
          'report_charts',
          'Performance reports',
          'Explore trends across your organization.',
        ),
        (
          'export',
          'Export report',
          'Copy the CSV data or generate a PDF report.',
        ),
      ],
      'Notifications' => [
        (
          'list',
          'Notification inbox',
          'Review updates and mentions from your workspace.',
        ),
        (
          'preferences',
          'Notification preferences',
          'Choose which workspace updates you receive.',
        ),
      ],
      'Settings' => [
        (
          'sections',
          'Settings sections',
          'Choose a category to configure the workspace.',
        ),
        (
          'permissions',
          'User permissions',
          'Set default access and approval rules.',
        ),
        (
          'save',
          'Save settings',
          'Apply your workspace configuration changes.',
        ),
      ],
      'My profile' => [
        (
          'edit',
          'Edit your profile',
          'Update your name, role, and contact information.',
        ),
        (
          'completion',
          'Profile completion',
          'Track profile details that help your teammates.',
        ),
        (
          'security',
          'Account security',
          'Review account and password options.',
        ),
      ],
      _ => [
        (
          'overview',
          'Workspace overview',
          'Explore this part of your workspace.',
        ),
      ],
    };
    return TourConfiguration(
      id: '${key}_tour',
      title: '$page tour',
      showWelcome: true,
      steps: [
        for (final item in items)
          TourStep(
            id: item.$1,
            route: path,
            targetId: item.$1 == 'member_overview'
                ? 'reports.report_charts'
                : '$key.${item.$1}',
            title: item.$2,
            description: item.$3,
            roles: page == 'Reports'
                ? item.$1 == 'member_overview'
                      ? {'member'}
                      : {'admin'}
                : const {},
          ),
      ],
    );
  }

  TourConfiguration get _crossTour => TourConfiguration(
    id: 'workspace_path',
    title: 'FlowDesk workspace tour',
    showWelcome: true,
    allowRouteChanges: true,
    steps: const [
      TourStep(
        id: 'workspace_dashboard',
        route: '/dashboard',
        targetId: 'dashboard.metrics',
        title: 'Your workspace at a glance',
        description:
            'Start with activity, growth and work that needs attention.',
      ),
      TourStep(
        id: 'workspace_users',
        route: '/users',
        targetId: 'users.add',
        title: 'Invite your team',
        description: 'Add people and choose the right access level.',
      ),
      TourStep(
        id: 'workspace_reports',
        route: '/reports',
        targetId: 'reports.export',
        title: 'Share useful reports',
        description: 'Copy report data or generate a shareable PDF.',
        roles: {'admin'},
      ),
      TourStep(
        id: 'workspace_settings',
        route: '/settings',
        targetId: 'settings.permissions',
        title: 'Configure access',
        description: 'Set default permissions for your workspace.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _teal,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return MaterialApp.router(
      title: 'FlowDesk',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: dark ? const Color(0xFF10161D) : _canvas,
        fontFamily: 'Arial',
        textTheme: ThemeData(useMaterial3: true).textTheme.apply(
          bodyColor: dark ? const Color(0xFFF0F4F7) : _ink,
          displayColor: dark ? const Color(0xFFF0F4F7) : _ink,
        ),
      ),
      builder: (context, child) => BlocProvider.value(
        value: demoCubit,
        child: TourOverlayHost(
          controller: tourController,
          child: FlowShell(
            router: router,
            role: role,
            dark: dark,
            onRole: (value) => setState(() {
              role = value;
              tourController.userContext = TourUserContext(
                roles: {value.toLowerCase()},
                permissions: {'analytics.read', 'users.read'},
              );
            }),
            onTheme: () => setState(() => dark = !dark),
            onTour: () {
              final path = router.routeInformationProvider.value.uri.path;
              final tours = tourRegistry.forRoute(path);
              final pageTour = tours
                  .where((tour) => tour.id != 'workspace_path')
                  .firstOrNull;
              if (pageTour != null) tourController.start(pageTour);
            },
            onCrossTour: () => tourController.start(_crossTour),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class FlowShell extends StatefulWidget {
  const FlowShell({
    super.key,
    required this.router,
    required this.role,
    required this.dark,
    required this.onRole,
    required this.onTheme,
    required this.onTour,
    required this.onCrossTour,
    required this.child,
  });
  final GoRouter router;
  final String role;
  final bool dark;
  final ValueChanged<String> onRole;
  final VoidCallback onTheme, onTour, onCrossTour;
  final Widget child;
  @override
  State<FlowShell> createState() => _FlowShellState();
}

class _FlowShellState extends State<FlowShell> {
  bool collapsed = false;
  String query = '';
  final scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxWidth < 1100;
      final path = widget.router.routeInformationProvider.value.uri.path;
      final title =
          _destinations.where((d) => d.path == path).firstOrNull?.title ??
          (path == '/profile' ? 'My profile' : 'Workspace');
      return Scaffold(
        key: scaffoldKey,
        appBar: _Topbar(
          title: title,
          compact: compact,
          role: widget.role,
          onRole: widget.onRole,
          onTheme: widget.onTheme,
          onTour: widget.onTour,
          onCrossTour: widget.onCrossTour,
          onMenu: () => scaffoldKey.currentState?.openDrawer(),
          onSearch: (value) => setState(() => query = value),
        ),
        drawer: compact
            ? Drawer(
                child: _Sidebar(
                  path: path,
                  collapsed: false,
                  onNavigate: (p) {
                    Navigator.pop(context);
                    context.go(p);
                  },
                ),
              )
            : null,
        body: Row(
          children: [
            if (!compact)
              _Sidebar(
                path: path,
                collapsed: collapsed,
                onCollapse: () => setState(() => collapsed = !collapsed),
                onNavigate: context.go,
              ),
            Expanded(child: widget.child),
          ],
        ),
      );
    },
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.path,
    required this.collapsed,
    required this.onNavigate,
    this.onCollapse,
  });
  final String path;
  final bool collapsed;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onCollapse;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: collapsed ? 78 : 248,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        right: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2E3B48)
              : _line,
        ),
      ),
    ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 18 : 22,
              vertical: 22,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'FlowDesk',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!collapsed)
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 12, 16, 8),
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  fontSize: 10,
                  color: _muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          for (final d in _destinations)
            _NavItem(
              destination: d,
              selected: path == d.path,
              collapsed: collapsed,
              onTap: () => onNavigate(d.path),
            ),
          const Spacer(),
          if (!collapsed)
            Padding(padding: const EdgeInsets.all(14), child: _UpgradeCard()),
          if (onCollapse != null)
            IconButton(
              tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
              onPressed: onCollapse,
              icon: Icon(
                collapsed
                    ? Icons.keyboard_double_arrow_right
                    : Icons.keyboard_double_arrow_left,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });
  final _Destination destination;
  final bool selected, collapsed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(collapsed ? 13 : 14, 3, 14, 3),
    child: Tooltip(
      message: collapsed ? destination.title : '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 14 : 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE7F4F0) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(
                destination.icon,
                size: 19,
                color: selected ? _teal : _muted,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.title,
                    style: TextStyle(
                      color: selected ? _teal : const Color(0xFF4C5967),
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (destination.title == 'Messages') const _Badge('3'),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _Topbar extends StatelessWidget implements PreferredSizeWidget {
  const _Topbar({
    required this.title,
    required this.compact,
    required this.role,
    required this.onRole,
    required this.onTheme,
    required this.onTour,
    required this.onCrossTour,
    required this.onMenu,
    required this.onSearch,
  });
  final String title, role;
  final bool compact;
  final ValueChanged<String> onRole;
  final VoidCallback onTheme, onTour, onCrossTour, onMenu;
  final ValueChanged<String> onSearch;
  @override
  Size get preferredSize => const Size.fromHeight(69);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 68,
    automaticallyImplyLeading: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    leading: compact
        ? IconButton(
            tooltip: 'Open navigation',
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded),
          )
        : null,
    leadingWidth: 52,
    titleSpacing: compact ? 4 : 28,
    title: Text(
      compact ? 'FlowDesk' : title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: compact ? 17 : 19,
        letterSpacing: -.25,
      ),
    ),
    actions: [
      if (!compact)
        SizedBox(
          width: 220,
          height: 40,
          child: TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search anything',
              prefixIcon: const Icon(Icons.search, size: 19),
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF202A34)
                  : const Color(0xFFF3F6F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      const SizedBox(width: 8),
      PopupMenuButton<String>(
        tooltip: 'Help and tours',
        onSelected: (value) => value == 'workspace' ? onCrossTour() : onTour(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'page', child: Text('Tour this page')),
          PopupMenuItem(value: 'workspace', child: Text('Workspace tour')),
        ],
        icon: const Icon(Icons.help_outline_rounded),
      ),
      IconButton(
        tooltip: 'Toggle theme',
        onPressed: onTheme,
        icon: Icon(
          Theme.of(context).brightness == Brightness.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
        ),
      ),
      IconButton(
        tooltip: 'Notifications',
        onPressed: () => context.go('/notifications'),
        icon: BlocBuilder<FlowDeskCubit, DemoState>(
          builder: (context, state) => Badge(
            isLabelVisible: state.unreadCount > 0,
            label: Text('${state.unreadCount}'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ),
      const SizedBox(width: 8),
      PopupMenuButton<String>(
        tooltip: 'Account menu',
        onSelected: (value) {
          if (value == 'profile') context.go('/profile');
          if (value == 'role') onRole(role == 'Admin' ? 'Member' : 'Admin');
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'profile', child: Text('My profile')),
          PopupMenuItem(value: 'role', child: Text('Switch role ($role)')),
          const PopupMenuItem(value: 'logout', child: Text('Sign out')),
        ],
        child: Padding(
          padding: EdgeInsets.only(right: compact ? 10 : 22, left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFDDEFEA),
                child: Text(
                  'JD',
                  style: TextStyle(
                    fontSize: 11,
                    color: _teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 9),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jordan Davis',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      role,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
                const Icon(Icons.keyboard_arrow_down, size: 18, color: _muted),
              ],
            ],
          ),
        ),
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2E3B48)
            : _line,
      ),
    ),
  );
}

class FlowPage extends StatelessWidget {
  const FlowPage({
    super.key,
    required this.title,
    required this.registry,
    this.detail,
  });
  final String title;
  final TourTargetRegistry registry;
  final String? detail;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final pad = box.maxWidth < 700 ? 18.0 : 30.0;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Breadcrumb(title: title),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: const TextStyle(color: _muted, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 29,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (title == 'Dashboard')
                      OutlinedButton.icon(
                        onPressed: () => _pickDateRange(context),
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: const Text('Last 30 days'),
                      ),
                    if (title == 'Users' ||
                        title == 'Alumni' ||
                        title == 'Events') ...[
                      if (box.maxWidth > 560) const SizedBox(width: 10),
                      TourTarget(
                        id: title == 'Users'
                            ? 'users.add'
                            : title == 'Events'
                            ? 'events.create'
                            : 'alumni.add',
                        registry: registry,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (title == 'Users') {
                              _editUser(context);
                            } else if (title == 'Events') {
                              _showEventDialog(context);
                            } else {
                              _showAction(
                                context,
                                'Alumni profile form opened',
                              );
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add new'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                if (detail != null) _Card(child: Text(detail!)),
                switch (title) {
                  'Dashboard' => _Dashboard(registry: registry),
                  'Users' => _Users(registry: registry),
                  'Alumni' => _Alumni(registry: registry),
                  'Messages' => _Messages(registry: registry),
                  'Events' => _Events(registry: registry),
                  'Reports' => _Reports(registry: registry),
                  'Notifications' => _Notifications(registry: registry),
                  'Settings' => _Settings(registry: registry),
                  'My profile' => _Profile(registry: registry),
                  _ => const _Card(
                    child: Text(
                      'Choose a section from the navigation to get started.',
                    ),
                  ),
                },
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12
      ? 'Good morning, Jordan'
      : h < 17
      ? 'Good afternoon, Jordan'
      : 'Good evening, Jordan';
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text('Workspace', style: TextStyle(color: _muted, fontSize: 12)),
      const Icon(Icons.chevron_right, size: 15, color: _muted),
      Text(
        title,
        style: const TextStyle(
          color: _ink,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.registry});
  final TourTargetRegistry registry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TourTarget(
        id: 'dashboard.metrics',
        registry: registry,
        child: LayoutBuilder(
          builder: (context, c) {
            final n = c.maxWidth > 1050
                ? 4
                : c.maxWidth > 620
                ? 2
                : 1;
            return _Grid(
              count: n,
              children: const [
                _MetricCard(
                  'Total users',
                  '24,892',
                  '+12.8%',
                  Icons.people_alt_outlined,
                  Color(0xFFE8F4F1),
                  true,
                ),
                _MetricCard(
                  'Active users',
                  '18,420',
                  '+8.2%',
                  Icons.bolt_outlined,
                  Color(0xFFFFF3E5),
                  true,
                ),
                _MetricCard(
                  'Revenue',
                  '\$84,254',
                  '+16.4%',
                  Icons.attach_money_rounded,
                  Color(0xFFEAF0FF),
                  true,
                ),
                _MetricCard(
                  'Pending tasks',
                  '1,284',
                  '-2.4%',
                  Icons.checklist_rounded,
                  Color(0xFFF4ECFF),
                  false,
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, c) => Flex(
          direction: c.maxWidth > 900 ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExpandedIfWide(
              wide: c.maxWidth > 900,
              child: TourTarget(
                id: 'dashboard.revenue',
                registry: registry,
                child: const _RevenueCard(),
              ),
            ),
            if (c.maxWidth > 900) const SizedBox(width: 18, height: 18),
            ExpandedIfWide(wide: c.maxWidth > 900, child: const _SourceCard()),
          ],
        ),
      ),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, c) => Flex(
          direction: c.maxWidth > 900 ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExpandedIfWide(
              wide: c.maxWidth > 900,
              child: TourTarget(
                id: 'dashboard.activity',
                registry: registry,
                child: const _ActivityCard(),
              ),
            ),
            if (c.maxWidth > 900) const SizedBox(width: 18, height: 18),
            ExpandedIfWide(
              wide: c.maxWidth > 900,
              child: const _NewMembersCard(),
            ),
          ],
        ),
      ),
    ],
  );
}

class ExpandedIfWide extends StatelessWidget {
  const ExpandedIfWide({super.key, required this.wide, required this.child});
  final bool wide;
  final Widget child;
  @override
  Widget build(BuildContext context) => wide
      ? Expanded(child: child)
      : SizedBox(width: double.infinity, child: child);
}

class _Grid extends StatelessWidget {
  const _Grid({required this.count, required this.children});
  final int count;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final gap = count == 1 ? 12.0 : 16.0;
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - gap * (count - 1)) / count;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children.map((e) => SizedBox(width: w, child: e)).toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
    this.title,
    this.value,
    this.delta,
    this.icon,
    this.tint,
    this.positive,
  );
  final String title, value, delta;
  final IconData icon;
  final Color tint;
  final bool positive;
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: _teal, size: 20),
            ),
            const Spacer(),
            Icon(
              positive ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: positive
                  ? const Color(0xFF17845B)
                  : const Color(0xFFC33D4B),
            ),
            Text(
              delta,
              style: TextStyle(
                color: positive
                    ? const Color(0xFF17845B)
                    : const Color(0xFFC33D4B),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 19),
        Text(
          value,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    ),
  );
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard();
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: _CardHeading(
                'Revenue overview',
                'Revenue performance over time',
              ),
            ),
            const _Pill('Monthly', icon: Icons.keyboard_arrow_down),
          ],
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            Text(
              '\$48,294',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            SizedBox(width: 10),
            _Tag('+14.6%'),
          ],
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 205, child: _LineChart()),
        const SizedBox(height: 8),
        const _Legend(),
      ],
    ),
  );
}

class _LineChart extends StatelessWidget {
  const _LineChart();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ChartPainter(), child: const SizedBox.expand());
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final grid = Paint()
      ..color = _line
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = 18 + i * (s.height - 42) / 3;
      canvas.drawLine(Offset(0, y), Offset(s.width, y), grid);
    }
    final pts = [.82, .72, .77, .5, .61, .39, .5, .28, .4, .16, .22, .08];
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final p = Offset(
        i * s.width / (pts.length - 1),
        pts[i] * (s.height - 34) + 8,
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(s.width, s.height - 20)
      ..lineTo(0, s.height - 20)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [_mint.withOpacity(.25), _mint.withOpacity(.01)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & s),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final x in [
      0,
      s.width * .2,
      s.width * .4,
      s.width * .6,
      s.width * .8,
      s.width,
    ]) {
      final tp = TextPainter(
        text: TextSpan(
          text:
              ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'][([
                0,
                s.width * .2,
                s.width * .4,
                s.width * .6,
                s.width * .8,
                s.width,
              ].indexOf(x))],
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, s.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      _Dot(color: _teal),
      SizedBox(width: 6),
      Text('Revenue', style: TextStyle(fontSize: 11, color: _muted)),
      SizedBox(width: 18),
      _Dot(color: _mint),
      SizedBox(width: 6),
      Text('Previous period', style: TextStyle(fontSize: 11, color: _muted)),
    ],
  );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard();
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardHeading('Users by source', 'Acquisition channels'),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _DonutPainter(),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '8,492',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Visitors',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (final x in [
          ('Direct', '42%'),
          ('Social', '28%'),
          ('Referral', '18%'),
          ('Other', '12%'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                _Dot(
                  color: x.$1 == 'Direct'
                      ? _teal
                      : x.$1 == 'Social'
                      ? _mint
                      : x.$1 == 'Referral'
                      ? const Color(0xFF86A4F3)
                      : const Color(0xFFF3BB69),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(x.$1, style: const TextStyle(fontSize: 12)),
                ),
                Text(
                  x.$2,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    var start = -1.57;
    for (final seg in [
      (2.64, _teal),
      (1.76, _mint),
      (1.13, Color(0xFF86A4F3)),
      (.75, Color(0xFFF3BB69)),
    ]) {
      p.color = seg.$2;
      c.drawArc(rect.deflate(10), start, seg.$1, false, p);
      start += seg.$1 + .04;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard();
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardHeading(
          'Recent activity',
          'What is happening in your workspace',
        ),
        const SizedBox(height: 12),
        for (final a in [
          (
            'MC',
            'Maya Chen',
            'created a new event',
            'Product launch webinar',
            '2 min ago',
          ),
          (
            'AR',
            'Alex Rivera',
            'invited a teammate',
            'Sam Wilson',
            '18 min ago',
          ),
          (
            'JP',
            'Jamie Park',
            'published a report',
            'Q3 engagement',
            '1 hour ago',
          ),
          (
            'DK',
            'Drew Kim',
            'updated a profile',
            'Taylor Morgan',
            '3 hours ago',
          ),
        ])
          _ActivityRow(a.$1, a.$2, a.$3, a.$4, a.$5),
      ],
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(
    this.initials,
    this.name,
    this.action,
    this.subject,
    this.when,
  );
  final String initials, name, action, subject, when;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: const Color(0xFFEAF0FF),
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 10,
              color: _teal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: _ink),
              children: [
                TextSpan(
                  text: name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' $action '),
                TextSpan(
                  text: subject,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        Text(when, style: const TextStyle(fontSize: 10, color: _muted)),
      ],
    ),
  );
}

class _NewMembersCard extends StatelessWidget {
  const _NewMembersCard();
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardHeading('New members', 'Recently joined your workspace'),
        const SizedBox(height: 12),
        for (final u in [
          ('Olivia Rhye', 'olivia@acme.co', 'Product designer', 'OR'),
          ('Phoenix Baker', 'phoenix@acme.co', 'Engineering', 'PB'),
          ('Lana Steiner', 'lana@acme.co', 'Marketing', 'LS'),
          ('Demi Wilkinson', 'demi@acme.co', 'Operations', 'DW'),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE7F4F0),
              child: Text(
                u.$4,
                style: const TextStyle(
                  color: _teal,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              u.$1,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${u.$3} · ${u.$2}',
              style: const TextStyle(fontSize: 10, color: _muted),
            ),
            trailing: const Icon(Icons.more_horiz, size: 18),
          ),
      ],
    ),
  );
}

class _Users extends StatelessWidget {
  const _Users({required this.registry});
  final TourTargetRegistry registry;

  @override
  Widget build(BuildContext context) => BlocBuilder<FlowDeskCubit, DemoState>(
    builder: (context, state) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TourTarget(
          id: 'users.search',
          registry: registry,
          child: _Card(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 270,
                  child: _SearchField(
                    hint: 'Search by name or email',
                    onChanged: context.read<FlowDeskCubit>().searchUsers,
                  ),
                ),
                DropdownButton<String>(
                  value: state.roleFilter,
                  items: const ['All roles', 'Admin', 'Editor', 'Viewer']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) context.read<FlowDeskCubit>().filterRole(v);
                  },
                ),
                DropdownButton<String>(
                  value: state.statusFilter,
                  items: const ['All statuses', 'Active', 'Pending', 'Inactive']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null)
                      context.read<FlowDeskCubit>().filterStatus(v);
                  },
                ),
                Text(
                  '${state.visibleUsers.length} users',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _CardHeading(
                      'Team members',
                      'Manage access across your workspace',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _showAction(context, 'Choose a CSV file to import'),
                    icon: const Icon(Icons.upload_file_outlined, size: 17),
                    label: const Text('Import'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TourTarget(
                id: 'users.table',
                registry: registry,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('NAME')),
                      DataColumn(label: Text('ROLE')),
                      DataColumn(label: Text('STATUS')),
                      DataColumn(label: Text('JOINED')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: [
                      for (final u in state.visibleUsers)
                        DataRow(
                          cells: [
                            DataCell(_Person(u.name, u.initials, u.email)),
                            DataCell(Text(u.role)),
                            DataCell(_Status(u.status)),
                            DataCell(Text(u.joined)),
                            DataCell(
                              PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'Edit') {
                                    await _editUser(context, existing: u);
                                  }
                                  if (action == 'View') {
                                    showDialog<void>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text(u.name),
                                        content: Text(
                                          '${u.email}\n${u.role} · ${u.status}\nJoined ${u.joined}',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  if (action == 'Delete' &&
                                      await _confirm(
                                        context,
                                        'Delete ${u.name}?',
                                        'This demo user will be removed from the list.',
                                      )) {
                                    if (context.mounted)
                                      context.read<FlowDeskCubit>().deleteUser(
                                        u.email,
                                      );
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'View',
                                    child: Text('View details'),
                                  ),
                                  PopupMenuItem(
                                    value: 'Edit',
                                    child: Text('Edit user'),
                                  ),
                                  PopupMenuItem(
                                    value: 'Delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                                child: const Icon(Icons.more_horiz),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              if (state.visibleUsers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No users match these filters.'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'Showing ${state.visibleUsers.length} matching users',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: state.visibleUsers.isEmpty
                  ? null
                  : () =>
                        _showAction(context, 'You are viewing the first page'),
              child: const Text('Previous'),
            ),
            const SizedBox(width: 8),
            const FilledButton(onPressed: null, child: Text('1')),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () =>
                  _showAction(context, 'All demo records fit on this page'),
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Person extends StatelessWidget {
  const _Person(this.name, this.initials, this.email);
  final String name, initials, email;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 200,
    child: Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFE7F4F0),
          child: Text(
            initials,
            style: const TextStyle(
              color: _teal,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            Text(email, style: const TextStyle(fontSize: 10, color: _muted)),
          ],
        ),
      ],
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: value == 'Active'
          ? const Color(0xFFE7F4EF)
          : value == 'Pending'
          ? const Color(0xFFFFF3E5)
          : const Color(0xFFF0F2F5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      value,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: value == 'Active'
            ? const Color(0xFF17845B)
            : value == 'Pending'
            ? const Color(0xFFB96B12)
            : _muted,
      ),
    ),
  );
}

class _Alumni extends StatelessWidget {
  const _Alumni({required this.registry});
  final TourTargetRegistry registry;
  static const people = [
    ('Sofia Davis', 'Class of 2021', 'Design · San Francisco', 'SD'),
    ('Ethan Miller', 'Class of 2019', 'Engineering · New York', 'EM'),
    ('Ava Johnson', 'Class of 2022', 'Marketing · Austin', 'AJ'),
    ('Liam Wilson', 'Class of 2018', 'Finance · Seattle', 'LW'),
    ('Mia Anderson', 'Class of 2020', 'Product · Chicago', 'MA'),
    ('Noah Taylor', 'Class of 2017', 'Research · Boston', 'NT'),
  ];
  @override
  Widget build(BuildContext context) => Column(
    children: [
      TourTarget(
        id: 'alumni.filters',
        registry: registry,
        child: _Card(
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SizedBox(
                width: 280,
                child: _SearchField(
                  hint: 'Search alumni by name, role, or company',
                ),
              ),
              const _Pill('Department', icon: Icons.keyboard_arrow_down),
              const _Pill('Class year', icon: Icons.keyboard_arrow_down),
              const _Pill('Location', icon: Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      TourTarget(
        id: 'alumni.directory',
        registry: registry,
        child: LayoutBuilder(
          builder: (context, c) => _Grid(
            count: c.maxWidth > 900
                ? 3
                : c.maxWidth > 600
                ? 2
                : 1,
            children: [
              for (final person in people)
                if (person.$1 == 'Sofia Davis')
                  TourTarget(
                    id: 'alumni.profile',
                    registry: registry,
                    child: _AlumniCard(person: person),
                  )
                else
                  _AlumniCard(person: person),
            ],
          ),
        ),
      ),
    ],
  );
}

class _AlumniCard extends StatelessWidget {
  const _AlumniCard({required this.person});
  final (String, String, String, String) person;
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE7F4F0),
              child: Text(
                person.$4,
                style: const TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showAction(context, 'Contact ${person.$1}'),
              icon: const Icon(Icons.mail_outline, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          person.$1,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          person.$2,
          style: const TextStyle(
            color: _teal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(person.$3, style: const TextStyle(color: _muted, fontSize: 11)),
        const Divider(height: 24),
        const Row(
          children: [
            Icon(Icons.work_outline, size: 16, color: _muted),
            SizedBox(width: 7),
            Text(
              'View profile',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Spacer(),
            Icon(Icons.arrow_forward, size: 15, color: _teal),
          ],
        ),
      ],
    ),
  );
}

class _Messages extends StatefulWidget {
  const _Messages({required this.registry});
  final TourTargetRegistry registry;
  @override
  State<_Messages> createState() => _MessagesState();
}

class _MessagesState extends State<_Messages> {
  final composer = TextEditingController();
  void send() {
    final text = composer.text.trim();
    if (text.isEmpty) return;
    context.read<FlowDeskCubit>().sendMessage(text);
    composer.clear();
  }

  @override
  void dispose() {
    composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Card(
    padding: EdgeInsets.zero,
    child: SizedBox(
      height: 560,
      child: LayoutBuilder(
        builder: (context, c) => Row(
          children: [
            TourTarget(
              id: 'messages.conversations',
              registry: widget.registry,
              child: SizedBox(
                width: c.maxWidth > 700 ? 280 : 95,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Messages',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(Icons.edit_square, size: 18, color: _teal),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: _SearchField(hint: 'Search chats'),
                    ),
                    const SizedBox(height: 10),
                    for (final x in [
                      (
                        'Maya Chen',
                        'Hey! Did you get a chance to review the brief?',
                        '10:42',
                        'MC',
                      ),
                      (
                        'Alex Rivera',
                        'The dashboard looks great',
                        '09:18',
                        'AR',
                      ),
                      (
                        'Jamie Park',
                        'You: Thanks, will do!',
                        'Yesterday',
                        'JP',
                      ),
                      (
                        'Design team',
                        'Olivia: New files are ready',
                        'Mon',
                        'DT',
                      ),
                    ])
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE7F4F0),
                          child: Text(
                            x.$4,
                            style: const TextStyle(color: _teal, fontSize: 10),
                          ),
                        ),
                        title: Text(
                          x.$1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: c.maxWidth > 700
                            ? Text(
                                x.$2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _muted,
                                ),
                              )
                            : null,
                        trailing: c.maxWidth > 700
                            ? Text(
                                x.$3,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: _muted,
                                ),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  TourTarget(
                    id: 'messages.details',
                    registry: widget.registry,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFE7F4F0),
                            child: Text(
                              'MC',
                              style: TextStyle(color: _teal, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Maya Chen',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Active now',
                                  style: TextStyle(
                                    color: Color(0xFF17845B),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showAction(
                              context,
                              'Conversation options opened',
                            ),
                            icon: const Icon(Icons.more_horiz),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const _Bubble(
                          'Hi Jordan! We are finalizing the product launch event. Can you take a look at the schedule?',
                          false,
                          '10:35 AM',
                        ),
                        const _Bubble(
                          'Absolutely. I will review the speakers and send you notes this afternoon.',
                          true,
                          '10:38 AM',
                        ),
                        const _Bubble(
                          'Perfect, thank you! I have added the latest draft to the shared folder.',
                          false,
                          '10:42 AM',
                        ),
                        BlocBuilder<FlowDeskCubit, DemoState>(
                          builder: (context, state) => Column(
                            children: [
                              for (final message in state.messages)
                                _Bubble(message, true, 'Now'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TourTarget(
                    id: 'messages.composer',
                    registry: widget.registry,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SearchField(
                              hint: 'Write a message...',
                              controller: composer,
                              onSubmitted: (_) => send(),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showAction(
                              context,
                              'Attachment picker is ready',
                            ),
                            icon: const Icon(Icons.attach_file),
                          ),
                          IconButton(
                            onPressed: send,
                            icon: const Icon(Icons.send_rounded, color: _teal),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text, this.mine, this.time);
  final String text, time;
  final bool mine;
  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFFE7F4F0) : _canvas,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(text, style: const TextStyle(fontSize: 12, height: 1.5)),
          const SizedBox(height: 6),
          Text(time, style: const TextStyle(fontSize: 9, color: _muted)),
        ],
      ),
    ),
  );
}

class _Events extends StatelessWidget {
  const _Events({required this.registry});
  final TourTargetRegistry registry;
  static const samples = [
    (
      'Product Design Summit',
      'Oct 28, 2026',
      '09:00 AM · Virtual',
      '120 attendees',
      Color(0xFFEAF0FF),
    ),
    (
      'Community Meetup',
      'Nov 04, 2026',
      '06:30 PM · New York',
      '64 attendees',
      Color(0xFFE7F4F0),
    ),
    (
      'Annual Alumni Gala',
      'Nov 18, 2026',
      '07:00 PM · Main Hall',
      '240 attendees',
      Color(0xFFFFF3E5),
    ),
    (
      'Q4 Planning Workshop',
      'Nov 23, 2026',
      '10:00 AM · Conference room',
      '32 attendees',
      Color(0xFFF4ECFF),
    ),
    (
      'Career Networking',
      'Dec 02, 2026',
      '05:00 PM · Virtual',
      '86 attendees',
      Color(0xFFFFEEF0),
    ),
    (
      'Leadership Forum',
      'Dec 12, 2026',
      '11:30 AM · West Hall',
      '48 attendees',
      Color(0xFFE8F4F1),
    ),
  ];
  @override
  Widget build(BuildContext context) => Column(
    children: [
      TourTarget(
        id: 'events.filters',
        registry: registry,
        child: _Card(
          child: Row(
            children: [
              const Expanded(child: _SearchField(hint: 'Search events')),
              const SizedBox(width: 10),
              _Pill('Upcoming', icon: Icons.keyboard_arrow_down),
              const SizedBox(width: 10),
              TourTarget(
                id: 'events.view_switcher',
                registry: registry,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Grid view',
                      onPressed: () =>
                          _showAction(context, 'Grid view selected'),
                      icon: const Icon(Icons.grid_view_rounded, color: _teal),
                    ),
                    IconButton(
                      tooltip: 'Calendar view',
                      onPressed: () =>
                          _showAction(context, 'Calendar view selected'),
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, c) => _Grid(
          count: c.maxWidth > 900
              ? 3
              : c.maxWidth > 600
              ? 2
              : 1,
          children: [
            for (final e in samples)
              _Card(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: e.$5,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.event_available_outlined,
                          size: 42,
                          color: _teal.withOpacity(.7),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Tag(e.$2),
                          const SizedBox(height: 9),
                          Text(
                            e.$1,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.$3,
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                          const Divider(height: 22),
                          Row(
                            children: [
                              const Icon(
                                Icons.people_outline,
                                size: 16,
                                color: _muted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                e.$4,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _muted,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _showAction(
                                  context,
                                  '${e.$1}: details opened',
                                ),
                                child: const Text('Details'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            BlocBuilder<FlowDeskCubit, DemoState>(
              builder: (context, state) => Column(
                children: [
                  for (final title in state.events)
                    _Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.event_available,
                          color: _teal,
                        ),
                        title: Text(title),
                        subtitle: const Text('Scheduled today · Workspace'),
                        trailing: IconButton(
                          onPressed: () =>
                              _showAction(context, '$title event options'),
                          icon: const Icon(Icons.more_horiz),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Reports extends StatelessWidget {
  const _Reports({required this.registry});
  final TourTargetRegistry registry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      TourTarget(
        id: 'reports.report_filters',
        registry: registry,
        child: _Card(
          child: Row(
            children: [
              const Expanded(
                child: _CardHeading(
                  'Report filters',
                  'Customize your reporting period',
                ),
              ),
              const _Pill('Last 90 days', icon: Icons.calendar_today_outlined),
              const SizedBox(width: 8),
              const _Pill('All departments', icon: Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, c) => _Grid(
          count: c.maxWidth > 900
              ? 3
              : c.maxWidth > 600
              ? 2
              : 1,
          children: const [
            _MetricCard(
              'New users',
              '3,842',
              '+18.2%',
              Icons.person_add_alt_1_outlined,
              Color(0xFFE8F4F1),
              true,
            ),
            _MetricCard(
              'Engagement',
              '68.4%',
              '+4.6%',
              Icons.insights_outlined,
              Color(0xFFEAF0FF),
              true,
            ),
            _MetricCard(
              'Retention',
              '84.2%',
              '+2.1%',
              Icons.repeat_rounded,
              Color(0xFFFFF3E5),
              true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      TourTarget(
        id: 'reports.report_charts',
        registry: registry,
        child: const _RevenueCard(),
      ),
      const SizedBox(height: 16),
      TourTarget(
        id: 'reports.export',
        registry: registry,
        child: _Card(
          child: Row(
            children: [
              const Expanded(
                child: _CardHeading(
                  'Export report',
                  'Download or share this report',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportReport(context),
                icon: const Icon(Icons.download_outlined, size: 17),
                label: const Text('Export CSV'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () =>
                    _showAction(context, 'Report generation started'),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                label: const Text('Generate PDF'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Notifications extends StatelessWidget {
  const _Notifications({required this.registry});
  final TourTargetRegistry registry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      TourTarget(
        id: 'notifications.list',
        registry: registry,
        child: _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _CardHeading(
                      'All notifications',
                      'Stay up to date with your workspace',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      context.read<FlowDeskCubit>().markAllRead();
                      _showAction(context, 'All notifications marked as read');
                    },
                    child: const Text('Mark all as read'),
                  ),
                ],
              ),
              for (final n in [
                (
                  'Maya Chen',
                  'invited you to Product Design Summit',
                  '5 min ago',
                  Icons.event_outlined,
                ),
                (
                  'Your weekly report is ready',
                  'Engagement increased by 12% this week',
                  '1 hour ago',
                  Icons.insert_chart_outlined,
                ),
                (
                  'Alex Rivera',
                  'mentioned you in #general',
                  'Yesterday',
                  Icons.alternate_email,
                ),
                (
                  'New member joined',
                  'Olivia Rhye joined the workspace',
                  '2 days ago',
                  Icons.person_add_alt_1_outlined,
                ),
              ])
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE7F4F0),
                    child: Icon(n.$4, color: _teal, size: 18),
                  ),
                  title: Text(
                    n.$1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(n.$2, style: const TextStyle(fontSize: 11)),
                  trailing: Text(
                    n.$3,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      TourTarget(
        id: 'notifications.preferences',
        registry: registry,
        child: _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardHeading(
                'Notification preferences',
                'Choose the updates you want to receive',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: true,
                onChanged: (_) =>
                    _showAction(context, 'Email preference updated'),
                title: const Text('Email summaries'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: true,
                onChanged: (_) =>
                    _showAction(context, 'Mention alerts updated'),
                title: const Text('Mentions and direct messages'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Settings extends StatefulWidget {
  const _Settings({required this.registry});
  final TourTargetRegistry registry;
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  final Map<String, bool> permissions = {
    'Administrators can manage workspace settings': true,
    'Members can invite teammates': false,
    'Require approval for new integrations': false,
  };
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.maxWidth > 700)
          TourTarget(
            id: 'settings.sections',
            registry: widget.registry,
            child: const SizedBox(
              width: 190,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingLink('General', true),
                  _SettingLink('Account', false),
                  _SettingLink('Appearance', false),
                  _SettingLink('Notifications', false),
                  _SettingLink('Security', false),
                  _SettingLink('Permissions', false),
                ],
              ),
            ),
          ),
        Expanded(
          child: Column(
            children: [
              if (c.maxWidth <= 700)
                TourTarget(
                  id: 'settings.sections',
                  registry: widget.registry,
                  child: _Card(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final section in [
                          'General',
                          'Account',
                          'Appearance',
                          'Notifications',
                          'Security',
                          'Permissions',
                        ])
                          _Tag(section),
                      ],
                    ),
                  ),
                ),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardHeading(
                      'General settings',
                      'Manage your workspace details',
                    ),
                    const SizedBox(height: 18),
                    const _LabeledField(
                      'Workspace name',
                      'Northstar Workspace',
                    ),
                    const SizedBox(height: 14),
                    const _LabeledField(
                      'Workspace URL',
                      'northstar.flowdesk.app',
                    ),
                    const SizedBox(height: 14),
                    const _LabeledField('Timezone', '(UTC-05:00) Eastern Time'),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TourTarget(
                        id: 'settings.save',
                        registry: widget.registry,
                        child: FilledButton(
                          onPressed: () =>
                              _showAction(context, 'Settings saved'),
                          child: const Text('Save changes'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TourTarget(
                id: 'settings.permissions',
                registry: widget.registry,
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CardHeading(
                        'User permissions',
                        'Set default access for your workspace',
                      ),
                      for (final r in [
                        'Administrators can manage workspace settings',
                        'Members can invite teammates',
                        'Require approval for new integrations',
                      ])
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: permissions[r] ?? false,
                          onChanged: (value) =>
                              setState(() => permissions[r] = value),
                          title: Text(r, style: const TextStyle(fontSize: 12)),
                          activeColor: _teal,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingLink extends StatelessWidget {
  const _SettingLink(this.label, this.active);
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    width: 170,
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: active ? const Color(0xFFE7F4F0) : null,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: active ? _teal : _muted,
        fontSize: 12,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
  );
}

class _Profile extends StatefulWidget {
  const _Profile({required this.registry});
  final TourTargetRegistry registry;
  @override
  State<_Profile> createState() => _ProfileState();
}

class _ProfileState extends State<_Profile> {
  final completed = <String>{
    'Confirm your email',
    'Add your job title',
    'Set notification preferences',
  };
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _Card(
        child: Row(
          children: [
            const CircleAvatar(
              radius: 38,
              backgroundColor: Color(0xFFE7F4F0),
              child: Text(
                'JD',
                style: TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jordan Davis',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Product Operations · Admin',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  Text(
                    'jordan.davis@northstar.io',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            TourTarget(
              id: 'profile.edit',
              registry: widget.registry,
              child: OutlinedButton.icon(
                onPressed: () => _showAction(context, 'Profile editing'),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit profile'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, c) => _Grid(
          count: c.maxWidth > 750 ? 2 : 1,
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardHeading(
                    'Personal information',
                    'Your profile details',
                  ),
                  const SizedBox(height: 18),
                  const _LabeledField('Full name', 'Jordan Davis'),
                  const SizedBox(height: 14),
                  const _LabeledField(
                    'Email address',
                    'jordan.davis@northstar.io',
                  ),
                  const SizedBox(height: 14),
                  const _LabeledField('Job title', 'Product Operations'),
                ],
              ),
            ),
            TourTarget(
              id: 'profile.completion',
              registry: widget.registry,
              child: _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardHeading(
                      'Profile completion',
                      'Complete your profile to help teammates',
                    ),
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(
                      value: .75,
                      color: _teal,
                      backgroundColor: _line,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '75% complete',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 14),
                    for (final x in [
                      'Add a profile photo',
                      'Confirm your email',
                      'Add your job title',
                      'Set notification preferences',
                    ])
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: completed.contains(x),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            completed.add(x);
                          } else {
                            completed.remove(x);
                          }
                        }),
                        title: Text(x, style: const TextStyle(fontSize: 11)),
                        activeColor: _teal,
                      ),
                  ],
                ),
              ),
            ),
            TourTarget(
              id: 'profile.security',
              registry: widget.registry,
              child: _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardHeading(
                      'Account security',
                      'Manage your sign-in protection',
                    ),
                    const SizedBox(height: 14),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.lock_outline, color: _teal),
                      title: Text('Password'),
                      subtitle: Text('Last changed 60 days ago'),
                      trailing: Icon(Icons.chevron_right),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          _showAction(context, 'Password update flow opened'),
                      child: const Text('Change password'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2E3B48)
            : _line,
      ),
    ),
    child: child,
  );
}

class _CardHeading extends StatelessWidget {
  const _CardHeading(this.title, this.subtitle);
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(fontSize: 11, color: _muted)),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.icon});
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 11),
    decoration: BoxDecoration(
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null && icon != Icons.keyboard_arrow_down)
          Icon(icon, size: 14, color: _muted),
        if (icon != null && icon != Icons.keyboard_arrow_down)
          const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
        if (icon == Icons.keyboard_arrow_down)
          Icon(icon, size: 16, color: _muted),
      ],
    ),
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.hint,
    this.onChanged,
    this.controller,
    this.onSubmitted,
  });
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 17),
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _line),
        ),
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFE7F4F0),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: _teal,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: _teal,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: TextEditingController(text: value),
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );
}

class _UpgradeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFE7F4F0),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.auto_awesome, color: _teal, size: 18),
        SizedBox(height: 9),
        Text(
          'Unlock more with Pro',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: _ink,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Get advanced analytics and unlimited team members.',
          style: TextStyle(fontSize: 10, height: 1.4, color: _muted),
        ),
        SizedBox(height: 9),
        Text(
          'Explore plans  →',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _teal,
          ),
        ),
      ],
    ),
  );
}

void _showAction(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> _editUser(BuildContext context, {DemoUser? existing}) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: existing?.name ?? '');
  final email = TextEditingController(text: existing?.email ?? '');
  var role = existing?.role ?? 'Editor';
  var status = existing?.status ?? 'Active';
  final result = await showDialog<DemoUser>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Add team member' : 'Edit team member'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const ['Admin', 'Editor', 'Viewer']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => role = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const ['Active', 'Pending', 'Inactive']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => status = v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final names = name.text.trim().split(RegExp(r'\s+'));
                final initials = names
                    .map((n) => n.isEmpty ? '' : n[0])
                    .take(2)
                    .join()
                    .toUpperCase();
                Navigator.pop(
                  dialogContext,
                  DemoUser(
                    name: name.text.trim(),
                    initials: initials,
                    email: email.text.trim(),
                    role: role,
                    status: status,
                    joined: existing?.joined ?? 'Today',
                  ),
                );
              }
            },
            child: Text(existing == null ? 'Add user' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
  if (result != null && context.mounted) {
    context.read<FlowDeskCubit>().saveUser(
      result,
      originalEmail: existing?.email,
    );
    _showAction(context, existing == null ? 'User added' : 'User updated');
  }
}

Future<void> _showEventDialog(BuildContext context) async {
  final name = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Create event'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Event name'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: const Text('Choose an event date'),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final picked = await showDatePicker(
                context: dialogContext,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                initialDate: DateTime.now().add(const Duration(days: 7)),
              );
              if (picked != null && dialogContext.mounted)
                _showAction(
                  dialogContext,
                  'Selected ${picked.month}/${picked.day}/${picked.year}',
                );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, name.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  if (result != null && result.isNotEmpty && context.mounted) {
    context.read<FlowDeskCubit>().addEvent(result);
    _showAction(context, 'Event "$result" created');
  }
}

Future<void> _exportReport(BuildContext context) async {
  const csv =
      'Metric,Value,Change\nNew users,3842,+18.2%\nEngagement,68.4%,+4.6%\nRetention,84.2%,+2.1%\nRevenue,48294,+14.6%';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Report CSV is ready'),
      content: const SizedBox(
        width: 420,
        child: SelectableText(
          csv,
          style: TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(const ClipboardData(text: csv));
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted)
              _showAction(context, 'CSV copied to clipboard');
          },
          icon: const Icon(Icons.content_copy, size: 16),
          label: const Text('Copy CSV'),
        ),
      ],
    ),
  );
}

Future<void> _pickDateRange(BuildContext context) async {
  final now = DateTime.now();
  final range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 3),
    lastDate: DateTime(now.year + 1),
    initialDateRange: DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    ),
  );
  if (range != null && context.mounted)
    _showAction(
      context,
      'Showing ${range.start.month}/${range.start.day} – ${range.end.month}/${range.end.day}',
    );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
