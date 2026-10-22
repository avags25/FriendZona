import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api_error.dart';
import 'auth_repository.dart';
import 'auth_data.dart';

class FriendProfile {
  const FriendProfile({
    required this.userId,
    required this.displayName,
    required this.friendCode,
  });
  final String userId;
  final String displayName;
  final String friendCode;
  factory FriendProfile.fromJson(Map<String, dynamic> json) => FriendProfile(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    friendCode: json['friendCode'] as String,
  );
}

class FriendRequest {
  const FriendRequest({
    required this.requestId,
    required this.friend,
    required this.status,
  });
  final String requestId;
  final FriendProfile friend;
  final String status;
  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    requestId: json['requestId'] as String,
    friend: FriendProfile.fromJson(json['friend'] as Map<String, dynamic>),
    status: json['status'] as String,
  );
}

class FriendsApi {
  FriendsApi(this.dio);
  final Dio dio;
  Future<List<FriendProfile>> friends() => _guard(
    () async => (await dio.get<List<dynamic>>('/api/v1/friends')).data!
        .map((e) => FriendProfile.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  Future<FriendProfile> lookup(String code) => _guard(
    () async => FriendProfile.fromJson(
      (await dio.get<Map<String, dynamic>>(
        '/api/v1/friends/lookup',
        queryParameters: {'code': code},
      )).data!,
    ),
  );
  Future<FriendRequest> send(String code) => _guard(
    () async => FriendRequest.fromJson(
      (await dio.post<Map<String, dynamic>>(
        '/api/v1/friends/requests',
        data: {'friendCode': code},
      )).data!,
    ),
  );
  Future<List<FriendRequest>> requests(bool incoming) => _guard(
    () async =>
        (await dio.get<List<dynamic>>(
              '/api/v1/friends/requests/${incoming ? 'incoming' : 'outgoing'}',
            )).data!
            .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
            .toList(),
  );
  Future<void> action(String id, String action) => _guard(
    () async =>
        (await dio.post<void>('/api/v1/friends/requests/$id/$action')).data,
  );
  Future<void> cancel(String id) => _guard(
    () async => (await dio.delete<void>('/api/v1/friends/requests/$id')).data,
  );
  Future<void> remove(String id) =>
      _guard(() async => (await dio.delete<void>('/api/v1/friends/$id')).data);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ApiError.fromDio(error);
    }
  }
}

final friendsApiProvider = Provider<FriendsApi>((ref) {
  final authRemote = ref.watch(authRemoteProvider);
  if (authRemote is! DioAuthDataSource) {
    throw StateError('Friends require the shared authenticated API client');
  }
  return FriendsApi(authRemote.dio);
});
final friendsListProvider = FutureProvider(
  (ref) => ref.watch(friendsApiProvider).friends(),
);
final incomingRequestsProvider = FutureProvider(
  (ref) => ref.watch(friendsApiProvider).requests(true),
);
final outgoingRequestsProvider = FutureProvider(
  (ref) => ref.watch(friendsApiProvider).requests(false),
);

void invalidateFriendLists(WidgetRef ref) {
  ref.invalidate(friendsListProvider);
  ref.invalidate(incomingRequestsProvider);
  ref.invalidate(outgoingRequestsProvider);
}

class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(friendsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Друзья'),
        actions: [
          IconButton(
            onPressed: () => context.push('/friends/requests'),
            icon: const Icon(Icons.inbox_outlined),
            tooltip: 'Заявки',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/friends/add'),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Добавить'),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(_error(e))),
        data: (friends) => friends.isEmpty
            ? const Center(
                child: Text('Пока нет друзей. Добавьте по коду Social World.'),
              )
            : ListView(
                children: friends
                    .map(
                      (f) => ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(f.displayName),
                        subtitle: Text(f.friendCode),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove_outlined),
                          tooltip: 'Удалить из друзей',
                          onPressed: () async {
                            await ref.read(friendsApiProvider).remove(f.userId);
                            invalidateFriendLists(ref);
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}

class AddFriendPage extends ConsumerStatefulWidget {
  const AddFriendPage({super.key});
  @override
  ConsumerState<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends ConsumerState<AddFriendPage> {
  final _code = TextEditingController();
  FriendProfile? _found;
  bool _busy = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    setState(() {
      _busy = true;
      _found = null;
    });
    try {
      _found = await ref.read(friendsApiProvider).lookup(_code.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await ref.read(friendsApiProvider).send(_code.text.trim());
      invalidateFriendLists(ref);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Заявка отправлена')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить друга')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Ваш код друга',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(user?.friendCode ?? ''),
            trailing: IconButton(
              tooltip: 'Скопировать код',
              icon: const Icon(Icons.copy),
              onPressed: user == null
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: user.friendCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Код скопирован')),
                      );
                    },
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Код друга',
              hintText: 'SW-XXXXXXXXXX',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _lookup,
            child: Text(_busy ? 'Поиск…' : 'Найти'),
          ),
          if (_found case final friend?) ...[
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(friend.displayName),
                subtitle: Text(friend.friendCode),
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: const Text('Отправить заявку'),
            ),
          ],
        ],
      ),
    );
  }
}

class FriendRequestsPage extends ConsumerWidget {
  const FriendRequestsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Заявки в друзья'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Входящие'),
            Tab(text: 'Исходящие'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          _RequestsList(incoming: true),
          _RequestsList(incoming: false),
        ],
      ),
    ),
  );
}

class _RequestsList extends ConsumerWidget {
  const _RequestsList({required this.incoming});
  final bool incoming;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      incoming ? incomingRequestsProvider : outgoingRequestsProvider,
    );
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(_error(e))),
      data: (items) => items.isEmpty
          ? const Center(child: Text('Заявок пока нет'))
          : ListView(
              children: items
                  .map(
                    (item) => ListTile(
                      title: Text(item.friend.displayName),
                      subtitle: Text(item.friend.friendCode),
                      trailing: incoming
                          ? Wrap(
                              children: [
                                IconButton(
                                  tooltip: 'Принять',
                                  icon: const Icon(Icons.check),
                                  onPressed: () async {
                                    await ref
                                        .read(friendsApiProvider)
                                        .action(item.requestId, 'accept');
                                    invalidateFriendLists(ref);
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Отклонить',
                                  icon: const Icon(Icons.close),
                                  onPressed: () async {
                                    await ref
                                        .read(friendsApiProvider)
                                        .action(item.requestId, 'decline');
                                    invalidateFriendLists(ref);
                                  },
                                ),
                              ],
                            )
                          : IconButton(
                              tooltip: 'Отменить заявку',
                              icon: const Icon(Icons.cancel_outlined),
                              onPressed: () async {
                                await ref
                                    .read(friendsApiProvider)
                                    .cancel(item.requestId);
                                invalidateFriendLists(ref);
                              },
                            ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

String _error(Object error) =>
    error is ApiError ? error.message : 'Не удалось выполнить запрос';
