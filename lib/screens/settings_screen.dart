import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/backup.dart';
import '../data/people.dart';
import '../data/settings.dart';
import '../events/event_store.dart';
import '../lunar/format.dart';
import '../widgets/day_sections.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = SettingsScope.of(context);
    final s = store.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SectionCard(
            icon: Icons.palette_outlined,
            title: 'Giao diện',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Label('Chế độ màu'),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('Theo máy')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Sáng'), icon: Icon(Icons.light_mode_outlined)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Tối'), icon: Icon(Icons.dark_mode_outlined)),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => store.update(s.copyWith(themeMode: v.first)),
                ),
                const SizedBox(height: 16),
                const _Label('Cỡ chữ'),
                SegmentedButton<double>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 1.0, label: Text('Vừa')),
                    ButtonSegment(value: 1.15, label: Text('Lớn')),
                    ButtonSegment(value: 1.3, label: Text('Rất lớn')),
                  ],
                  selected: {s.textScale},
                  onSelectionChanged: (v) => store.update(s.copyWith(textScale: v.first)),
                ),
                const SizedBox(height: 16),
                const _Label('Tuần bắt đầu từ'),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: true, label: Text('Thứ Hai')),
                    ButtonSegment(value: false, label: Text('Chủ Nhật')),
                  ],
                  selected: {s.weekStartsMonday},
                  onSelectionChanged: (v) => store.update(s.copyWith(weekStartsMonday: v.first)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            icon: Icons.celebration_outlined,
            title: 'Ngày lễ hiển thị',
            child: Column(
              children: [
                for (final kind in HolidayKind.values)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(kind.label),
                    subtitle: Text(kind.examples),
                    value: s.holidayKinds.contains(kind),
                    onChanged: (on) => store.update(
                      s.copyWith(holidayKinds: on ? {...s.holidayKinds, kind} : ({...s.holidayKinds}..remove(kind))),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _BackupCard(),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Âm lịch Việt Nam · lịch tính theo thuật toán Hồ Ngọc Đức (UTC+7)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
  );
}

enum _ImportMode { merge, replace }

class _BackupCard extends StatelessWidget {
  const _BackupCard();

  Future<void> _export(BuildContext context) async {
    final events = EventScope.of(context).events;
    final people = PeopleScope.of(context).people;
    final settings = SettingsScope.of(context).value;
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final name = 'amlich-saoluu-${now.year}${two(now.month)}${two(now.day)}.json';
    try {
      final saved = await FilePicker.saveText(
        name,
        Backup.encode(BackupData(events: events, people: people, settings: settings)),
      );
      if (saved) messenger.showSnackBar(SnackBar(content: Text('Đã sao lưu ${events.length} sự kiện vào $name')));
    } on PlatformException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Không lưu được file: ${e.message}')));
    }
  }

  Future<void> _import(BuildContext context) async {
    final events = EventScope.of(context);
    final people = PeopleScope.of(context);
    final settings = SettingsScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final BackupData data;
    try {
      final text = await FilePicker.openText();
      if (text == null) return;
      data = Backup.decode(text);
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } on PlatformException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Không đọc được file: ${e.message}')));
      return;
    }
    if (!context.mounted) return;
    final mode = await showDialog<_ImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục dữ liệu'),
        content: Text(
          'File có ${data.events.length} sự kiện và ${data.people.length} người trong mục tuổi cả nhà.\n\n'
          '• Thêm vào: giữ dữ liệu hiện có, bỏ qua mục trùng.\n'
          '• Thay thế: xoá dữ liệu hiện có, khôi phục cả cài đặt.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(context, _ImportMode.replace), child: const Text('Thay thế')),
          FilledButton(onPressed: () => Navigator.pop(context, _ImportMode.merge), child: const Text('Thêm vào')),
        ],
      ),
    );
    if (mode == null) return;
    final replace = mode == _ImportMode.replace;
    final added = await events.import(data.events, replace: replace, key: Backup.eventKey);
    await people.import(data.people, replace: replace);
    // Event ids change on import, so the countdown target cannot be carried over.
    if (replace && data.settings != null) await settings.update(data.settings!.copyWith(countdownEventId: () => null));
    messenger.showSnackBar(SnackBar(content: Text('Đã khôi phục $added sự kiện')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      icon: Icons.backup_outlined,
      title: 'Sao lưu & khôi phục',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sự kiện chỉ lưu trên máy này. Hãy sao lưu ra file (chọn Google Drive hoặc bộ nhớ máy) để không mất khi '
            'đổi điện thoại hay cài lại app.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _export(context),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Sao lưu ra file'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _import(context),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Khôi phục từ file'),
          ),
        ],
      ),
    );
  }
}
