import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_avatar.dart';
import '../../../../core/notifiers/chats_list_refresh_notifier.dart';
import '../../../chats/presentation/controllers/user_presentation_helpers.dart';
import '../../data/stories_service.dart';
import '../screens/story_viewer_screen.dart';
import '../stories_feed_controller.dart';

class StoriesStrip extends StatelessWidget {
  const StoriesStrip({
    super.key,
    required this.entries,
    required this.loading,
    required this.onRefreshFeed,
  });

  final List<StoryFeedEntryVm> entries;
  final bool loading;
  final Future<void> Function() onRefreshFeed;

  Future<void> _openStory(BuildContext context, StoryFeedEntryVm e) async {
    if (e.storyCount == 0 && e.isSelf) {
      await _pickAndUpload(context);
      return;
    }
    if (e.storyCount == 0) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StoryViewerScreen(
          authorId: e.userId,
          initialUsername: e.username,
          initialAvatarUrl: e.avatarUrl,
        ),
      ),
    );
    await onRefreshFeed();
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final picker = ImagePicker();
      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.surfaceElevated,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Фото из галереи'),
                onTap: () => Navigator.pop(ctx, 'g_photo'),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_rounded),
                title: const Text('Видео из галереи'),
                onTap: () => Navigator.pop(ctx, 'g_video'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Камера'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
            ],
          ),
        ),
      );
      if (action == null || !context.mounted) return;

      XFile? file;
      String mediaType = 'image';

      if (action == 'g_photo') {
        file = await picker.pickImage(source: ImageSource.gallery);
      } else if (action == 'g_video') {
        file = await picker.pickVideo(source: ImageSource.gallery);
        mediaType = 'video';
      } else if (action == 'camera') {
        file = await picker.pickImage(source: ImageSource.camera);
      }

      if (file == null || !context.mounted) return;
      final bytes = await file.readAsBytes();
      final fn = file.name.isNotEmpty
          ? file.name
          : (mediaType == 'video' ? 'story.mp4' : 'story.jpg');

      await StoriesService().uploadStory(bytes: bytes, filename: fn, mediaType: mediaType);
      requestChatsListRefresh();
      await onRefreshFeed();
      if (context.mounted) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Сторис опубликована')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            extractFeatureErrorMessage(e, fallback: 'Не удалось опубликовать сторис'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && entries.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final e = entries[i];
          return _StoryBubble(
            entry: e,
            onTap: () => _openStory(context, e),
          );
        },
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.entry,
    required this.onTap,
  });

  final StoryFeedEntryVm entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = entry.hasUnseen && !entry.isSelf
        ? const LinearGradient(
            colors: [Color(0xFFFF9F0A), Color(0xFFFF375F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gradient,
                border: gradient == null
                    ? Border.all(color: Colors.white24, width: 2)
                    : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(
                      title: entry.username,
                      imageUrl: entry.avatarUrl,
                      size: 58,
                      radius: AppRadius.pill,
                    ),
                    if (entry.isSelf)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.accentBright,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 2),
                          ),
                          child: const Icon(Icons.add_rounded, size: 14, color: Colors.black),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.isSelf ? 'История' : entry.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
