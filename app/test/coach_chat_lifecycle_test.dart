import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/coach_chat.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

// Coach chat while something is on its way: a reply belongs to the chat it was asked in, and a chat that is being
// deleted takes no new messages.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime.now().toIso8601String();

  // In-memory chats; each send and delete waits for the test to finish it.
  ({CoachApi api, List<Map<String, dynamic>> sent, List<String> deleted, List<Completer<Map>> replies, List<Completer<void>> deletes}) fake() {
    final sent = <Map<String, dynamic>>[];
    final deleted = <String>[];
    final replies = <Completer<Map>>[];
    final deletes = <Completer<void>>[];
    final CoachApi api = (
      boot: () async => ('Asha', <dynamic>[
            {'id': 't1', 'title': 'Knee pain', 'updated_at': now},
            {'id': 't2', 'title': 'Meal ideas', 'updated_at': now},
          ]),
      messages: (id) async => <dynamic>[
            {'id': 1, 'role': 'user', 'content': 'Question in $id'},
            {'id': 2, 'role': 'assistant', 'content': 'Answer in $id'},
          ],
      send: (body) {
        sent.add(body);
        final c = Completer<Map>();
        replies.add(c);
        return c.future;
      },
      deleteThread: (id) {
        deleted.add(id);
        final c = Completer<void>();
        deletes.add(c);
        return c.future;
      },
    );
    return (api: api, sent: sent, deleted: deleted, replies: replies, deletes: deletes);
  }

  // A few frames: enough for the drawer, snack bars and dialogs to move, while the typing dots keep animating.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> show(WidgetTester tester, CoachApi api) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: CoachScreen(api: api)));
    await settle(tester);
  }

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Your chats'));
    await settle(tester);
  }

  Future<void> openChat(WidgetTester tester, String title) async {
    await openDrawer(tester);
    await tester.tap(find.text(title));
    await settle(tester);
  }

  Future<void> deleteChat(WidgetTester tester, int index) async {
    await openDrawer(tester);
    await tester.tap(find.byTooltip('Delete chat').at(index));
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  Future<void> tapSend(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
  }

  IconButton sendButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.ancestor(of: find.byTooltip('Send'), matching: find.byType(IconButton)).first);

  Map reply(String threadId) => {'reply': 'Here is the answer', 'threadId': threadId, 'title': null, 'userMessageId': 3, 'assistantMessageId': 4};

  testWidgets('switching chats while a reply is on its way is refused; the reply lands in the chat it was asked in', (tester) async {
    final f = fake();
    await show(tester, f.api);
    await openChat(tester, 'Knee pain');
    await type(tester, 'Can I squat?');
    await tapSend(tester);
    expect(f.sent.single['threadId'], 't1');

    await openChat(tester, 'Meal ideas');
    expect(find.text('Wait for Levlofit AI to finish replying first.'), findsOneWidget);
    expect(find.text('Answer in t2'), findsNothing);
    expect(find.text('Can I squat?'), findsOneWidget);

    f.replies.single.complete(reply('t1'));
    await settle(tester);
    expect(find.text('Answer in t1'), findsOneWidget);
    expect(find.text('Can I squat?'), findsOneWidget);

    await openChat(tester, 'Meal ideas'); // the reply is in: switching works again
    expect(find.text('Answer in t2'), findsOneWidget);
    expect(find.text('Can I squat?'), findsNothing);
  });

  testWidgets('a second message while a reply is on its way is not sent', (tester) async {
    final f = fake();
    await show(tester, f.api);
    await type(tester, 'First');
    await tapSend(tester);
    await type(tester, 'Second');
    expect(sendButton(tester).onPressed, isNull);
    await tester.tap(find.byTooltip('Send'), warnIfMissed: false);
    await tester.pump();
    expect(f.sent, hasLength(1));
    f.replies.single.complete(reply('new1'));
    await settle(tester);
  });

  testWidgets('deleting the current chat while a reply is on its way is refused; another chat can be deleted', (tester) async {
    final f = fake();
    await show(tester, f.api);
    await openChat(tester, 'Knee pain');
    await type(tester, 'Can I squat?');
    await tapSend(tester);

    await deleteChat(tester, 0); // Knee pain, the current chat
    expect(find.text('Wait for Levlofit AI to finish replying first.'), findsOneWidget);
    expect(f.deleted, isEmpty);

    await tester.tap(find.byTooltip('Delete chat').at(1)); // Meal ideas
    await tester.pump();
    expect(f.deleted, ['t2']);
    f.deletes.single.complete();
    await settle(tester);
    expect(find.text('Meal ideas'), findsNothing);

    f.replies.single.complete(reply('t1'));
    await settle(tester);
  });

  testWidgets('while the current chat is being deleted nothing can be sent into it; afterwards a new chat opens', (tester) async {
    final f = fake();
    await show(tester, f.api);
    await openChat(tester, 'Knee pain');
    await deleteChat(tester, 0);
    expect(f.deleted, ['t1']);
    Navigator.of(tester.element(find.byType(Drawer))).pop();
    await settle(tester);

    await type(tester, 'Still there?');
    expect(sendButton(tester).onPressed, isNull);
    await tester.tap(find.byTooltip('Send'), warnIfMissed: false);
    await tester.pump();
    expect(f.sent, isEmpty);

    await tester.tap(find.byTooltip('Regenerate')); // edit and regenerate reach the send guard too
    await settle(tester);
    expect(find.text('This chat is being deleted. Start a new chat to send a message.'), findsOneWidget);
    expect(f.sent, isEmpty);

    await deleteChat(tester, 1); // a second deletion waits for the first, and says so
    expect(f.deleted, ['t1']);
    await settle(tester);
    expect(find.text('Wait until the chat is deleted.'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Knee pain'))); // nor can the chat being deleted be opened again
    await settle(tester);
    expect(find.text('Wait until the chat is deleted.'), findsWidgets);
    expect(find.byType(Drawer), findsNothing);

    f.deletes.single.complete();
    await settle(tester);
    expect(find.text('New chat'), findsOneWidget); // the app bar title
    expect(find.text('Answer in t1'), findsNothing);
    await type(tester, 'Fresh start');
    await tapSend(tester);
    expect(f.sent.single.containsKey('threadId'), isFalse);
    f.replies.single.complete(reply('t9'));
    await settle(tester);
  });

  testWidgets('a failed deletion says so and the chat can be used again', (tester) async {
    final f = fake();
    await show(tester, f.api);
    await openChat(tester, 'Knee pain');
    await deleteChat(tester, 0);
    f.deletes.single.completeError(Exception('offline'));
    await settle(tester);
    expect(find.text('Could not delete that chat.'), findsOneWidget);
    Navigator.of(tester.element(find.byType(Drawer))).pop();
    await settle(tester);
    await type(tester, 'Still here');
    await tapSend(tester);
    expect(f.sent.single['threadId'], 't1');
    f.replies.single.complete(reply('t1'));
    await settle(tester);
  });

  testWidgets('a deletion that finishes after the chat was closed does not touch the closed screen', (tester) async {
    final f = fake();
    await show(tester, f.api);
    await openChat(tester, 'Knee pain');
    await deleteChat(tester, 0);
    await tester.pumpWidget(const MaterialApp(home: Text('closed')));
    f.deletes.single.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an error reply offers Try again with the same message id, so a saved turn is returned, not answered twice', (tester) async {
    final f = fake();
    await show(tester, f.api);
    await type(tester, 'How many sets?');
    await tapSend(tester);
    f.replies.single.completeError(const FunctionException(status: 409, details: {'error': 'This message was already answered. Try again to load the reply.', 'saved': true, 'duplicate': true}));
    await settle(tester);
    expect(find.text('This message was already answered. Try again to load the reply.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(f.sent, hasLength(2));
    expect(f.sent[1]['clientMsgId'], f.sent[0]['clientMsgId']);
    expect(f.sent[1]['message'], 'How many sets?');
    f.replies[1].complete(reply('t5'));
    await settle(tester);
    expect(find.text('How many sets?'), findsOneWidget); // the message is shown once, not twice
  });

  testWidgets('a saved message whose reply is gone is retried under a new message id', (tester) async {
    final f = fake();
    await show(tester, f.api);
    await type(tester, 'How many sets?');
    await tapSend(tester);
    f.replies.single.completeError(const FunctionException(status: 409, details: {
      'error': 'This message has no saved reply. Send it again as a new message.', 'saved': true, 'duplicate': true, 'replyMissing': true}));
    await settle(tester);
    expect(find.text('This message has no saved reply. Send it again as a new message.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(f.sent, hasLength(2));
    expect(f.sent[1]['clientMsgId'], isNot(f.sent[0]['clientMsgId']));
    f.replies[1].complete(reply('t6'));
    await settle(tester);
  });
}
