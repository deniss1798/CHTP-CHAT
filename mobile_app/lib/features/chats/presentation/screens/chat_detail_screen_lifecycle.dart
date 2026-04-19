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
    final controller = TextEditingController(text: _chatTitle.trim());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Название группы',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Название',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),

            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final t = controller.text.trim();
    if (t.isEmpty) return;
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Покинуть группу?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Вы больше не будете получать сообщения из этой группы.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(

              'Покинуть',
              style: TextStyle(color: Colors.orange.shade300),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
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

  Future<void> _loadMessages() async {
    try {
      final messages = await _messagesService.getMessages(widget.chatId);
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
