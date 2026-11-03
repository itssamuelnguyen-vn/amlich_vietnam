import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../astro/sun_moon_card.dart';
import '../counters/counter.dart';
import '../data/backup.dart';
import '../data/people.dart';
import '../data/settings.dart';
import '../events/event_store.dart';
import '../notes/day_notes.dart';
import '../lunar/format.dart';
import '../sync/google_sync.dart';
import '../widget/widget_bridge.dart';
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: const Text('Thành phố'),
                  subtitle: const Text('Cho giờ mặt trời, mặt trăng và thời tiết'),
                  trailing: Text(currentCity(s).name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => pickCity(context),
                ),
                const SizedBox(height: 8),
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
          const _GoogleSyncCard(),
          const SizedBox(height: 16),
          const _RemindersCard(),
          const SizedBox(height: 16),
          SectionCard(
            icon: Icons.hourglass_bottom_rounded,
            title: 'Widget đếm ngược',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int?>(
                  // Rebuilt when the setting changes elsewhere (e.g. a restore).
                  key: ValueKey(s.countdownEventId),
                  initialValue: EventScope.of(context).events.any((e) => e.id == s.countdownEventId)
                      ? s.countdownEventId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Đếm ngược tới',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tết Nguyên đán')),
                    for (final e in EventScope.of(context).events)
                      DropdownMenuItem(
                        value: e.id,
                        child: Text(e.title, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) => store.update(s.copyWith(countdownEventId: () => id)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Thêm widget "Đếm ngược": nhấn giữ chỗ trống trên màn hình chính, chọn Tiện ích (Widgets), rồi chọn Âm lịch.',
                  style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant),
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
    final counters = CounterScope.of(context).counters;
    final notes = NotesScope.of(context);
    final settings = SettingsScope.of(context).value;
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final name = 'amlich-saoluu-${now.year}${two(now.month)}${two(now.day)}.json';
    try {
      final saved = await FilePicker.saveText(
        name,
        Backup.encode(
          BackupData(
            events: events,
            people: people,
            counters: counters,
            notes: notes.notes,
            todos: notes.todos,
            settings: settings,
          ),
        ),
      );
      if (saved) messenger.showSnackBar(SnackBar(content: Text('Đã sao lưu ${events.length} sự kiện vào $name')));
    } on PlatformException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Không lưu được file: ${e.message}')));
    }
  }

  Future<void> _import(BuildContext context) async {
    final events = EventScope.of(context);
    final people = PeopleScope.of(context);
    final counters = CounterScope.of(context);
    final notes = NotesScope.of(context);
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
          'File có ${data.events.length} sự kiện, ${data.counters.length} bộ đếm ngày và ${data.people.length} người '
          'trong mục Cả nhà.\n\n'
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
    await counters.import(data.counters, replace: replace);
    await notes.import(data.notes, data.todos, replace: replace);
    // Event and calendar ids are specific to this phone, so the countdown target and the synced calendar are not restored.
    if (replace && data.settings != null) {
      await settings.update(
        data.settings!.copyWith(
          countdownEventId: () => null,
          counterWidgetId: () => null,
          googleCalendarId: () => settings.value.googleCalendarId,
          googleCalendarName: settings.value.googleCalendarName,
        ),
      );
    }
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

class _RemindersCard extends StatefulWidget {
  const _RemindersCard();

  @override
  State<_RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends State<_RemindersCard> with WidgetsBindingObserver {
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the phone's settings may have changed the permission.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final enabled = await WidgetBridge.notificationsEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _request() async {
    final enabled = await WidgetBridge.requestNotificationPermission();
    if (mounted) setState(() => _enabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final store = SettingsScope.of(context);
    final s = store.value;
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      icon: Icons.notifications_outlined,
      title: 'Nhắc nhở',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_enabled)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.notifications_off_outlined, color: scheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Thông báo đang bị tắt nên sẽ không có nhắc nhở.',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                  TextButton(onPressed: _request, child: const Text('Bật')),
                ],
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Giờ nhắc'),
            subtitle: const Text('Áp dụng cho mọi nhắc nhở'),
            trailing: Text(
              '${two(s.reminderHour)}:${two(s.reminderMinute)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
              );
              if (t != null) await store.update(s.copyWith(reminderHour: t.hour, reminderMinute: t.minute));
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.brightness_3_outlined),
            title: const Text('Nhắc trước mùng 1 và rằm'),
            subtitle: const Text('Thông báo vào hôm trước, để kịp chuẩn bị hương hoa'),
            value: s.lunarReminders,
            onChanged: (on) async {
              await store.update(s.copyWith(lunarReminders: on));
              if (on) await _request();
            },
          ),
          Text(
            'Mỗi sự kiện chọn nhắc trước bao nhiêu ngày ngay trong màn hình sửa sự kiện.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _GoogleSyncCard extends StatelessWidget {
  const _GoogleSyncCard();

  /// Asks for the calendar permission, then lets the user pick the calendar to sync into.
  Future<void> _choose(BuildContext context) async {
    final sync = GoogleSyncScope.of(context);
    final settings = SettingsScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await sync.requestPermission()) {
      messenger.showSnackBar(const SnackBar(content: Text('Cần quyền truy cập lịch để đồng bộ')));
      return;
    }
    final calendars = await sync.calendars();
    if (!context.mounted) return;
    if (calendars.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không thấy lịch nào. Hãy đăng nhập tài khoản Google trên điện thoại trước.')),
      );
      return;
    }
    final chosen = await showDialog<PhoneCalendar>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Đồng bộ vào lịch nào?'),
        children: [
          for (final c in calendars)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c),
              child: Row(
                children: [
                  CircleAvatar(radius: 7, backgroundColor: Color(c.color | 0xFF000000)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          c.isGoogle ? c.account : '${c.account} (chỉ trên máy)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await settings.update(settings.value.copyWith(googleCalendarId: () => chosen.id, googleCalendarName: chosen.label));
  }

  Future<void> _disable(BuildContext context) async {
    final sync = GoogleSyncScope.of(context);
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tắt đồng bộ?'),
        content: const Text('Có xoá các sự kiện app đã thêm vào Google Calendar không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Giữ lại')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (remove == null) return;
    await sync.disable(removeEvents: remove);
  }

  @override
  Widget build(BuildContext context) {
    final sync = GoogleSyncScope.of(context);
    final s = SettingsScope.of(context).value;
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    final result = sync.lastResult;
    final last = sync.lastSync;
    return SectionCard(
      icon: Icons.sync_rounded,
      title: 'Đồng bộ Google Calendar',
      child: !sync.enabled
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ghi sự kiện của app vào Google Calendar qua tài khoản Google trên điện thoại, để xem được trên '
                  'máy tính và các thiết bị khác. Sự kiện lặp theo âm lịch được ghi từng ngày cho ${GoogleSync.horizonYears} '
                  'năm tới và tự cập nhật khi bạn sửa trong app.',
                  style: muted,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _choose(context),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Bật đồng bộ'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: Text(s.googleCalendarName.isEmpty ? 'Lịch đã chọn' : s.googleCalendarName),
                  subtitle: Text(
                    sync.syncing
                        ? 'Đang đồng bộ…'
                        : sync.lastError != null
                        ? 'Lỗi: ${sync.lastError}'
                        : last == null
                        ? 'Chưa đồng bộ'
                        : 'Đồng bộ lúc ${two(last.hour)}:${two(last.minute)}'
                              '${result == null ? '' : ' · thêm ${result.added}, sửa ${result.changed}, xoá ${result.removed}'}',
                    style: TextStyle(color: sync.lastError != null ? scheme.error : null),
                  ),
                  trailing: sync.syncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          tooltip: 'Đồng bộ ngay',
                          onPressed: sync.syncNow,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                ),
                Text('Tự đồng bộ mỗi khi bạn thêm, sửa hoặc xoá sự kiện.', style: muted),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => _choose(context), child: const Text('Đổi lịch')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(onPressed: () => _disable(context), child: const Text('Tắt đồng bộ')),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
