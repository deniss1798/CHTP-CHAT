part of 'chat_detail_screen.dart';

mixin _ChatDetailStateHelpers on _ChatDetailScreenStateBase {
  Future<void> _connectSocket();
  Future<void> _drainTextOutbox();

  Future<void> _ensureSocketConnected() async {
    if (_chatSocketService.isConnected) return;
    await _connectSocket();
  }

  Future<void> _sendTypingFalse() async {
    await _ensureSocketConnected();
    if (!mounted || !_chatSocketService.isConnected) return;
    _chatSocketService.sendTyping(false);
  }

  Future<void> _fireTypingBurst() async {
    await _ensureSocketConnected();
    if (!mounted || !_chatSocketService.isConnected) return;
    _chatSocketService.sendTyping(true);
    _localTypingStopTimer?.cancel();
    _localTypingStopTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_sendTypingFalse());
    });
  }

  void _onMessageTextChanged() {
    if (mounted) {
      setState(() {});
    }
    final hasText = _messageController.text.isNotEmpty;
    if (!hasText) {
      _typingDebounce?.cancel();
      _localTypingStopTimer?.cancel();
      unawaited(_sendTypingFalse());
      return;
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 220), () {
      unawaited(_fireTypingBurst());
    });
  }

  int? _privatePeerUserId() {
    if (_isGroupChat) return null;
    if (_currentUserId == null) return null;
    for (final id in _memberNames.keys) {
      if (id != _currentUserId) return id;
    }
    return null;
  }

  String _computeDeliveryForOutgoing(int messageId) {
    if (_isGroupChat) {
      final others =
          _memberNames.keys.where((id) => id != _currentUserId).toList();
      if (others.isEmpty) return 'sent';
      for (final uid in others) {
        final lr = _lastReadByUserId[uid] ?? 0;
        if (lr < messageId) return 'sent';
      }
      return 'read';
    }
    final peer = _privatePeerUserId();
    if (peer == null) return 'sent';
    final lr = _lastReadByUserId[peer] ?? 0;
    return lr >= messageId ? 'read' : 'sent';
  }

  void _applyReadReceiptToMessages(int userId, int lastReadId) {
    _lastReadByUserId[userId] = lastReadId;
    _memberLastSeen[userId] = DateTime.now().toUtc();
    if (!mounted) return;
    setState(() {
      _messages = _messages.map((m) {
        if (!_isMine(m)) return m;
        final mid = ChatDetailMessageMaps.intFromDynamic(m['id']);
        if (mid == null) return m;
        final copy = Map<String, dynamic>.from(m);
        copy['delivery_status'] = _computeDeliveryForOutgoing(mid);
        return copy;
      }).toList();
    });
  }

  void _scrollToMessageById(int messageId) {
    final idx = _messages.indexWhere(
      (m) => ChatDetailMessageMaps.intFromDynamic(m['id']) == messageId,
    );
    if (idx < 0) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0 || _messages.isEmpty) return;
    final progress = idx / _messages.length;
    final target = (progress * max).clamp(0.0, max);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;

    final maxExtent = _scrollController.position.maxScrollExtent;
    final offset = maxExtent.clamp(0.0, double.infinity);

    if (jump) {
      _scrollController.jumpTo(offset);
      return;
    }

    final quickScroll = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    _scrollController.animateTo(
      offset,
      duration: quickScroll
          ? const Duration(milliseconds: 120)
          : const Duration(milliseconds: 250),
      curve: quickScroll ? Curves.easeOutCubic : Curves.easeOut,
    );
  }

  bool _isMine(Map<String, dynamic> message) {
    return _messageActionController.isMine(message, _currentUserId);
  }

  String _senderName(Map<String, dynamic> message) {
    final rawSenderId = message['sender_id'];

    int? senderId;
    if (rawSenderId is int) {
      senderId = rawSenderId;
    } else {
      senderId = int.tryParse(rawSenderId.toString());
    }

    if (senderId == null) return 'User';
    if (senderId == _currentUserId) return 'You';
    return _memberNames[senderId] ?? 'User';
  }

  String _senderNameForUserId(int? userId) {
    if (userId == null) return 'User';
    if (userId == _currentUserId) return 'You';
    return _memberNames[userId] ?? 'User';
  }
}
