import 'package:flutter_test/flutter_test.dart';
import 'package:social_world_mobile/src/friends.dart';
import 'package:social_world_mobile/src/models.dart';

void main() {
  test(
    'self profile preserves the permanent friend code through JSON and name edits',
    () {
      final user = PublicUser.fromJson({
        'id': 'c80cb3c8-3442-493f-b533-3fc159850e11',
        'email': 'person@example.test',
        'displayName': 'Alex',
        'friendCode': 'SW-ABC234DEFG',
        'createdAt': '2026-10-22T12:00:00Z',
      });
      expect(PublicUser.fromJson(user.toJson()).friendCode, user.friendCode);
      expect(user.withDisplayName('New name').friendCode, user.friendCode);
    },
  );

  test('friend request maps only the public friend fields', () {
    final request = FriendRequest.fromJson({
      'requestId': '3e4af5fc-fec5-4bfd-8aa6-9e8d0a1899fb',
      'friend': {
        'userId': 'c80cb3c8-3442-493f-b533-3fc159850e11',
        'displayName': 'Alex',
        'friendCode': 'SW-ABC234DEFG',
      },
      'status': 'PENDING',
    });
    expect(request.status, 'PENDING');
    expect(request.friend.displayName, 'Alex');
  });
}
