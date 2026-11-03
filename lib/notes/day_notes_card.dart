import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/day_sections.dart';
import 'day_notes.dart';

/// "Ghi chú & việc cần làm" for the selected day: a free-text note (saved as you type) and a checklist.
class DayNotesCard extends StatefulWidget {
  const DayNotesCard({super.key, required this.date});

  final DateTime date;

  @override
  State<DayNotesCard> createState() => _DayNotesCardState();
}

class _DayNotesCardState extends State<DayNotesCard> {
  final _note = TextEditingController();
  final _todo = TextEditingController();
  Timer? _save;
  late NotesStore _store;
  late DateTime _shown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = NotesScope.of(context);
  }

  @override
  void initState() {
    super.initState();
    _shown = widget.date;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _note.text = _store.noteOf(_shown);
    });
  }

  @override
  void didUpdateWidget(DayNotesCard old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date) {
      _flush(); // keep what was typed for the previous day
      _shown = widget.date;
      _note.text = _store.noteOf(_shown);
    }
  }

  void _flush() {
    if (_save?.isActive ?? false) {
      _save!.cancel();
      _store.setNote(_shown, _note.text);
    }
  }

  @override
  void dispose() {
    _flush();
    _note.dispose();
    _todo.dispose();
    super.dispose();
  }

  void _addTodo() {
    _store.addTodo(widget.date, _todo.text);
    _todo.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final todos = _store.todosOf(widget.date);
    final left = todos.where((t) => !t.done).length;
    return SectionCard(
      icon: Icons.edit_note_rounded,
      title: 'Ghi chú & việc cần làm',
      trailing: todos.isEmpty
          ? null
          : Text(
              left == 0 ? 'Xong hết' : 'Còn $left việc',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (text) {
              _save?.cancel();
              final day = _shown;
              _save = Timer(const Duration(milliseconds: 600), () => _store.setNote(day, text));
            },
            decoration: InputDecoration(
              hintText: 'Ghi chú cho ngày này…',
              filled: true,
              fillColor: scheme.surfaceContainer,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          for (final t in todos)
            Row(
              children: [
                Checkbox(value: t.done, onChanged: (_) => _store.toggle(t)),
                Expanded(
                  child: Text(
                    t.text,
                    style: TextStyle(
                      decoration: t.done ? TextDecoration.lineThrough : null,
                      color: t.done ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Xoá việc',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _store.removeTodo(t),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _todo,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _addTodo(),
                  decoration: const InputDecoration(hintText: 'Thêm việc cần làm…', isDense: true),
                ),
              ),
              IconButton(tooltip: 'Thêm việc', onPressed: _addTodo, icon: const Icon(Icons.add_task_rounded)),
            ],
          ),
        ],
      ),
    );
  }
}
