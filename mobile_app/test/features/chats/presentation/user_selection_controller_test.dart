import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/chats/presentation/controllers/user_presentation_helpers.dart';
import 'package:mobile_app/features/chats/presentation/controllers/user_selection_controller.dart';
import 'package:mobile_app/features/chats/presentation/widgets/chat_composer_action_sheet.dart';

void main() {
  group('UserSelectionController', () {
    test('toggles users and returns stable member ids', () {
      final controller = UserSelectionController();
      final first = {'id': '3', 'username': 'Alice'};
      final second = {'id': 1, 'username': 'Bob'};

      expect(controller.isEmpty, isTrue);
      expect(controller.toggle(first), isTrue);
      expect(controller.toggle(second), isTrue);

      expect(controller.selectedCount, 2);
      expect(controller.contains(3), isTrue);
      expect(controller.toMemberIds(), [1, 3]);

      expect(controller.toggle(first), isTrue);
      expect(controller.selectedUserIds, {1});
    });

    test('shows search results when query is active and cache otherwise', () {
      final controller = UserSelectionController();
      final selected = {'id': 5, 'username': 'Selected'};
      final searched = {'id': 7, 'username': 'Search'};
      controller.toggle(selected);

      expect(
        controller.visibleUsers(query: '', searchResults: [searched]),
        [selected],
      );
      expect(
        controller.visibleUsers(query: 'se', searchResults: [searched]),
        [searched],
      );
    });
  });

  group('user presentation helpers', () {
    test('normalizes ids, initials and avatar urls', () {
      expect(userIdFromMap({'id': '42'}), 42);
      expect(initialsForTitle('Code Green'), 'CG');
      expect(initialsForTitle('  '), '?');
      expect(
        avatarUrlFromUserMap({'avatar_url': '/avatars/a.png'}),
        endsWith('/avatars/a.png'),
      );
      expect(
        avatarUrlFromUserMap({'avatarUrl': 'https://cdn.test/a.png'}),
        'https://cdn.test/a.png',
      );
    });
  });

  group('composer action enums', () {
    test('keep attachment actions typed instead of stringly-typed', () {
      expect(ChatComposerAttachmentAction.values, hasLength(3));
      expect(ChatComposerDesktopExtraAction.values, hasLength(2));
    });
  });
}
