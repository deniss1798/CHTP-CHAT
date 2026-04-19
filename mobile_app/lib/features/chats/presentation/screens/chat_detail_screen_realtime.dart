part of 'chat_detail_screen.dart';

mixin _ChatDetailRealtimeAndCallsLogic on _ChatDetailScreenStateBase, _ChatDetailStateHelpers {
  Future<void> _connectSocket() async {
    await _socketSubscription?.cancel();

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _chatSocketService.connect(
          chatId: widget.chatId,
          baseHttpUrl: ApiClient.baseUrl,
        );

        _socketSubscription = _chatSocketService.messagesStream.listen((message) {
          _handleSocketEvent(message);
        });
        return;
      } catch (_) {
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    }
  }

  void _handleSocketEvent(Map<String, dynamic> incoming) {
    if (incoming['type'] == 'group_call_invite') {
      _handleGroupCallInvite(incoming);
      return;
    }
    if (incoming['type'] == 'call_e2e_hangup') {
      _handleIncomingCallHangup(incoming);
      return;
    }
    if (incoming['type'] == 'call_e2e_init') {
      _handleIncomingCallSignal(incoming);
      return;
    }
    if (incoming['type'] == 'typing') {
      final uid = ChatDetailMessageMaps.intFromDynamic(incoming['user_id']);
      if (uid == null || uid == _currentUserId) return;
      final typing = incoming['typing'] != false;
      if (!typing) {
        if (_typingUserId == uid) {
          setState(() => _typingUserId = null);
        }

        return;
      }
      setState(() {
        _typingUserId = uid;
        _memberLastSeen[uid] = DateTime.now().toUtc();
      });
      _remoteTypingHideTimer?.cancel();
      _remoteTypingHideTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          if (_typingUserId == uid) {
            _typingUserId = null;
          }
        });
      });
      return;
    }

    if (incoming['type'] == 'read_receipt') {
      final uid = ChatDetailMessageMaps.intFromDynamic(incoming['user_id']);
      final lr = ChatDetailMessageMaps.intFromDynamic(incoming['last_read_message_id']);
      if (uid == null || lr == null) return;
      if (uid == _currentUserId) return;
      _applyReadReceiptToMessages(uid, lr);
      return;
    }

    if (incoming['event'] == ChatWsContract.eventMessageDeleted) {
      final rawId = incoming['id'];
      int? id;
      if (rawId is int) {
        id = rawId;
      } else {
        id = int.tryParse(rawId.toString());
      }

      if (id == null) return;

      if (!mounted) return;

      setState(() {
        _messages.removeWhere((m) => m['id'] == id);
        if (_editingMessage != null && _editingMessage!['id'] == id) {
          _editingMessage = null;
          _messageController.clear();
        }
      });

      return;
    }

    if (incoming['event'] == ChatWsContract.eventMessageUpdated) {
      final msg = incoming['message'];
      if (msg is! Map) return;

      var normalized =
          ChatDetailMessageMaps.normalizeMessageMap(Map<String, dynamic>.from(msg));
      final incomingId = normalized['id'];
      if (_isMine(normalized)) {
        final mid = ChatDetailMessageMaps.intFromDynamic(normalized['id']);
        if (mid != null) {
          normalized = Map<String, dynamic>.from(normalized);
          normalized['delivery_status'] = _computeDeliveryForOutgoing(mid);
        }
      }

      if (!mounted) return;

      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == incomingId);
        if (idx >= 0) {
          _messages[idx] = normalized;
        }
      });

      return;
    }

    if (incoming['type'] == ChatWsContract.payloadTypeNewMessage ||
        incoming.containsKey('message')) {
      _handleNewMessage(incoming);
    }
  }

  void _handleGroupCallInvite(Map<String, dynamic> incoming) {
    if (!_isGroupChat) return;
    final uid = ChatDetailMessageMaps.intFromDynamic(incoming['user_id']);
    if (uid == null || uid == _currentUserId) return;
    final callId = incoming['call_id']?.toString() ?? '';
    if (callId.isEmpty) return;
    if (!VoiceCallRing.tryStart(callId)) return;
    unawaited(_showGroupIncomingCallDialog(incoming));
  }

  Future<void> _showGroupIncomingCallDialog(Map<String, dynamic> init) async {
    final callId = init['call_id']?.toString() ?? '';
    final callerId = ChatDetailMessageMaps.intFromDynamic(init['user_id']);
    if (callerId == null || _currentUserId == null) return;
    final startedBy = ChatDetailMessageMaps.intFromDynamic(init['started_by']) ?? callerId;
    final withVideo = init['video'] == true;
    final name = (_memberNames[callerId] ?? '').trim();
    final visibleTitle = _chatTitle.trim().isNotEmpty ? _chatTitle : widget.title;
    final callerLabel =
        name.isNotEmpty ? name : 'Участник $callerId';


    await IncomingCallRingtone.instance.start();
    if (!mounted) {
      await IncomingCallRingtone.instance.stop();
      return;
    }
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(

          backgroundColor: AppColors.surface,
          title: const Text(
            'Групповой звонок',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            '$callerLabel зовёт в звонок «$visibleTitle»',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                VoiceCallRing.end(callId);
                Navigator.of(ctx).pop();
              },
              child: const Text('Отклонить'),
            ),
            TextButton(
              onPressed: () {
                VoiceCallRing.end(callId);
                Navigator.of(ctx).pop();
                final me = _currentUserId;
                if (me == null) return;
                unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => GroupCallScreen(
                        chatId: widget.chatId,
                        chatTitle: visibleTitle,
                        myUserId: me,
                        callId: callId,
                        startedByUserId: startedBy,
                        memberNames: Map<int, String>.from(_memberNames),
                        memberAvatarUrls: {
                          for (final e in _memberAvatarUrls.entries)
                            e.key: chatDetailNormalizedAvatarUrl(e.value),
                        },
                        existingSocket: _chatSocketService,
                        isHost: false,
                        startWithVideo: withVideo,
                        incomingInvite: init,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Принять'),
            ),
          ],
        ),
      );
    } finally {
      await IncomingCallRingtone.instance.stop();
    }
  }

  void _handleIncomingCallHangup(Map<String, dynamic> incoming) {
    if (_isGroupChat) return;
    final uid = ChatDetailMessageMaps.intFromDynamic(incoming['user_id']);
    if (uid == null || uid == _currentUserId) return;
    final peer = _privatePeerUserId();
    if (peer != null && peer != uid) return;
    final callId = incoming['call_id']?.toString() ?? '';
    if (callId.isEmpty) return;
    VoiceCallRing.dismissIncomingDialog(callId);
  }

  void _handleIncomingCallSignal(Map<String, dynamic> incoming) {
    if (_isGroupChat) return;
    final uid = ChatDetailMessageMaps.intFromDynamic(incoming['user_id']);
    if (uid == null || uid == _currentUserId) return;
    // Пока участники ещё не подгрузились, _privatePeerUserId() == null — не отбрасываем звонок.
    final peer = _privatePeerUserId();
    if (peer != null && peer != uid) return;
    final callId = incoming['call_id']?.toString() ?? '';
    if (callId.isEmpty) return;
    if (!VoiceCallRing.tryStart(callId)) return;

    unawaited(_showIncomingCallDialog(incoming));
  }

  Future<void> _showIncomingCallDialog(Map<String, dynamic> init) async {
    final callId = init['call_id']?.toString() ?? '';
    final visibleTitle =
        _chatTitle.trim().isNotEmpty ? _chatTitle : widget.title;
    await IncomingCallRingtone.instance.start();
    if (!mounted) {
      await IncomingCallRingtone.instance.stop();
      return;

    }
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          VoiceCallRing.registerIncomingDismiss(callId, () {
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          });
          return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Входящий звонок',

            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            '$visibleTitle звонит вам',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                VoiceCallRing.end(callId);
                _chatSocketService.sendJson({
                  'type': 'call_e2e_hangup',
                  'call_id': callId,
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Отклонить'),
            ),
            TextButton(
              onPressed: () {
                VoiceCallRing.end(callId);
                Navigator.of(ctx).pop();
                final peer = _privatePeerUserId();
                final me = _currentUserId;
                if (peer == null || me == null) return;
                unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => VoiceCallScreen(
                        chatId: widget.chatId,
                        peerTitle: visibleTitle,
                        peerUserId: peer,
                        myUserId: me,
                        existingSocket: _chatSocketService,
                        incomingInit: init,
                        peerAvatarUrl:
                            chatDetailNormalizedAvatarUrl(_memberAvatarUrls[peer]),
                        myAvatarUrl:
                            chatDetailNormalizedAvatarUrl(_memberAvatarUrls[me]),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Принять'),
            ),
          ],
        );
        },
      );
    } finally {
      VoiceCallRing.unregisterIncomingDismiss(callId);
      await IncomingCallRingtone.instance.stop();
    }
  }

  Future<void> _startGroupCall() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Групповые звонки в браузере пока не поддерживаются'),
        ),
      );
      return;
    }
    final me = _currentUserId;
    if (me == null) return;
    await _ensureSocketConnected();
    if (!mounted) return;
    final callId =
        '${DateTime.now().microsecondsSinceEpoch}_gc${widget.chatId}_$me';
    final visibleTitle =
        _chatTitle.trim().isNotEmpty ? _chatTitle : widget.title;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GroupCallScreen(

          chatId: widget.chatId,
          chatTitle: visibleTitle,
          myUserId: me,
          callId: callId,
          startedByUserId: me,
          memberNames: Map<int, String>.from(_memberNames),
          memberAvatarUrls: {
            for (final e in _memberAvatarUrls.entries)
              e.key: chatDetailNormalizedAvatarUrl(e.value),
          },
          existingSocket: _chatSocketService,
          isHost: true,
          startWithVideo: true,
        ),
      ),
    );
  }

  Future<void> _startVoiceCall() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Звонки в браузере не поддерживаются'),
        ),
      );
      return;
    }
    final peer = _privatePeerUserId();
    final me = _currentUserId;
    if (peer == null || me == null) return;
    await _ensureSocketConnected();
    if (!mounted) return;
    final visibleTitle =
        _chatTitle.trim().isNotEmpty ? _chatTitle : widget.title;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VoiceCallScreen(
          chatId: widget.chatId,

          peerTitle: visibleTitle,
          peerUserId: peer,
          myUserId: me,
          existingSocket: _chatSocketService,
          peerAvatarUrl: chatDetailNormalizedAvatarUrl(_memberAvatarUrls[peer]),
          myAvatarUrl: chatDetailNormalizedAvatarUrl(_memberAvatarUrls[me]),
        ),
      ),
    );
  }

  Future<void> _handleNewMessage(Map<String, dynamic> incoming) async {
    final payload = ChatDetailMessageMaps.extractMessagePayload(incoming);
    if (payload == null) return;

    var normalized = ChatDetailMessageMaps.normalizeMessageMap(payload);
    final incomingId = normalized['id'];
    final senderId = ChatDetailMessageMaps.intFromDynamic(normalized['sender_id']);
    if (_isMine(normalized)) {
      final mid = ChatDetailMessageMaps.intFromDynamic(normalized['id']);
      if (mid != null) {
        normalized = Map<String, dynamic>.from(normalized);
        normalized['delivery_status'] = _computeDeliveryForOutgoing(mid);
      }
    }
    final exists = _messages.any((m) => m['id'] == incomingId);

    if (exists) return;
    if (!mounted) return;

    setState(() {
      if (senderId != null && senderId == _typingUserId) {

        _typingUserId = null;
        _remoteTypingHideTimer?.cancel();
      }
      if (senderId != null &&
          senderId != _currentUserId &&
          !_isGroupChat) {
        _memberLastSeen[senderId] = DateTime.now().toUtc();
      }
      _messages.add(normalized);
      _messages.sort((a, b) {
        final am = serverInstantMillis(a['created_at']?.toString());
        final bm = serverInstantMillis(b['created_at']?.toString());
        return (am ?? 0).compareTo(bm ?? 0);
      });
    });

    await _markCurrentChatAsRead();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _markCurrentChatAsRead() async {
    if (_messages.isEmpty) return;

    final lastMessage = _messages.last;
    final lastMessageId = ChatDetailMessageMaps.intFromDynamic(lastMessage['id']);
    if (lastMessageId == null) return;

    try {
      await _messagesService.markChatRead(
        chatId: widget.chatId,
        messageId: lastMessageId,
      );
    } catch (_) {}

    await _localChatStateService.markChatAsRead(
      chatId: widget.chatId,
      lastMessageId: lastMessageId,
    );

    requestChatsListRefresh();
  }
}

