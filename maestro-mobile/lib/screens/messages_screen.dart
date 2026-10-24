import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/messaging_service.dart';
import '../services/messaging_inbox.dart';
import 'message_emoji_picker.dart';
import 'message_image.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen(
      {super.key, required this.client, this.teacher = true, this.inbox});
  final SupabaseClient client;
  final bool teacher;
  final MessagingInbox? inbox;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late final MessagingService service = MessagingService(widget.client);
  late MessagingInbox inbox;
  String search = '';
  bool unreadOnly = false;

  @override
  void initState() {
    super.initState();
    inbox = widget.inbox ?? MessagingInbox(service);
    inbox.addListener(_inboxChanged);
    inbox.start();
  }

  void _inboxChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    inbox.removeListener(_inboxChanged);
    if (widget.inbox == null) inbox.dispose();
    super.dispose();
  }

  Future<void> _load() => inbox.refresh();

  void _open(Map<String, dynamic> item) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => ChatRoom(
                  service: service,
                  teacherId: item['teacherId'] as String,
                  studentId: item['studentId'] as String,
                  name: item['name'] as String,
                  instrument: item['instrument'] as String?,
                  conversationId: item['id'] as String?,
                  onRead: inbox.scheduleRefresh,
                )))
        .then((_) => _load());
  }

  Future<void> _start() async {
    try {
      final candidates = await service.candidates();
      if (!mounted) return;
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) => SafeArea(
                child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .65,
                    child: Column(children: [
                      const ListTile(title: Text('Start a conversation')),
                      Expanded(
                          child: candidates.isEmpty
                              ? Center(
                                  child: Text(widget.teacher
                                      ? 'No authorized students yet.'
                                      : 'No authorized teachers yet.'))
                              : ListView.builder(
                                  itemCount: candidates.length,
                                  itemBuilder: (_, i) {
                                    final item = candidates[i];
                                    return ListTile(
                                      leading: _Avatar(item['name'] as String),
                                      title: Text(item['name'] as String),
                                      subtitle: Text(
                                          item['instrument'] as String? ?? ''),
                                      onTap: () {
                                        Navigator.pop(sheetContext);
                                        _open(item);
                                      },
                                    );
                                  })),
                    ])),
              ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load contacts: $e')));
      }
    }
  }

  Future<void> _notificationSettings() async {
    try {
      var enabled = await service.notificationsEnabled();
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                    title: const Text('Message notifications'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      SwitchListTile(
                          title: const Text('Allow message alerts'),
                          value: enabled,
                          onChanged: (value) async {
                            try {
                              await service.setNotificationsEnabled(value);
                              setDialogState(() => enabled = value);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Could not save preference: $e')));
                              }
                            }
                          }),
                      const Text(
                          'Device push alerts need the server notification service to be configured.'),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Done'))
                    ],
                  )));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not load notification settings: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = inbox.conversations
        .where((c) =>
            (c['name'] as String)
                .toLowerCase()
                .contains(search.toLowerCase()) &&
            (!unreadOnly || (c['unreadCount'] as num? ?? 0) > 0))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Messages'), actions: [
        IconButton(
            onPressed: _notificationSettings,
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notification settings'),
        IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh'),
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _start,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('New')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by name',
                  border: OutlineInputBorder()),
              onChanged: (value) => setState(() => search = value),
            )),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              ChoiceChip(
                  label: const Text('All'),
                  selected: !unreadOnly,
                  onSelected: (_) => setState(() => unreadOnly = false)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: const Text('Unread'),
                  selected: unreadOnly,
                  onSelected: (_) => setState(() => unreadOnly = true)),
            ])),
        Expanded(
            child: inbox.loading
                ? const Center(child: CircularProgressIndicator())
                : inbox.error != null
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Could not load messages: ${inbox.error}'),
                        TextButton(
                            onPressed: _load, child: const Text('Try again'))
                      ]))
                    : visible.isEmpty
                        ? Center(
                            child: Text(unreadOnly
                                ? 'No unread conversations.'
                                : search.isNotEmpty
                                    ? 'No matching conversations.'
                                    : 'No conversations yet.'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (_, i) {
                                final c = visible[i];
                                final unread =
                                    (c['unreadCount'] as num? ?? 0).toInt();
                                final date = DateTime.tryParse(
                                        '${c['lastMessageAt'] ?? ''}')
                                    ?.toLocal();
                                return ListTile(
                                  leading: _Avatar(c['name'] as String),
                                  title: Text(c['name'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: unread > 0
                                              ? FontWeight.bold
                                              : null)),
                                  subtitle: Text(
                                      c['lastMessage'] as String? ??
                                          'Say hello',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (date != null)
                                          Text(DateFormat.MMMd().format(date),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                        if (unread > 0)
                                          Badge(
                                              label: Text(unread > 99
                                                  ? '99+'
                                                  : '$unread')),
                                      ]),
                                  onTap: () => _open(c),
                                );
                              },
                            ))),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => CircleAvatar(
      child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase()));
}

