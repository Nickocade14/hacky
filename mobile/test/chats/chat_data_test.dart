import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/fake/fake_world.dart';
import 'package:mobile/chats/chat_data.dart';

import '../support/screen_harness.dart';

void main() {
  test('ConversationsData loads me and my conversations', () async {
    final (:api, store: _) = signedInFakeApi();
    final me = await api.getMe();

    final data = await ConversationsData.load(api, fakeEventSlug);

    expect(data.myUserId, me.profile.userId);
    expect(data.conversations.single.peer!.name, 'Priya Shah');
  });

  test('ChatThreadData loads the conversation and its newest page', () async {
    final (:api, store: _) = signedInFakeApi();
    final id = (await api.listConversations(fakeEventSlug)).single.id;

    final data = await ChatThreadData.load(api, fakeEventSlug, id);

    expect(data.conversation!.id, id);
    expect(data.newest.messages, hasLength(3));
    expect(data.newest.hasMore, isFalse);
  });

  test('ChatThreadData has no conversation when the list lacks it', () {
    expect(ChatThreadData.find(const [], 'x'), isNull);
  });
}
