import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/screens/messages_screen.dart';
import 'package:maestro_mobile/screens/message_emoji_picker.dart';
import 'package:maestro_mobile/screens/message_image.dart';
import 'package:maestro_mobile/services/messaging_inbox.dart';
import 'package:maestro_mobile/services/messaging_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MessagingFixture extends MessagingService {
  _MessagingFixture()
      : super(SupabaseClient('https://example.invalid', 'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));

  bool failFirst = true;
  final sentClientIds = <String>[];
  final readIds = <String>[];
  void Function(Map<String, dynamic>)? receive;
  List<Map<String, dynamic>>? initialRows;
  int olderLoads = 0;
  List<Map<String, dynamic>> summaryRows = [];
  void Function()? summaryChanged;
  void Function()? summaryConnected;
  bool failSummary = false;

  @override
  Future<List<Map<String, dynamic>>> summaries() async {
    if (failSummary) throw StateError('offline');
    return summaryRows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  RealtimeChannel watchSummaries(
      void Function() onChanged, void Function() onConnected) {
    summaryChanged = onChanged;
    summaryConnected = onConnected;
    return client.channel('fixture-summaries');
  }

  @override
  Future<String> signedImageUrl(String path, {bool thumbnail = true}) async =>
      'https://example.invalid/image.png';

  @override
  String get userId => 'my-user';

  @override
  Future<String> open(String teacherId, String studentId) async => 'room-1';

  @override
  Future<bool> canMessage(String conversationId) async => true;

  @override
  Future<List<Map<String, dynamic>>> messages(String conversationId,
      {DateTime? before, String? beforeId}) async {
    if (before != null) {
      olderLoads++;
      return [
        {
          'id': 'older-1',
          'conversation_id': 'room-1',
          'sender_id': 'peer',
          'kind': 'text',
          'body': 'Older history',
          'created_at': '2026-10-23T15:00:00Z',
          'message_attachments': [],
        }
      ];
    }
    return initialRows ??
        [
          {
            'id': 'old-1',
            'conversation_id': 'room-1',
            'sender_id': 'peer',
            'kind': 'text',
            'body': 'Practice slowly',
            'created_at': '2026-10-24T15:00:00Z',
            'message_attachments': [],
          }
        ];
  }

  @override
  RealtimeChannel watchMessages(
      String conversationId, void Function(Map<String, dynamic>) onMessage) {
    receive = onMessage;
    return client.channel('fixture-messages');
  }

  @override
  RealtimeChannel watchReads(
          String conversationId, void Function() onChanged) =>
      client.channel('fixture-reads');

  @override
  RealtimeChannel watchAttachments(
          String conversationId, void Function() onChanged) =>
      client.channel('fixture-attachments');

  @override
  Future<void> unwatch(RealtimeChannel channel) async {}

  @override
  Future<DateTime?> peerReadAt(String conversationId) async => null;

  @override
  Future<void> markRead(String conversationId, String messageId) async {
    readIds.add(messageId);
  }

  @override
  Future<Map<String, dynamic>> send(
      String conversationId, String clientId, String kind, String body,
      {String? referenceId}) async {
    sentClientIds.add(clientId);
    if (failFirst) {
      failFirst = false;
      throw StateError('offline');
    }
    return {
      'id': 'sent-1',
      'conversation_id': conversationId,
      'sender_id': userId,
      'client_id': clientId,
      'kind': kind,
      'body': body,
      'created_at': '2026-10-24T15:01:00Z',
      'message_attachments': [],
    };
  }
}

void main() {
  test('inbox totals rooms and refreshes on new messages and reconnection',
      () async {
    final fixture = _MessagingFixture();
    fixture.summaryRows = [
      {'id': 'a', 'unreadCount': 2},
      {'id': 'b', 'unreadCount': 1},
    ];
    final inbox = MessagingInbox(fixture)..start();
    await Future<void>.delayed(Duration.zero);
    expect(inbox.unreadCount, 3);
    fixture.summaryRows = [
      {'id': 'a', 'unreadCount': 3},
      {'id': 'b', 'unreadCount': 1},
    ];
    fixture.summaryChanged!();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(inbox.unreadCount, 4);
    fixture.failSummary = true;
    fixture.summaryConnected!();
    await Future<void>.delayed(Duration.zero);
    expect(inbox.unreadCount, 4);
    fixture.failSummary = false;
    fixture.summaryRows = [
      {'id': 'a', 'unreadCount': 0}
    ];
    fixture.summaryConnected!();
    await Future<void>.delayed(Duration.zero);
    expect(inbox.unreadCount, 0);
    inbox.dispose();
  });

  testWidgets('conversation unread badge updates and caps at 99+',
      (tester) async {
    final fixture = _MessagingFixture();
    fixture.summaryRows = [
      {
        'id': 'room-1',
        'teacherId': 'teacher',
        'studentId': 'student',
        'name': 'Aria',
        'lastMessage': 'Hello',
        'unreadCount': 120
      }
    ];
    final inbox = MessagingInbox(fixture)..start();
    await tester.pumpWidget(MaterialApp(
        home: MessagesScreen(client: fixture.client, inbox: inbox)));
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Aria'));
    expect(title.style?.fontWeight, FontWeight.bold);
    fixture.summaryRows = [
      {
        'id': 'room-1',
        'teacherId': 'teacher',
        'studentId': 'student',
        'name': 'Aria',
        'lastMessage': 'Hello',
        'unreadCount': 0
      }
    ];
    fixture.summaryChanged!();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    inbox.dispose();
  });

  test('emoji insertion preserves text and cursor position', () {
    final controller = TextEditingController(text: 'Hello world');
    controller.selection = const TextSelection.collapsed(offset: 6);
    insertMessageEmoji(controller, '🎵');
    insertMessageEmoji(controller, '😀');
    expect(controller.text, 'Hello 🎵😀world');
    expect(controller.selection.baseOffset, 'Hello 🎵😀'.length);
    controller.dispose();
  });

  testWidgets('composer emoji button inserts without replacing draft',
      (tester) async {
    final fixture = _MessagingFixture()..initialRows = [];
    await tester.pumpWidget(MaterialApp(
        home: ChatRoom(
            service: fixture,
            teacherId: 'emoji-teacher',
            studentId: 'emoji-student',
            name: 'Aria')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byTooltip('Choose emoji'));
    await tester.pumpAndSettle();
    expect(find.byType(MessageEmojiPicker), findsOneWidget);
    await tester.tap(find.text('😀'));
    await tester.pumpAndSettle();
    expect(find.text('Hello😀'), findsOneWidget);
  });

  testWidgets('image attachment has a thumbnail and opens zoomable viewer',
      (tester) async {
    final fixture = _MessagingFixture();
    fixture.initialRows = [
      {
        'id': 'image-1',
        'conversation_id': 'room-1',
        'sender_id': 'peer',
        'kind': 'file',
        'body': '',
        'created_at': '2026-10-24T15:00:00Z',
        'message_attachments': [
          {
            'id': 'attachment-1',
            'storage_path': 'room-1/image-1/a.png',
            'mime_type': 'image/png',
            'file_name': 'photo.png',
            'size_bytes': 100
          }
        ],
      }
    ];
    await tester.pumpWidget(MaterialApp(
        home: ChatRoom(
            service: fixture,
            teacherId: 'teacher',
            studentId: 'student',
            name: 'Aria')));
    await tester.pumpAndSettle();
    expect(find.byType(MessageImage), findsOneWidget);
    await tester.tap(find.byType(MessageImage));
    await tester.pumpAndSettle();
    expect(find.byType(MessageImageViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Close image'));
    await tester.pumpAndSettle();
    expect(find.byType(MessageImageViewer), findsNothing);
  });

  testWidgets(
      'chat renders history, retries with one client ID, and keeps a draft',
      (tester) async {
    tester.view.physicalSize = const Size(420, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _MessagingFixture();

    Widget room() => ChatRoom(
        service: fixture,
        teacherId: 'teacher-test-1',
        studentId: 'student-test-1',
        name: 'Aria');
    await tester.pumpWidget(MaterialApp(home: room()));
    await tester.pumpAndSettle();
    expect(find.text('Practice slowly'), findsOneWidget);
    expect(fixture.readIds, contains('old-1'));

    await tester.enterText(find.byType(TextField), 'Hello Aria');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(fixture.sentClientIds, hasLength(1));
    expect(find.text('Failed · Retry'), findsOneWidget);
    await tester.tap(find.text('Failed · Retry'));
    await tester.pumpAndSettle();
    expect(fixture.sentClientIds.length, 2);
    expect(fixture.sentClientIds[0], fixture.sentClientIds[1]);
    expect(find.text('Hello Aria'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Unsent draft');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(MaterialApp(home: room()));
    await tester.pumpAndSettle();
    expect(find.text('Unsent draft'), findsOneWidget);
  });

  testWidgets('older pages load lazily and incoming messages respect scroll',
      (tester) async {
    tester.view.physicalSize = const Size(420, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _MessagingFixture();
    fixture.initialRows = List.generate(
        40,
        (index) => {
              'id': 'm-$index',
              'conversation_id': 'room-1',
              'sender_id': 'peer',
              'kind': 'text',
              'body': 'Message $index',
              'created_at':
                  DateTime.utc(2026, 10, 24, 15, 0, index).toIso8601String(),
              'message_attachments': [],
            });
    await tester.pumpWidget(MaterialApp(
        home: ChatRoom(
            service: fixture,
            teacherId: 'teacher-test-2',
            studentId: 'student-test-2',
            name: 'Aria')));
    await tester.pumpAndSettle();
    expect(fixture.olderLoads, 0);
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(fixture.olderLoads, 1);
    final readsBefore = fixture.readIds.length;

    fixture.receive!({
      'id': 'new-1',
      'conversation_id': 'room-1',
      'sender_id': 'peer',
      'kind': 'text',
      'body': 'New while reading',
      'created_at': '2026-10-24T16:00:00Z',
    });
    await tester.pump();
    expect(find.text('New messages'), findsOneWidget);
    expect(fixture.readIds.length, readsBefore);
    await tester.tap(find.text('New messages'));
    await tester.pumpAndSettle();
    expect(fixture.readIds, contains('new-1'));
  });
}