class ChatRoom extends StatefulWidget {
  const ChatRoom(
      {super.key,
      required this.service,
      required this.teacherId,
      required this.studentId,
      required this.name,
      this.instrument,
      this.conversationId,
      this.onRead});
  final MessagingService service;
  final String teacherId;
  final String studentId;
  final String name;
  final String? instrument;
  final String? conversationId;
  final VoidCallback? onRead;

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom> with WidgetsBindingObserver {
  static final Map<String, String> drafts = {};
  final controller = TextEditingController();
  final scroll = ScrollController();
  final List<Map<String, dynamic>> messages = [];
  final Map<String, String> pending = {};
  final Set<String> failed = {};
  final Set<String> sending = {};
  final recorder = AudioRecorder();
  final previewPlayer = AudioPlayer();
  Timer? recordLimit;
  DateTime? recordStarted;
  XFile? recording;
  String? recordingClientId;
  XFile? failedFile;
  String? failedFileType;
  String? failedFileClientId;
  int? recordingDurationMs;
  bool recordingNow = false;
  bool uploading = false;
  String? conversationId;
  String? error;
  bool loading = true;
  bool loadingOlder = false;
  bool hasOlder = true;
  bool newMessages = false;
  DateTime? peerReadAt;
  RealtimeChannel? messageChannel;
  RealtimeChannel? readChannel;
  RealtimeChannel? attachmentChannel;
  String? lastReadMessageId;
  bool markingRead = false;

  String get draftKey =>
      '${widget.service.userId}:${widget.teacherId}:${widget.studentId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    conversationId = widget.conversationId;
    controller.text = drafts[draftKey] ?? '';
    controller.addListener(() {
      drafts[draftKey] = controller.text;
      setState(() {});
    });
    scroll.addListener(() {
      if (scroll.hasClients &&
          scroll.position.pixels > scroll.position.maxScrollExtent - 250) {
        _older();
      }
      if (_atBottom() && newMessages) {
        setState(() => newMessages = false);
        _markVisibleRead();
      }
    });
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (messageChannel != null) {
      widget.service.unwatch(messageChannel!);
    }
    if (readChannel != null) widget.service.unwatch(readChannel!);
    if (attachmentChannel != null) {
      widget.service.unwatch(attachmentChannel!);
    }
    recordLimit?.cancel();
    recorder.dispose();
    previewPlayer.dispose();
    scroll.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshRecent();
  }

  bool _atBottom() => !scroll.hasClients || scroll.offset < 90;

