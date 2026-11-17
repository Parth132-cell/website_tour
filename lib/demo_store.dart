import 'package:flutter_bloc/flutter_bloc.dart';

class DemoUser {
  const DemoUser({
    required this.name,
    required this.initials,
    required this.email,
    required this.role,
    required this.status,
    required this.joined,
  });
  final String name, initials, email, role, status, joined;
  DemoUser copyWith({
    String? name,
    String? initials,
    String? email,
    String? role,
    String? status,
    String? joined,
  }) => DemoUser(
    name: name ?? this.name,
    initials: initials ?? this.initials,
    email: email ?? this.email,
    role: role ?? this.role,
    status: status ?? this.status,
    joined: joined ?? this.joined,
  );
}

class DemoState {
  const DemoState({
    required this.users,
    this.query = '',
    this.roleFilter = 'All roles',
    this.statusFilter = 'All statuses',
    this.unreadCount = 3,
    this.messages = const [],
    this.events = const [],
  });
  final List<DemoUser> users;
  final String query, roleFilter, statusFilter;
  final int unreadCount;
  final List<String> messages;
  final List<String> events;
  List<DemoUser> get visibleUsers => users.where((u) {
    final q = query.trim().toLowerCase();
    return (q.isEmpty ||
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q)) &&
        (roleFilter == 'All roles' || u.role == roleFilter) &&
        (statusFilter == 'All statuses' || u.status == statusFilter);
  }).toList();
  DemoState copyWith({
    List<DemoUser>? users,
    String? query,
    String? roleFilter,
    String? statusFilter,
    int? unreadCount,
    List<String>? messages,
    List<String>? events,
  }) => DemoState(
    users: users ?? this.users,
    query: query ?? this.query,
    roleFilter: roleFilter ?? this.roleFilter,
    statusFilter: statusFilter ?? this.statusFilter,
    unreadCount: unreadCount ?? this.unreadCount,
    messages: messages ?? this.messages,
    events: events ?? this.events,
  );
}

/// In-memory repository for the interactive demo. Replace with an API-backed repository later.
class DemoUserRepository {
  final List<DemoUser> _users = [
    const DemoUser(
      name: 'Olivia Rhye',
      initials: 'OR',
      email: 'olivia@acme.co',
      role: 'Admin',
      status: 'Active',
      joined: 'Oct 24, 2024',
    ),
    const DemoUser(
      name: 'Phoenix Baker',
      initials: 'PB',
      email: 'phoenix@acme.co',
      role: 'Editor',
      status: 'Active',
      joined: 'Oct 22, 2024',
    ),
    const DemoUser(
      name: 'Lana Steiner',
      initials: 'LS',
      email: 'lana@acme.co',
      role: 'Viewer',
      status: 'Pending',
      joined: 'Oct 18, 2024',
    ),
    const DemoUser(
      name: 'Demi Wilkinson',
      initials: 'DW',
      email: 'demi@acme.co',
      role: 'Editor',
      status: 'Active',
      joined: 'Oct 12, 2024',
    ),
    const DemoUser(
      name: 'Candice Wu',
      initials: 'CW',
      email: 'candice@acme.co',
      role: 'Viewer',
      status: 'Inactive',
      joined: 'Oct 08, 2024',
    ),
    const DemoUser(
      name: 'Natali Craig',
      initials: 'NC',
      email: 'natali@acme.co',
      role: 'Admin',
      status: 'Active',
      joined: 'Oct 02, 2024',
    ),
    const DemoUser(
      name: 'Drew Cano',
      initials: 'DC',
      email: 'drew@acme.co',
      role: 'Editor',
      status: 'Active',
      joined: 'Sep 29, 2024',
    ),
    const DemoUser(
      name: 'Orlando Diggs',
      initials: 'OD',
      email: 'orlando@acme.co',
      role: 'Viewer',
      status: 'Pending',
      joined: 'Sep 26, 2024',
    ),
  ];
  List<DemoUser> get users => List.unmodifiable(_users);
  void save(DemoUser user, {String? originalEmail}) {
    final i = originalEmail == null
        ? -1
        : _users.indexWhere((u) => u.email == originalEmail);
    if (i < 0) {
      _users.insert(0, user);
    } else {
      _users[i] = user;
    }
  }

  void remove(String email) => _users.removeWhere((u) => u.email == email);
}

class FlowDeskCubit extends Cubit<DemoState> {
  FlowDeskCubit({DemoUserRepository? repository})
    : this._(repository ?? DemoUserRepository());
  FlowDeskCubit._(this.repository) : super(DemoState(users: repository.users));
  final DemoUserRepository repository;
  void searchUsers(String value) => emit(state.copyWith(query: value));
  void filterRole(String value) => emit(state.copyWith(roleFilter: value));
  void filterStatus(String value) => emit(state.copyWith(statusFilter: value));
  void saveUser(DemoUser user, {String? originalEmail}) {
    repository.save(user, originalEmail: originalEmail);
    emit(state.copyWith(users: repository.users));
  }

  void deleteUser(String email) {
    repository.remove(email);
    emit(state.copyWith(users: repository.users));
  }

  void markAllRead() => emit(state.copyWith(unreadCount: 0));
  void addEvent(String title) =>
      emit(state.copyWith(events: [title, ...state.events]));
  void sendMessage(String message) {
    final text = message.trim();
    if (text.isNotEmpty)
      emit(state.copyWith(messages: [...state.messages, text]));
  }
}
