import 'package:amlich_vietnam/data/backup.dart';
import 'package:amlich_vietnam/notes/day_notes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('notes and to-dos per day, with a calendar marker', () async {
    final store = NotesStore(MemoryNotesBackend());
    await store.load();
    final d = DateTime(2026, 11, 3);
    expect(store.hasContent(d), isFalse);
    await store.setNote(d, '  Đi chợ mua hoa  ');
    expect(store.noteOf(d), 'Đi chợ mua hoa');
    await store.addTodo(d, 'Mua nhang');
    await store.addTodo(d, '   ');
    expect(store.todosOf(d), hasLength(1));
    await store.toggle(store.todosOf(d).single);
    expect(store.todosOf(d).single.done, isTrue);
    expect(store.hasContent(d), isTrue);
    await store.setNote(d, '');
    await store.removeTodo(store.todosOf(d).single);
    expect(store.hasContent(d), isFalse);
  });

  test('backup round trip merges notes and skips duplicate to-dos', () async {
    final text = Backup.encode(
      const BackupData(
        events: [],
        people: [],
        notes: {'2026-11-03': 'Ghi chú'},
        todos: [Todo(date: '2026-11-03', text: 'Việc A', done: true)],
      ),
    );
    final data = Backup.decode(text);
    final store = NotesStore(MemoryNotesBackend());
    await store.load();
    await store.import(data.notes, data.todos, replace: false);
    await store.import(data.notes, data.todos, replace: false);
    expect(store.noteOf(DateTime(2026, 11, 3)), 'Ghi chú');
    expect(store.todos.single.done, isTrue);
  });

  testWidgets('write a note and a to-do on the calendar', (tester) async {
    usePhoneScreen(tester);
    final app = await testApp();
    await tester.pumpWidget(app);
    await tester.dragUntilVisible(
      find.text('Ghi chú & việc cần làm'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ghi chú cho ngày này…'), 'Cúng rằm');
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.widgetWithText(TextField, 'Thêm việc cần làm…'), 'Mua hoa');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(app.notes.noteOf(now), 'Cúng rằm');
    expect(app.notes.todosOf(now).single.text, 'Mua hoa');
    expect(find.text('Còn 1 việc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