  Future<void> _initialize() async {
    try {
      final id = conversationId ??
          await widget.service.open(widget.teacherId, widget.studentId);
      if (!await widget.service.canMessage(id)) {
        throw StateError('Conversation access is no longer active.');
      }
      final rows = await widget.service.messages(id);
      if (!mounted) return;
      setState(() {
        conversationId = id;
        messages.addAll(rows);
        hasOlder = rows.length == MessagingService.pageSize;
        loading = false;
        error = null;
      });
      messageChannel = widget.service.watchMessages(id, _incoming);
      readChannel = widget.service.watchReads(id, _refreshRead);
      attachmentChannel = widget.service.watchAttachments(id, _refreshRecent);
      _refreshRead();
      WidgetsBinding.instance.addPostFrameCallback((_) => _markVisibleRead());
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> _refreshRecent() async {
    final id = conversationId;
    if (id == null || !mounted) return;
    try {
      if (!await widget.service.canMessage(id)) {
        if (mounted) {
          setState(() {
            messages.clear();
            pending.clear();
            error = 'Conversation access is no longer active.';
          });
        }
        return;
      }
      final rows = await widget.service.messages(id);
      if (!mounted) return;
      final atBottom = _atBottom();
      setState(() {
        for (final row in rows) {
          final existing = messages.indexWhere((m) => m['id'] == row['id']);
          if (existing == -1) {
            messages.add(row);
          } else {
            messages[existing] = row;
          }
        }
        messages.sort(_compare);
        if (!atBottom) newMessages = true;
      });
      if (atBottom) _markVisibleRead();
    } catch (_) {/* The room retains cached history while offline. */}
  }

  static int _compare(Map<String, dynamic> a, Map<String, dynamic> b) {
    final byTime = '${a['created_at']}'.compareTo('${b['created_at']}');
    return byTime != 0 ? byTime : '${a['id']}'.compareTo('${b['id']}');
  }

  void _incoming(Map<String, dynamic> row) {
    if (!mounted || messages.any((m) => m['id'] == row['id'])) return;
    final atBottom = _atBottom();
    setState(() {
      messages.add(row);
      messages.sort(_compare);
      if (!atBottom && row['sender_id'] != widget.service.userId) {
        newMessages = true;
      }
    });
    if (atBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) {
          scroll.animateTo(0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
        _markVisibleRead();
      });
    }
  }

  Future<void> _older() async {
    final id = conversationId;
    if (id == null || loadingOlder || !hasOlder || messages.isEmpty) return;
    loadingOlder = true;
    final oldest = messages.first;
    try {
      final rows = await widget.service.messages(id,
          before: DateTime.parse(oldest['created_at'] as String),
          beforeId: oldest['id'] as String);
      if (!mounted) return;
      setState(() {
        for (final row in rows) {
          if (!messages.any((m) => m['id'] == row['id'])) messages.add(row);
        }
        messages.sort(_compare);
        hasOlder = rows.length == MessagingService.pageSize;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load older messages: $e')));
      }
    } finally {
      loadingOlder = false;
    }
  }

  Future<void> _refreshRead() async {
    final id = conversationId;
    if (id == null) return;
    try {
      final value = await widget.service.peerReadAt(id);
      if (mounted) setState(() => peerReadAt = value);
    } catch (_) {/* A revoked room is handled by the next request. */}
  }

  Future<void> _markVisibleRead() async {
    final id = conversationId;
    if (id == null || !_atBottom() || messages.isEmpty) return;
    final last = messages.last;
    if (last['id'] == null || last['id'] == lastReadMessageId || markingRead) {
      return;
    }
    markingRead = true;
    var succeeded = false;
    try {
      await widget.service.markRead(id, last['id'] as String);
      lastReadMessageId = last['id'] as String;
      succeeded = true;
      widget.onRead?.call();
    } catch (_) {
    } finally {
      markingRead = false;
      if (succeeded &&
          mounted &&
          messages.isNotEmpty &&
          messages.last['id'] != lastReadMessageId &&
          _atBottom()) {
        unawaited(_markVisibleRead());
      }
    }
  }

  Future<void> _chooseEmoji() async {
    final selection = controller.selection;
    final emoji = await showDialog<String>(
        context: context, builder: (_) => const MessageEmojiPicker());
    if (emoji == null || !mounted) return;
    if (selection.isValid) controller.selection = selection;
    insertMessageEmoji(controller, emoji);
  }

  Future<void> _send({String? retryId}) async {
    final id = conversationId;
    if (id == null) return;
    final body = retryId == null ? controller.text.trim() : pending[retryId];
    if (body == null || body.isEmpty) return;
    final clientId = retryId ?? MessagingService.uuid.v4();
    if (sending.contains(clientId)) return;
    if (retryId == null) {
      pending[clientId] = body;
      controller.clear();
    }
    failed.remove(clientId);
    sending.add(clientId);
    setState(() {});
    try {
      final row = await widget.service.send(id, clientId, 'text', body);
      if (!mounted) return;
      setState(() {
        pending.remove(clientId);
        failed.remove(clientId);
        if (!messages.any((m) => m['id'] == row['id'])) messages.add(row);
        messages.sort(_compare);
      });
      if (scroll.hasClients && _atBottom()) {
        scroll.animateTo(0,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    } catch (_) {
      failed.add(clientId);
      if (mounted) setState(() {});
    } finally {
      sending.remove(clientId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _shareReference(String kind) async {
    final id = conversationId;
    if (id == null) return;
    try {
      final items = await widget.service.shareableReferences(id, kind);
      if (!mounted) return;
      await showModalBottomSheet<void>(
          context: context,
          builder: (sheetContext) => SafeArea(
              child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .55,
                  child: Column(children: [
                    ListTile(
                        title: Text(
                            'Share a ${kind == 'lesson' ? 'lesson' : 'piece'}')),
                    Expanded(
                        child: items.isEmpty
                            ? const Center(
                                child: Text('Nothing available to share.'))
                            : ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (_, index) {
                                  final item = items[index];
                                  return ListTile(
                                      title: Text(item['title'] as String),
                                      subtitle:
                                          Text(item['detail'] as String? ?? ''),
                                      onTap: () async {
                                        Navigator.pop(sheetContext);
                                        try {
                                          final row = await widget.service.send(
                                              id,
                                              MessagingService.uuid.v4(),
                                              kind,
                                              '',
                                              referenceId:
                                                  item['id'] as String);
                                          _incoming(row);
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        'Could not share: $e')));
                                          }
                                        }
                                      });
                                })),
                  ]))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load references: $e')));
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (recordingNow) {
      recordLimit?.cancel();
      final path = await recorder.stop();
      if (path == null) return;
      recording = XFile(path);
      recordingDurationMs = DateTime.now()
          .difference(recordStarted!)
          .inMilliseconds
          .clamp(1, 300000);
      await previewPlayer.setFilePath(path);
      if (mounted) setState(() => recordingNow = false);
      return;
    }
    try {
      if (!await recorder.hasPermission()) {
        throw StateError('Microphone permission was denied.');
      }
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/maestro-${MessagingService.uuid.v4()}.m4a';
      await recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
          path: path);
      recordStarted = DateTime.now();
      recordLimit = Timer(const Duration(minutes: 5), _toggleRecording);
      if (mounted) {
        setState(() {
          recordingNow = true;
          recording = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not record audio: $e')));
      }
    }
  }

  Future<void> _discardRecording() async {
    recordLimit?.cancel();
    if (recordingNow) await recorder.cancel();
    await previewPlayer.stop();
    if (mounted) {
      setState(() {
        recordingNow = false;
        recording = null;
        recordingDurationMs = null;
        recordingClientId = null;
      });
    }
  }

  Future<void> _sendRecording() async {
    final file = recording;
    final id = conversationId;
    if (file == null || id == null || uploading) return;
    setState(() => uploading = true);
    try {
      if (await file.length() > MessagingService.maxFileBytes) {
        throw ArgumentError('20 MB recording limit');
      }
      recordingClientId ??= MessagingService.uuid.v4();
      final row =
          await widget.service.send(id, recordingClientId!, 'audio', '');
      await widget.service.upload(id, row, file, 'Recording.m4a', 'audio/mp4',
          durationMs: recordingDurationMs);
      await previewPlayer.stop();
      if (mounted) {
        setState(() {
          recording = null;
          recordingDurationMs = null;
          recordingClientId = null;
        });
      }
      await _refreshRecent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Audio upload failed. Retry from the preview. $e')));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _attach() async {
    final id = conversationId;
    if (id == null) return;
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'Sheet music, images and audio', extensions: [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'mp3',
        'm4a',
        'wav',
        'aac',
        'ogg',
        'webm'
      ])
    ]);
    if (file == null) return;
    final types = <String, String>{
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'wav': 'audio/wav',
      'aac': 'audio/aac',
      'ogg': 'audio/ogg',
      'webm': 'audio/webm'
    };
    final type = types[file.name.split('.').last.toLowerCase()];
    if (type == null) return;
    try {
      setState(() => uploading = true);
      if (await file.length() > MessagingService.maxFileBytes) {
        throw ArgumentError('20 MB file limit');
      }
      failedFile = file;
      failedFileType = type;
      failedFileClientId = MessagingService.uuid.v4();
      await _retryFile();
      await _refreshRecent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Attachment failed: $e')));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _retryFile() async {
    final file = failedFile;
    final type = failedFileType;
    final id = conversationId;
    if (file == null || type == null || id == null) return;
    try {
      if (mounted) setState(() => uploading = true);
      final row =
          await widget.service.send(id, failedFileClientId!, 'file', '');
      await widget.service.upload(id, row, file, file.name, type);
      failedFile = null;
      failedFileType = null;
      failedFileClientId = null;
      await _refreshRecent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Attachment failed. Retry below. $e')));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    try {
      await widget.service.openAttachment(attachment);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open attachment: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reversed = messages.reversed.toList(growable: false);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
          titleSpacing: 0,
          title: Row(children: [
            _Avatar(widget.name),
            const SizedBox(width: 10),
            Flexible(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(widget.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if ((widget.instrument ?? '').isNotEmpty)
                    Text(widget.instrument!,
                        style: Theme.of(context).textTheme.bodySmall),
                ])),
          ]),
          actions: [
            PopupMenuButton<String>(
                itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'lesson', child: Text('Share lesson')),
                      const PopupMenuItem(
                          value: 'piece', child: Text('Share piece')),
                      const PopupMenuItem(
                          value: 'refresh', child: Text('Refresh messages')),
                    ],
                onSelected: (value) => value == 'refresh'
                    ? _refreshRecent()
                    : _shareReference(value))
          ]),
      body: SafeArea(
          child: Column(children: [
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Could not open chat: $error'),
                        TextButton(
                            onPressed: _initialize,
                            child: const Text('Try again'))
                      ]))
                    : Stack(children: [
                        if (messages.isEmpty && pending.isEmpty)
                          const Center(
                              child: Text('No messages yet. Say hello!')),
                        ListView.builder(
                          controller: scroll,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          itemCount: reversed.length +
                              pending.length +
                              (loadingOlder ? 1 : 0),
                          itemBuilder: (_, index) {
                            if (index < pending.length) {
                              final entry = pending.entries
                                  .toList()
                                  .reversed
                                  .elementAt(index);
                              return Align(
                                  alignment: Alignment.centerRight,
                                  child: Card(
                                      child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(entry.value),
                                                const SizedBox(height: 3),
                                                TextButton.icon(
                                                    onPressed: failed
                                                            .contains(entry.key)
                                                        ? () => _send(
                                                            retryId: entry.key)
                                                        : null,
                                                    icon: Icon(failed
                                                            .contains(entry.key)
                                                        ? Icons.refresh
                                                        : Icons.schedule),
                                                    label: Text(failed
                                                            .contains(entry.key)
                                                        ? 'Failed · Retry'
                                                        : 'Sending')),
                                              ]))));
                            }
                            index -= pending.length;
                            if (index >= reversed.length) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final row = reversed[index];
                            final own =
                                row['sender_id'] == widget.service.userId;
                            final time =
                                DateTime.tryParse('${row['created_at']}')
                                    ?.toLocal();
                            final nextOlder = index + 1 < reversed.length
                                ? reversed[index + 1]
                                : null;
                            final olderTime =
                                DateTime.tryParse('${nextOlder?['created_at']}')
                                    ?.toLocal();
                            final separator = time != null &&
                                (olderTime == null ||
                                    time.year != olderTime.year ||
                                    time.month != olderTime.month ||
                                    time.day != olderTime.day);
                            final showTime = separator ||
                                nextOlder?['sender_id'] != row['sender_id'];
                            final attachments =
                                (row['message_attachments'] as List? ??
                                    const []);
                            return Column(children: [
                              if (separator)
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Text(DateFormat.yMMMd().format(time),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall)),
                              Align(
                                alignment: own
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.sizeOf(context).width *
                                                .78),
                                    child: Card(
                                        color: own
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                            : null,
                                        child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if ((row['body'] as String? ??
                                                          '')
                                                      .isNotEmpty)
                                                    Text(row['kind'] == 'lesson'
                                                        ? 'Lesson: ${row['body']}'
                                                        : row['kind'] == 'piece'
                                                            ? 'Piece: ${row['body']}'
                                                            : row['body']
                                                                as String),
                                                  for (final raw in attachments)
                                                    if ('${raw['mime_type']}'
                                                        .startsWith('audio/'))
                                                      _AudioAttachment(
                                                          key: ValueKey(
                                                              raw['id']),
                                                          service:
                                                              widget.service,
                                                          attachment: Map<String, dynamic>.from(
                                                              raw as Map))
                                                    else if (MessagingService.isImage(
                                                        Map<String, dynamic>.from(
                                                            raw as Map)))
                                                      MessageImage(
                                                          key: ValueKey(
                                                              raw['id']),
                                                          service:
                                                              widget.service,
                                                          attachment: Map<String, dynamic>.from(
                                                              raw))
                                                    else
                                                      TextButton.icon(
                                                          onPressed: () => _openAttachment(Map<String, dynamic>.from(raw)),
                                                          icon: const Icon(Icons.attach_file),
                                                          label: Text('${raw['file_name']}')),
                                                  if (attachments.isEmpty &&
                                                      row['kind'] == 'file')
                                                    const Text(
                                                        'Uploading attachment…'),
                                                  if (showTime) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                        '${time == null ? '' : DateFormat.jm().format(time)}${own ? peerReadAt != null && time != null && !time.isAfter(peerReadAt!) ? ' · Read' : ' · Sent' : ''}',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall),
                                                  ],
                                                ])))),
                              ),
                            ]);
                          },
                        ),
                        if (newMessages)
                          Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Center(
                                  child: FilledButton.icon(
                                      onPressed: () {
                                        scroll.animateTo(0,
                                            duration: const Duration(
                                                milliseconds: 250),
                                            curve: Curves.easeOut);
                                      },
                                      icon: const Icon(Icons.arrow_downward),
                                      label: const Text('New messages')))),
                      ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(children: [
              IconButton(
                  onPressed:
                      loading || error != null || uploading ? null : _attach,
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Attach file'),
              IconButton(
                  onPressed: loading || error != null || uploading
                      ? null
                      : _toggleRecording,
                  icon: Icon(recordingNow ? Icons.stop_circle : Icons.mic_none),
                  tooltip: recordingNow ? 'Stop recording' : 'Record audio'),
              IconButton(
                  onPressed: loading || error != null ? null : _chooseEmoji,
                  icon: const Icon(Icons.sentiment_satisfied_alt_outlined),
                  tooltip: 'Choose emoji'),
              Expanded(
                  child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          hintText: 'Message', border: OutlineInputBorder()),
                      onSubmitted: (_) => _send())),
              IconButton(
                  onPressed:
                      controller.text.trim().isEmpty || loading || error != null
                          ? null
                          : () => _send(),
                  icon: const Icon(Icons.send),
                  tooltip: 'Send'),
            ])),
        if (recordingNow)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.fiber_manual_record, color: Colors.red),
                const Text('Recording · 5 minute limit'),
                TextButton(
                    onPressed: _discardRecording, child: const Text('Cancel')),
              ])),
        if (recording != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                IconButton(
                    onPressed: () async {
                      if (previewPlayer.playing) {
                        await previewPlayer.pause();
                      } else {
                        unawaited(previewPlayer.play());
                      }
                      if (mounted) setState(() {});
                    },
                    icon: Icon(
                        previewPlayer.playing ? Icons.pause : Icons.play_arrow),
                    tooltip: 'Preview recording'),
                Expanded(
                    child: Text(
                        'Recording · ${(recordingDurationMs ?? 0) ~/ 1000}s')),
                TextButton(
                    onPressed: uploading ? null : _discardRecording,
                    child: const Text('Discard')),
                TextButton(
                    onPressed: uploading ? null : _sendRecording,
                    child: const Text('Send audio')),
              ])),
        if (uploading) const LinearProgressIndicator(),
        if (failedFile != null && !uploading)
          ListTile(
            title: Text('Upload failed: ${failedFile!.name}'),
            trailing:
                TextButton(onPressed: _retryFile, child: const Text('Retry')),
          ),
      ])),
    );
  }
}

