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

    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final replyId = _pendingReplyToMessageId();

      final createdMessage = ChatDetailMessageMaps.normalizeMessageMap(
        await _messagesService.sendMessage(
          chatId: widget.chatId,
          text: text,
          replyToMessageId: replyId,
        ),
      );

      if (!mounted) return;

      _messageController.clear();

      final exists = _messages.any((m) => m['id'] == createdMessage['id']);

      setState(() {
        if (!exists) {
          _messages.add(createdMessage);
        }
        _replyingTo = null;
        _isSending = false;
      });

      await _markCurrentChatAsRead();

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
              fallback: 'Failed to send message',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showAttachmentPicker() async {
    if (_isUploadingChatAvatar || _isSendingDocument) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.photo, color: AppColors.accent),
                  title: const Text('Photo'),
                  onTap: () => Navigator.of(ctx).pop('photo'),
                ),
                ListTile(
                  leading: const Icon(
                    AppIcons.videoLibrary,
                    color: AppColors.accent,
                  ),
                  title: const Text('Video'),
                  subtitle: const Text('Pick a regular video from gallery'),
                  onTap: () => Navigator.of(ctx).pop('video_gallery'),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.insert_drive_file,
                    color: AppColors.accent,
                  ),
                  title: const Text('File'),
                  subtitle: const Text('PDF, Office, ODF, RTF, TXT up to 50 MB'),
                  onTap: () => Navigator.of(ctx).pop('document'),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || choice == null) return;

    if (choice == 'photo') {
      await _pickAndSendImage();
      return;
    }

    if (choice == 'video_gallery') {
      await _pickAndSendVideo(source: ImageSource.gallery);
      return;
    }

    if (choice == 'document') {
      await _pickAndSendDocument();
    }
  }

  Future<void> _sendDocumentFromLocalPath(
    String path, {
    required String displayName,
  }) async {
    if (_isSendingDocument) return;

    final file = File(path);
    if (!await file.exists()) return;

    final len = await file.length();
    if (len > kMaxDocumentBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File is larger than 50 MB')),
      );
      return;
    }

    if (!isAllowedDocumentFileName(displayName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unsupported file type. Allowed: PDF, Office, ODF, RTF, TXT'),
        ),
      );
      return;
    }

    setState(() {
      _isSendingDocument = true;
    });

    try {
      final replyId = _pendingReplyToMessageId();
      final createdMessage = ChatDetailMessageMaps.normalizeMessageMap(
        await _messagesService.sendDocumentMessage(
          chatId: widget.chatId,
          filePath: path,
          fileName: displayName,
          replyToMessageId: replyId,
        ),
      );

      if (!mounted) return;

      final exists = _messages.any((m) => m['id'] == createdMessage['id']);

      setState(() {
        if (!exists) {
          _messages.add(createdMessage);
        }
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

      final createdMessage = ChatDetailMessageMaps.normalizeMessageMap(
        await _messagesService.sendPhotoMessage(
          chatId: widget.chatId,
          imagePath: picked.path,
          fileName: picked.name,
          replyToMessageId: replyId,
        ),
      );

      if (!mounted) return;

      final exists = _messages.any((m) => m['id'] == createdMessage['id']);

      setState(() {
        if (!exists) {
          _messages.add(createdMessage);
        }
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

      final createdMessage = ChatDetailMessageMaps.normalizeMessageMap(
        await _messagesService.sendVideoMessage(
          chatId: widget.chatId,
          videoPath: picked.path,
          fileName: picked.name,
          replyToMessageId: replyId,
        ),
      );

      if (!mounted) return;

      final exists = _messages.any((m) => m['id'] == createdMessage['id']);

      setState(() {
        if (!exists) {
          _messages.add(createdMessage);
        }
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

      final createdMessage = ChatDetailMessageMaps.normalizeMessageMap(
        await _messagesService.sendVideoNoteMessage(
          chatId: widget.chatId,
          videoPath: videoPath,
          fileName: _basenameFromPath(videoPath),
          replyToMessageId: replyId,
        ),
      );

      if (!mounted) return;

      final exists = _messages.any((m) => m['id'] == createdMessage['id']);

      setState(() {
        if (!exists) {
          _messages.add(createdMessage);
        }
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

  Future<void> _showMessageActions(Map<String, dynamic> message) async {
    final isMine = _isMine(message);
    final messageId = ChatDetailMessageMaps.intFromDynamic(message['id']);
    if (messageId == null) return;

    final messageType = (message['message_type'] ?? 'text').toString();
    final text = (message['text'] ?? '').toString().trim();

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.reply, color: AppColors.accent),
                  title: const Text('Reply'),
                  onTap: () => Navigator.of(ctx).pop('reply'),
                ),
                ListTile(
                  leading: const Icon(Icons.forward, color: AppColors.accent),
                  title: const Text('Forward'),
                  onTap: () => Navigator.of(ctx).pop('forward'),
                ),
                if (text.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      AppIcons.copy,
                      color: AppColors.textPrimary,
                    ),
                    title: const Text('Copy'),
                    onTap: () => Navigator.of(ctx).pop('copy'),
                  ),
                if (isMine && messageType == 'text' && text.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      AppIcons.edit,
                      color: AppColors.textPrimary,
                    ),
                    title: const Text('Edit'),
                    onTap: () => Navigator.of(ctx).pop('edit'),
                  ),
                if (isMine)
                  ListTile(
                    leading: const Icon(
                      AppIcons.delete,
                      color: Colors.redAccent,
                    ),
                    title: const Text('Delete'),
                    onTap: () => Navigator.of(ctx).pop('delete'),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

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

    if (action == 'copy' && text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text copied')),
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
      await _confirmDeleteMessage(messageId);
    }
  }

  String _titleForForwardChat(Map<String, dynamic> chat) {
    final title = (chat['title'] ?? '').toString().trim();
    if (title.isNotEmpty) return title;
    return 'Chat ${chat['id'] ?? ''}';
  }

  Future<void> _pickForwardTarget(Map<String, dynamic> message) async {
    final sourceId = ChatDetailMessageMaps.intFromDynamic(message['id']);
    if (sourceId == null || _currentUserId == null) return;

    List<Map<String, dynamic>> chats;
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
              fallback: 'Failed to load chats',
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Forward to...',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final targetId = ChatDetailMessageMaps.intFromDynamic(
                      chat['id'] ?? chat['chat_id'],
                    );
                    if (targetId == null) return const SizedBox.shrink();
                    final title = _titleForForwardChat(chat);
                    final chatType = (chat['type'] ?? 'private').toString();

                    return ListTile(
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await _forwardToChat(
                          sourceId,
                          targetId,
                          title,
                          chatType,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
          const SnackBar(content: Text('Message forwarded')),
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
              fallback: 'Failed to forward message',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteMessage(int messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Delete message?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

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
}
