import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../temperature.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'email_log_screen.dart';
import 'session_detail_screen.dart';

enum RecordRange { week, month, ninety, all }

extension RecordRangeX on RecordRange {
  String get label => switch (this) {
        RecordRange.week => '7 days',
        RecordRange.month => '30 days',
        RecordRange.ninety => '90 days',
        RecordRange.all => 'All',
      };
  DateTime? get from {
    final today = startOfDay(DateTime.now());
    return switch (this) {
      RecordRange.week => today.subtract(const Duration(days: 6)),
      RecordRange.month => today.subtract(const Duration(days: 29)),
      RecordRange.ninety => today.subtract(const Duration(days: 89)),
      RecordRange.all => null,
    };
  }
}

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  RecordRange _range = RecordRange.week;
  List<CheckSession>? _sessions;
  bool _issuesOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppDb.instance.sessions(from: _range.from);
    if (mounted) setState(() => _sessions = list);
  }

  @override
  Widget build(BuildContext context) {
    final scale = AppState.instance.settings.scale;
    final list = (_sessions ?? []).where((s) => !_issuesOnly || s.status != TempStatus.ok).toList();
    // Group by day.
    final groups = <DateTime, List<CheckSession>>{};
    for (final s in list) {
      groups.putIfAbsent(startOfDay(s.takenAt), () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Records'),
        actions: [
          IconButton(
            tooltip: 'Email log',
            icon: const Icon(Icons.mark_email_unread_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailLogScreen())),
          ),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final r in RecordRange.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(r.label),
                    selected: _range == r,
                    onSelected: (_) {
                      setState(() {
                        _range = r;
                        _sessions = null;
                      });
                      _load();
                    },
                  ),
                ),
              FilterChip(
                label: const Text('Issues only'),
                selected: _issuesOnly,
                onSelected: (v) => setState(() => _issuesOnly = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: _sessions == null
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _issuesOnly ? 'No out-of-range readings in this period.' : 'No checks recorded in this period.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Brand.muted),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          for (final day in groups.keys) ...[
                            SectionLabel(fmtDayDate(day)),
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(children: [
                                for (var i = 0; i < groups[day]!.length; i++) ...[
                                  if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
                                  _SessionTile(
                                    session: groups[day]![i],
                                    scale: scale,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => SessionDetailScreen(session: groups[day]![i])),
                                    ),
                                  ),
                                ],
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final CheckSession session;
  final TempScale scale;
  final VoidCallback onTap;
  const _SessionTile({required this.session, required this.scale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final st = session.status;
    final summary = session.readings.map((r) => '${r.unitName} ${formatTemp(r.tempC, scale)}').join(' · ');
    return ListTile(
      onTap: onTap,
      leading: Text(fmtTime(session.takenAt),
          style: const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 17)),
      title: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
      subtitle: session.checkedBy.isEmpty ? null : Text('Checked by ${session.checkedBy}'),
      trailing: Icon(st.icon, color: st.color),
    );
  }
}