class _AudioAttachment extends StatefulWidget {
  const _AudioAttachment(
      {super.key, required this.service, required this.attachment});
  final MessagingService service;
  final Map<String, dynamic> attachment;

  @override
  State<_AudioAttachment> createState() => _AudioAttachmentState();
}

class _AudioAttachmentState extends State<_AudioAttachment> {
  final player = AudioPlayer();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (player.playing) {
      await player.pause();
      return;
    }
    try {
      if (player.audioSource == null) {
        setState(() => loading = true);
        final path = widget.attachment['storage_path'] as String;
        await player.setUrl(widget.service.authenticatedAudioUrl(path),
            headers: widget.service.audioHeaders);
      }
      unawaited(player.play());
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StreamBuilder<bool>(
            stream: player.playingStream,
            builder: (_, snapshot) => TextButton.icon(
                onPressed: loading ? null : _toggle,
                icon: Icon(
                    snapshot.data == true ? Icons.pause : Icons.play_arrow),
                label: Text(loading ? 'Loading recording…' : 'Voice message'))),
        StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (_, snapshot) {
              final duration = player.duration ??
                  Duration(
                      milliseconds:
                          widget.attachment['duration_ms'] as int? ?? 1);
              final position = snapshot.data ?? Duration.zero;
              return SizedBox(
                  width: 180,
                  child: LinearProgressIndicator(
                      value: (position.inMilliseconds /
                              duration.inMilliseconds.clamp(1, 300000))
                          .clamp(0.0, 1.0)));
            }),
        if (error != null)
          Text('Playback failed: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ]);
}
