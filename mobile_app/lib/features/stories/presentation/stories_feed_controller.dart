import 'package:flutter/foundation.dart';

import '../../../../core/notifiers/chats_list_refresh_notifier.dart';
import '../data/stories_service.dart';

class StoryFeedEntryVm {
  StoryFeedEntryVm({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.isSelf,
    required this.hasUnseen,
    required this.storyCount,
  });

  final int userId;
  final String username;
  final String? avatarUrl;
  final bool isSelf;
  final bool hasUnseen;
  final int storyCount;
}

class StoriesFeedController extends ChangeNotifier {
  StoriesFeedController({StoriesService? service})
      : _service = service ?? StoriesService() {
    chatsListRefreshNotifier.addListener(_onChatsRefreshSignal);
  }

  final StoriesService _service;

  bool loading = false;
  String? error;
  List<StoryFeedEntryVm> entries = [];

  void _onChatsRefreshSignal() {
    load(silent: true);
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final data = await _service.getFeed();
      final raw = data['entries'];
      final next = <StoryFeedEntryVm>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final user = m['user'];
          if (user is! Map) continue;
          final um = Map<String, dynamic>.from(user);
          final id = um['id'];
          final uid = id is int ? id : int.tryParse(id.toString());
          if (uid == null) continue;
          next.add(
            StoryFeedEntryVm(
              userId: uid,
              username: (um['username'] ?? '').toString(),
              avatarUrl: um['avatar_url']?.toString(),
              isSelf: m['is_self'] == true,
              hasUnseen: m['has_unseen'] == true,
              storyCount: (m['story_count'] is int)
                  ? m['story_count'] as int
                  : int.tryParse('${m['story_count']}') ?? 0,
            ),
          );
        }
      }
      entries = next;
      error = null;
    } catch (e) {
      if (!silent) {
        error = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    chatsListRefreshNotifier.removeListener(_onChatsRefreshSignal);
    super.dispose();
  }
}
