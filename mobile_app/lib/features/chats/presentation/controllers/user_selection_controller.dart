import '../chat_detail_message_maps.dart';

class UserSelectionController {
  final Map<int, Map<String, dynamic>> _selectedUsersCache = {};
  final Set<int> _selectedUserIds = <int>{};

  Set<int> get selectedUserIds => Set.unmodifiable(_selectedUserIds);
  int get selectedCount => _selectedUserIds.length;
  bool get isEmpty => _selectedUserIds.isEmpty;

  bool contains(int? userId) {
    return userId != null && _selectedUserIds.contains(userId);
  }

  bool toggle(Map<String, dynamic> user) {
    final userId = ChatDetailMessageMaps.intFromDynamic(user['id']);
    if (userId == null) return false;

    if (_selectedUserIds.contains(userId)) {
      _selectedUserIds.remove(userId);
      _selectedUsersCache.remove(userId);
    } else {
      _selectedUserIds.add(userId);
      _selectedUsersCache[userId] = Map<String, dynamic>.from(user);
    }
    return true;
  }

  List<int> toMemberIds() {
    final ids = _selectedUserIds.toList()..sort();
    return ids;
  }

  List<Map<String, dynamic>> visibleUsers({
    required String query,
    required List<Map<String, dynamic>> searchResults,
  }) {
    if (query.trim().isNotEmpty) {
      return searchResults;
    }
    final ids = toMemberIds();
    return ids
        .map((id) => _selectedUsersCache[id])
        .whereType<Map<String, dynamic>>()
        .toList();
  }
}
