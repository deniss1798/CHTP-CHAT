part of 'chat_detail_screen.dart';

mixin _ChatDetailLifecycleLogic on _ChatDetailScreenStateBase, _ChatDetailStateHelpers, _ChatDetailRealtimeAndCallsLogic {
  Future<void> _pickAndUploadChatAvatar() async {
    if (!_isGroupChat || _isUploadingChatAvatar) return;

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (picked == null) return;

    setState(() {
      _isUploadingChatAvatar = true;
    });

    try {
      final updated = await _chatAvatarService.uploadChatAvatar(
        chatId: widget.chatId,
        file: File(picked.path),
      );

      final rawAvatar = (updated['avatar_url'] ?? '').toString().trim();

      if (!mounted) return;

      setState(() {
        _chatAvatarUrl = rawAvatar.isNotEmpty ? rawAvatar : null;
        _isUploadingChatAvatar = false;
      });

      await _loadChatDetails();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аватар группы обновлен'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUploadingChatAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Не удалось обновить аватар группы',
            ),
          ),
        ),
      );
    }
  }


  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _presenceService.ping();
    _presenceTimer = Timer.periodic(const Duration(seconds: 35), (_) async {
      if (!mounted) return;
      await _presenceService.ping();
      try {
        await _loadChatMembers();
        if (mounted) setState(() {});
      } catch (_) {}
    });
  }


  void _startSocketReconnectLoop() {
    _socketReconnectTimer?.cancel();
    _socketReconnectTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      if (!_chatSocketService.isConnected) {
        unawaited(_connectSocket());
      }
    });
  }


  Future<void> _initChat() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final me = await _authService.getMe();
      final userId = me['id'];

      if (userId is int) {
        _currentUserId = userId;
      } else {
        _currentUserId = int.tryParse(userId.toString());
      }

      await _loadChatDetails();

      await _loadChatMembers();

      await _loadMessages();
      await _connectSocket();
      _startSocketReconnectLoop();
      _startPresenceHeartbeat();
      if (mounted && _messageController.text.trim().isNotEmpty) {
        _onMessageTextChanged();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = chatDetailExtractErrorMessage(e, fallback: 'Не удалось открыть чат');
        _isLoading = false;
      });
    }
  }


  Future<void> _loadChatDetails() async {
    final detail = await _chatsService.fetchChatDetail(widget.chatId);
    final title = detail.title.trim();
    final avatarUrl = (detail.avatarUrl ?? '').trim();
    final createdBy = detail.createdBy;

    if (!mounted) return;

    final isGroup = detail.type == 'group';

    setState(() {
      if (title.isNotEmpty) {
        _chatTitle = title;
      }
      _chatAvatarUrl = avatarUrl.isNotEmpty ? avatarUrl : null;
      _groupCreatedBy = isGroup ? createdBy : null;
    });
  }

  Future<void> _loadChatMembers() async {
    final rows = await _chatsService.fetchChatMembers(widget.chatId);
    _memberNames.clear();
    _memberAvatarUrls.clear();
    _memberLastSeen.clear();

    for (final member in rows) {

      if (member.username.isNotEmpty) {
        _memberNames[member.id] = member.username;
      }
      _memberAvatarUrls[member.id] = member.avatarUrl;
      final rawSeen = member.lastSeenAtRaw;
      if (rawSeen != null && rawSeen.isNotEmpty) {
        _memberLastSeen[member.id] = parseServerUtcInstant(rawSeen)?.toLocal();
      } else {
        _memberLastSeen[member.id] = null;
      }
    }
  }

  Future<void> _openAddMemberScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChatMemberAddScreen(
          chatId: widget.chatId,
          existingMemberIds: _memberNames.keys.toSet(),
        ),
      ),
    );

    if (!mounted || result != true) return;

    try {
      await _loadChatMembers();
      await _loadChatDetails();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Участник успешно добавлен'),

        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Не удалось обновить список участников',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showRenameGroupDialog() async {
    final titleForAvatar = _chatTitle.trim().isNotEmpty
        ? _chatTitle.trim()
        : widget.title;
    final t = await showMessengerGroupRenameDialog(
      context: context,
      initialTitle: _chatTitle.trim(),
      groupTitleForInitials: titleForAvatar,
      avatarUrl: _chatAvatarUrl,
    );
    if (t == null || !mounted) return;
    try {
      await _chatsService.updateGroupTitle(chatId: widget.chatId, title: t);
      await _loadChatDetails();
      requestChatsListRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Название обновлено')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatDetailExtractErrorMessage(e, fallback: 'Не удалось сохранить название'),
          ),
        ),
      );
    }
  }

  Future<void> _leaveGroup() async {
    final titleForAvatar = _chatTitle.trim().isNotEmpty
        ? _chatTitle.trim()
        : widget.title;
    final ok = await showMessengerConfirmDialog(
      context: context,
      title: 'Покинуть группу?',
      body: 'Вы больше не будете получать сообщения из этой группы.',
      confirmLabel: 'Покинуть',
      cancelLabel: 'Отмена',
      contextHeader: Center(
        child: ChatDetailSquareAvatar(
          title: titleForAvatar,
          avatarUrl: _chatAvatarUrl,
          size: 52,
          showOnlineDot: false,
        ),
      ),
    );
    if (!ok || !mounted) return;
    try {
      await _chatsService.leaveGroup(chatId: widget.chatId);
      requestChatsListRefresh();
      if (!mounted) return;
      if (widget.onBackOverride != null) {
        widget.onBackOverride!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatDetailExtractErrorMessage(e, fallback: 'Не удалось выйти из группы'),
          ),
        ),
      );
    }
  }

  Future<void> _openGroupMembersManage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupMembersManageScreen(
          chatId: widget.chatId,
          createdBy: _groupCreatedBy ?? -1,
          currentUserId: _currentUserId ?? -1,
        ),
      ),
    );
    if (!mounted) return;
    await _loadChatMembers();
    await _loadChatDetails();
  }

  void _onMessagesScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingOlder || !_hasMoreMessages) return;
    final pos = _scrollController.position;
    if (pos.pixels <= 64) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlder || !_hasMoreMessages || _messages.isEmpty) return;
    final first = _messages.first;
    final mid = ChatDetailMessageMaps.intFromDynamic(first['id']);
    if (mid == null) return;

    setState(() {
      _isLoadingOlder = true;
    });

    try {
      final page = await _messagesService.getMessagesPage(
        widget.chatId,
        beforeMessageId: mid,
        limit: 50,
      );
      if (!mounted) return;

      final prevMax = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      final prevOffset = _scrollController.hasClients
          ? _scrollController.offset
          : 0.0;

      var normalized = page.messages
          .map(ChatDetailMessageMaps.normalizeMessageMap)
          .toList();

      normalized = normalized.map((m) {
        if (_currentUserId == null) return m;
        if (!_isMine(m)) return m;
        final id = ChatDetailMessageMaps.intFromDynamic(m['id']);
        if (id == null) return m;
        final copy = Map<String, dynamic>.from(m);
        copy['delivery_status'] = _computeDeliveryForOutgoing(id);
        return copy;
      }).toList();

      normalized.sort((a, b) {
        final am = serverInstantMillis(a['created_at']?.toString());
        final bm = serverInstantMillis(b['created_at']?.toString());
        return (am ?? 0).compareTo(bm ?? 0);
      });

      if (!mounted) return;

      setState(() {
        _messages = [...normalized, ..._messages];
        _hasMoreMessages = page.hasMore;
        _isLoadingOlder = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final newMax = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(newMax - prevMax + prevOffset);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingOlder = false;
      });
    }
  }

  void _onOpenChatSyncRequest() {
    final req = openChatSyncNotifier.value;
    if (req == null) return;
    if (req.chatId != widget.chatId) return;
    unawaited(_loadMessages(silentError: true));
  }

  /// [silentError] — при догрузке по inbox не затирать экран ошибкой сети.
  Future<void> _loadMessages({bool silentError = false}) async {
    try {
      final page = await _messagesService.getMessagesPage(
        widget.chatId,
        limit: 50,
      );
      final messages = page.messages;
      _hasMoreMessages = page.hasMore;
      _lastReadByUserId.clear();
      try {
        final rows = await _messagesService.getChatReadState(widget.chatId);

        for (final r in rows) {
          final uid = ChatDetailMessageMaps.intFromDynamic(r['user_id']);
          final lr = ChatDetailMessageMaps.intFromDynamic(r['last_read_message_id']);
          if (uid != null) {
            _lastReadByUserId[uid] = lr ?? 0;
          }
        }
      } catch (_) {}

      var normalizedMessages = messages
          .map(ChatDetailMessageMaps.normalizeMessageMap)
          .toList();

      normalizedMessages = normalizedMessages.map((m) {
        if (_currentUserId == null) return m;

        if (!_isMine(m)) return m;
        final mid = ChatDetailMessageMaps.intFromDynamic(m['id']);
        if (mid == null) return m;
        final copy = Map<String, dynamic>.from(m);
        copy['delivery_status'] = _computeDeliveryForOutgoing(mid);
        return copy;
      }).toList();

      normalizedMessages.sort((a, b) {
        final am = serverInstantMillis(a['created_at']?.toString());
        final bm = serverInstantMillis(b['created_at']?.toString());
        return (am ?? 0).compareTo(bm ?? 0);
      });

      if (!mounted) return;

      setState(() {
        _messages = normalizedMessages;
        _isLoading = false;
      });

      await _markCurrentChatAsRead();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(jump: true);
      });
    } catch (e) {
      if (!mounted) return;
      if (silentError) return;

      setState(() {
        _error = chatDetailExtractErrorMessage(
          e,
          fallback: 'Не удалось загрузить сообщения',
        );
        _isLoading = false;
      });
    }
  }

}
