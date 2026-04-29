part of 'chat_detail_screen.dart';

mixin _ChatDetailComposerAndActionsLogic
    on
        _ChatDetailScreenStateBase,
        _ChatDetailStateHelpers,
        _ChatDetailRealtimeAndCallsLogic {
  Future<void> _sendMessage() async {
    if (_editingMessage != null) {
      await _submitEdit();
      return;
    }

    if (!_composerController.canSendText(
      controller: _messageController,
      isSending: _isSending,
    )) {
      return;
    }
    final text = _composerController.normalizedText(_messageController);
    final replyId = _pendingReplyToMessageId();
    final clientTempId =
        'tmp-${widget.chatId}-${DateTime.now().microsecondsSinceEpoch}';
    final clientMessageId = clientTempId;
    final optimisticMessage = <String, dynamic>{
      'client_temp_id': clientTempId,
      'client_message_id': clientMessageId,
      'chat_id': widget.chatId,
      'sender_id': _currentUserId,
      'sender_username': _memberNames[_currentUserId] ?? 'Вы',
      'text': text,
      'message_type': 'text',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'reply_to_message_id': replyId,
      'reply_to': _replyingTo,
      'delivery_status': 'sending',
      'reactions': const [],
    };

    setState(() {
      _isSending = true;
      _messageListController.appendIfMissing(_messages, optimisticMessage);
      _replyingTo = null;
    });
    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      final createdMessage = await _messageSendController.sendText(
        chatId: widget.chatId,
        text: text,
        replyToMessageId: replyId,
        clientMessageId: clientMessageId,
      );

      if (!mounted) return;

      setState(() {
        final replaced = _messageListController.replaceByClientTempId(
          _messages,
          clientTempId: clientTempId,
          replacement: createdMessage,
        );
        if (!replaced) {
          _messageListController.appendIfMissing(_messages, createdMessage);
        }
        _isSending = false;
      });

      await _markCurrentChatAsRead();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messageListController.markClientTempFailed(
          _messages,
          clientTempId: clientTempId,
          error: chatDetailExtractErrorMessage(
            e,
            fallback: 'Failed to send message',
          ),
        );
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Failed to send message',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _retryFailedMessage(Map<String, dynamic> message) async {
    final clientTempId = message['client_temp_id']?.toString();
    final clientMessageId =
        (message['client_message_id'] ?? clientTempId)?.toString();
    final text = (message['text'] ?? '').toString().trim();
    if (clientTempId == null || clientTempId.isEmpty || text.isEmpty) return;

    setState(() {
      _messageListController.markClientTempSending(
        _messages,
        clientTempId: clientTempId,
      );
    });

    try {
      final createdMessage = await _messageSendController.sendText(
        chatId: widget.chatId,
        text: text,
        replyToMessageId: ChatDetailMessageMaps.intFromDynamic(
          message['reply_to_message_id'],
        ),
        clientMessageId: clientMessageId,
      );
      if (!mounted) return;
      setState(() {
        _messageListController.replaceByClientTempId(
          _messages,
          clientTempId: clientTempId,
          replacement: createdMessage,
        );
      });
      await _markCurrentChatAsRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messageListController.markClientTempFailed(
          _messages,
          clientTempId: clientTempId,
          error: chatDetailExtractErrorMessage(
            e,
            fallback: 'Failed to send message',
          ),
        );
      });
    }
  }

  Future<void> _showAttachmentPicker() async {
    if (_isUploadingChatAvatar || _isSendingDocument) return;

    final choice = await showModalBottomSheet<ChatComposerAttachmentAction>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const ChatComposerAttachmentSheet(),
    );

    if (!mounted || choice == null) return;

    switch (choice) {
      case ChatComposerAttachmentAction.photo:
        await _pickAndSendImage();
        break;
      case ChatComposerAttachmentAction.videoGallery:
        await _pickAndSendVideo(source: ImageSource.gallery);
        break;
      case ChatComposerAttachmentAction.document:
        await _pickAndSendDocument();
        break;
    }
  }

  Future<void> _sendDocumentFromLocalPath(
    String path, {
    required String displayName,
  }) async {
    if (_isSendingDocument) return;

    final validation = await _mediaUploadController.validateDocumentPath(
      path: path,
      displayName: displayName,
    );
    if (!validation.isOk) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation.errorMessage!)),
      );
      return;
    }

    setState(() {
      _isSendingDocument = true;
    });

    try {
      final replyId = _pendingReplyToMessageId();
      final createdMessage = await _messageSendController.sendDocument(
        chatId: widget.chatId,
        filePath: path,
        fileName: displayName,
        replyToMessageId: replyId,
      );

      if (!mounted) return;

      setState(() {
        _messageListController.appendIfMissing(_messages, createdMessage);
        _replyingTo = null;
        _isSendingDocument = false;
      });

      await _markCurrentChatAsRead();
      requestChatsListRefresh();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSendingDocument = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Failed to send file',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _onDesktopDocumentsDropped(DropDoneDetails detail) async {
    if (_isSendingDocument || _isSending || _isSendingImage || _isSendingVideo) {
      return;
    }

    for (final file in detail.files) {
      final path = file.path;
      if (path.isEmpty) continue;
      final name =
          file.name.isNotEmpty ? file.name : path.split(RegExp(r'[/\\]')).last;
      await _sendDocumentFromLocalPath(path, displayName: name);
    }
  }

  Future<void> _pickAndSendDocument() async {
    if (_isSendingDocument) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kAllowedDocumentExtensions,
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final path = picked.path;
    if (path == null || path.isEmpty) return;

    final name = picked.name.trim().isNotEmpty
        ? picked.name
        : path.split(RegExp(r'[/\\]')).last;
    await _sendDocumentFromLocalPath(path, displayName: name);
  }

  Future<void> _pickAndSendImage() async {
    if (_isSendingImage || _isSendingDocument) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2200,
      );

      if (picked == null) return;

      setState(() {
        _isSendingImage = true;
      });

      final replyId = _pendingReplyToMessageId();

      final createdMessage = await _messageSendController.sendImage(
        chatId: widget.chatId,
        imagePath: picked.path,
        fileName: picked.name,
        replyToMessageId: replyId,
      );

      if (!mounted) return;

      setState(() {
        _messageListController.appendIfMissing(_messages, createdMessage);
        _replyingTo = null;
        _isSendingImage = false;
      });

      await _markCurrentChatAsRead();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSendingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Failed to send photo',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _pickAndSendVideo({required ImageSource source}) async {
    if (_isSendingVideo || _isSendingDocument) return;

    try {
      final picked = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );

      if (picked == null) return;

      setState(() {
        _isSendingVideo = true;
      });

      final replyId = _pendingReplyToMessageId();

      final createdMessage = await _messageSendController.sendVideo(
        chatId: widget.chatId,
        videoPath: picked.path,
        fileName: picked.name,
        replyToMessageId: replyId,
      );

      if (!mounted) return;

      setState(() {
        _messageListController.appendIfMissing(_messages, createdMessage);
        _replyingTo = null;
        _isSendingVideo = false;
      });

      await _markCurrentChatAsRead();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSendingVideo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Failed to send video',
            ),
          ),
        ),
      );
    }
  }

  String _basenameFromPath(String path) {
    final name = path.replaceAll(r'\', '/').split('/').last;
    return name.isEmpty ? 'video_note.mp4' : name;
  }

  Future<void> _openVideoNoteRecorder() async {
    if (_isSendingVideo || _isSendingDocument) return;

    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const VideoNoteRecordScreen(),
      ),
    );

    if (path == null || path.isEmpty) return;

    await _uploadVideoNote(path);
  }

  Future<void> _uploadVideoNote(String videoPath) async {
    if (_isSendingVideo || _isSendingDocument) return;

    setState(() {
      _isSendingVideo = true;
    });

    try {
      final replyId = _pendingReplyToMessageId();

      final createdMessage = await _messageSendController.sendVideoNote(
        chatId: widget.chatId,
        videoPath: videoPath,
        fileName: _basenameFromPath(videoPath),
        replyToMessageId: replyId,
      );

      if (!mounted) return;

      setState(() {
        _messageListController.appendIfMissing(_messages, createdMessage);
        _replyingTo = null;
        _isSendingVideo = false;
      });

      await _markCurrentChatAsRead();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSendingVideo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Failed to send video note',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showMessageActions(
    Map<String, dynamic> message, [
    Offset? menuPosition,
  ]) async {
    final messageId = ChatDetailMessageMaps.intFromDynamic(message['id']);
    final isFailed = message['delivery_status']?.toString() == 'failed';
    if (messageId == null && !isFailed) return;

    final text = (message['text'] ?? '').toString().trim();

    final String? action;
    if (menuPosition != null) {
      final size = MediaQuery.sizeOf(context);
      final padding = MediaQuery.paddingOf(context);
      const menuW = 300.0;
      final left = menuPosition.dx.clamp(8.0, size.width - menuW - 8);
      final top = menuPosition.dy.clamp(padding.top + 8, size.height - 400);

      action = await showGeneralDialog<String>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.transparent,
        pageBuilder: (ctx, _, __) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(ctx).pop(),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: menuW,
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: ChatMessageActionsPanel(
                    message: message,
                    isMineMessage: _isMine(message),
                    onAction: (code) => Navigator.of(ctx).pop(code),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      action = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: ChatMessageActionsPanel(
                  message: message,
                  isMineMessage: _isMine(message),
                  onAction: (code) => Navigator.of(ctx).pop(code),
                ),
              ),
            ),
          );
        },
      );
    }

    if (!mounted) return;

    if (action == 'retry') {
      await _retryFailedMessage(message);
      return;
    }

    if (action == 'reply') {
      setState(() {
        _replyingTo = Map<String, dynamic>.from(message);
        _editingMessage = null;
      });
      return;
    }

    if (action == 'forward') {
      await _pickForwardTarget(message);
      return;
    }

    if (action != null && action.startsWith('react:')) {
      final emoji = action.substring('react:'.length);
      await _toggleReactionEmoji(message, emoji);
      return;
    }

    if (action == 'copy' && text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Текст скопирован')),
      );
      return;
    }

    if (action == 'edit') {
      setState(() {
        _editingMessage = Map<String, dynamic>.from(message);
        _replyingTo = null;
        _messageController.text = text;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      });
      return;
    }

    if (action == 'delete') {
      if (messageId == null) return;
      await _confirmDeleteMessage(messageId);
    }
  }

  String _titleForForwardChat(ChatSummary chat) {
    final title = chat.title.trim();
    if (title.isNotEmpty) return title;
    return 'Чат ${chat.id}';
  }

  Future<void> _pickForwardTarget(Map<String, dynamic> message) async {
    final sourceId = ChatDetailMessageMaps.intFromDynamic(message['id']);
    if (sourceId == null || _currentUserId == null) return;

    List<ChatSummary> chats;
    try {
      chats = await ChatsService().getChats(currentUserId: _currentUserId!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Не удалось загрузить чаты',
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    final selected = await showForwardChatPickerSheet(
      context: context,
      chats: chats,
      excludeChatId: widget.chatId,
    );
    if (selected == null) return;
    await _forwardToChat(
      sourceId,
      selected.id,
      _titleForForwardChat(selected),
      selected.type,
    );
  }

  Future<void> _forwardToChat(
    int sourceMessageId,
    int targetChatId,
    String title,
    String chatType,
  ) async {
    try {
      final raw = await _messagesService.forwardMessage(
        targetChatId: targetChatId,
        sourceMessageId: sourceMessageId,
      );
      final created = ChatDetailMessageMaps.normalizeMessageMap(raw);

      if (!mounted) return;

      if (targetChatId == widget.chatId) {
        setState(() {
          _messages.add(created);
          _messages.sort((a, b) {
            final am = serverInstantMillis(a['created_at']?.toString());
            final bm = serverInstantMillis(b['created_at']?.toString());
            return (am ?? 0).compareTo(bm ?? 0);
          });
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
        requestChatsListRefresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сообщение переслано')),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              chatId: targetChatId,
              title: title,
              chatType: chatType,
            ),
          ),
        );
        requestChatsListRefresh();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Не удалось переслать сообщение',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteMessage(int messageId) async {
    final confirmed = await showMessengerConfirmDialog(
      context: context,
      title: 'Удалить сообщение?',
      body: 'Это действие нельзя отменить.',
      confirmLabel: 'Удалить',
    );

    if (!confirmed) return;

    try {
      await _messagesService.deleteMessage(messageId);

      if (!mounted) return;

      setState(() {
        _messages.removeWhere((m) => m['id'] == messageId);
        if (_editingMessage != null && _editingMessage!['id'] == messageId) {
          _editingMessage = null;
          _messageController.clear();
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Failed to delete message',
            ),
          ),
        ),
      );
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  int? _pendingReplyToMessageId() {
    if (_replyingTo == null) return null;
    return ChatDetailMessageMaps.intFromDynamic(_replyingTo!['id']);
  }

  Future<void> _submitEdit() async {
    final editing = _editingMessage;
    if (editing == null) return;

    final messageId = ChatDetailMessageMaps.intFromDynamic(editing['id']);
    if (messageId == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final updated = ChatDetailMessageMaps.normalizeMessageMap(
        await _messagesService.updateMessage(
          messageId: messageId,
          text: text,
        ),
      );

      if (!mounted) return;

      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == updated['id']);
        if (index >= 0) {
          _messages[index] = updated;
        }
        _editingMessage = null;
        _messageController.clear();
        _isSending = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Failed to update message',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _toggleReactionEmoji(
    Map<String, dynamic> message,
    String emoji,
  ) async {
    final messageId = ChatDetailMessageMaps.intFromDynamic(message['id']);
    if (messageId == null) return;

    final emojiNorm = emoji.trim();
    var mine = false;
    final raw = message['reactions'];
    if (raw is List) {
      for (final r in raw) {
        Map<String, dynamic>? m;
        if (r is Map<String, dynamic>) {
          m = r;
        } else if (r is Map) {
          m = Map<String, dynamic>.from(r);
        }
        if (m == null) continue;
        if (m['emoji']?.toString().trim() != emojiNorm) continue;
        if (m['reacted_by_me'] == true) {
          mine = true;
          break;
        }
        final uid = _currentUserId;
        if (uid != null) {
          final idsRaw = m['reactor_user_ids'];
          if (idsRaw is List) {
            for (final x in idsRaw) {
              if (ChatDetailMessageMaps.intFromDynamic(x) == uid) {
                mine = true;
                break;
              }
            }
          }
        }
        if (mine) break;
      }
    }

    try {
      final updated = ChatDetailMessageMaps.normalizeMessageMap(
        mine
            ? await _messagesService.removeReaction(
                messageId: messageId,
                emoji: emoji,
              )
            : await _messagesService.addReaction(
                messageId: messageId,
                emoji: emoji,
              ),
      );
      if (!mounted) return;
      setState(() {
        final uid = ChatDetailMessageMaps.intFromDynamic(updated['id']);
        final idx = _messages.indexWhere(
          (m) => ChatDetailMessageMaps.intFromDynamic(m['id']) == uid,
        );
        if (idx >= 0) {
          _messages[idx] = updated;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Не удалось обновить реакцию',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_editingMessage != null || _isSendingVoice) return;

    if (_recordingVoice) {
      String? path;
      try {
        path = await _voiceRecorder.stop();
      } catch (_) {
        path = null;
      }
      if (!mounted) return;
      setState(() => _recordingVoice = false);
      if (path != null && path.isNotEmpty) {
        final name = path.split(RegExp(r'[\\/]')).last;
        await _uploadVoiceRecording(path, name);
      }
      return;
    }

    if (!kIsWeb) {
      final st = await Permission.microphone.request();
      if (!st.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceSoft,
            content: Text('Нужен доступ к микрофону'),
          ),
        );
        return;
      }
    }

    if (!await _voiceRecorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text('Нет разрешения на запись звука'),
        ),
      );
      return;
    }

    final tmpPath = kIsWeb
        ? 'voice_recording'
        : '${(await getTemporaryDirectory()).path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _voiceRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: tmpPath,
      );
      if (!mounted) return;
      setState(() => _recordingVoice = true);
    } catch (e) {
      if (kIsWeb) {
        await _pickAndSendVoiceFile();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Не удалось начать запись',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _uploadVoiceRecording(String path, String fileName) async {
    if (_isSendingVoice) return;

    setState(() {
      _isSendingVoice = true;
    });

    try {
      final replyId = _pendingReplyToMessageId();
      final created = await _messageSendController.sendVoice(
        chatId: widget.chatId,
        filePath: path,
        fileName: fileName,
        replyToMessageId: replyId,
      );
      if (!mounted) return;
      setState(() {
        final uid = ChatDetailMessageMaps.intFromDynamic(created['id']);
        final exists = _messages.any(
          (m) => ChatDetailMessageMaps.intFromDynamic(m['id']) == uid,
        );
        if (!exists) {
          _messages.add(created);
          _messages.sort((a, b) {
            final am = serverInstantMillis(a['created_at']?.toString());
            final bm = serverInstantMillis(b['created_at']?.toString());
            return (am ?? 0).compareTo(bm ?? 0);
          });
        }
        _replyingTo = null;
        _isSendingVoice = false;
      });
      await _markCurrentChatAsRead();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingVoice = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            chatDetailExtractErrorMessage(
              e,
              fallback: 'Не удалось отправить голосовое',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _pickAndSendVoiceFile() async {
    if (_isSendingVoice || _editingMessage != null || _recordingVoice) return;
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['m4a', 'mp3', 'ogg', 'aac', 'wav', 'webm'],
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.single;
    final path = f.path;
    if (path == null || path.isEmpty) return;
    final name = f.name.trim().isEmpty ? 'voice.m4a' : f.name.trim();
    await _uploadVoiceRecording(path, name);
  }

  void _openFullscreenImage(String url) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => ChatDetailFullscreenImageViewer(url: url),
      ),
    );
  }

  void _openFullscreenVideo(String url, {required bool isVideoNote}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => ChatDetailFullscreenVideoPage(
          url: url,
          isVideoNote: isVideoNote,
        ),
      ),
    );
  }

  Future<void> _showDesktopComposerExtras() async {
    if (!mounted) return;
    if (_isUploadingChatAvatar || _isSendingDocument) return;

    final choice = await showModalBottomSheet<ChatComposerDesktopExtraAction>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const ChatComposerDesktopExtraSheet(),
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case ChatComposerDesktopExtraAction.videoNote:
        await _openVideoNoteRecorder();
        break;
      case ChatComposerDesktopExtraAction.voice:
        await _toggleVoiceRecording();
        break;
    }
  }

  void _showInChatSearch() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: const Text(
            'Поиск в чате',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Поиск по истории сообщений появится в следующей версии.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Понятно'),
            ),
          ],
        );
      },
    );
  }

  void _showPrivateChatHeaderMenu() {
    if (!mounted) return;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surfaceRaised,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Уведомления о чате'),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
                ListTile(
                  title: const Text('Пожаловаться…'),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
