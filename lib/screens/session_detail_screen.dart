import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../temperature.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SessionDetailScreen extends StatelessWidget {
  final CheckSession session;
  final bool justSaved;
  const SessionDetailScreen({super.key, required this.session, this.justSaved = false});

  @override
  Widget build(BuildContext context) {
    final scale = AppState.instance.settings.scale;
    final st = session.status;
    return Scaffold(
      appBar: AppBar(title: Text(justSaved ? 'Check saved' : 'Check details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (justSaved)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: Brand.headerGradient, borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Brand.mint,
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Temperatures recorded',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(fmtDateTime(session.takenAt), style: const TextStyle(color: Colors.white70)),
                    ]),
                  ),
                ]),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(fmtDate(session.takenAt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Recorded at ${fmtTime(session.takenAt)}', style: const TextStyle(color: Brand.muted)),
                      if (session.checkedBy.isNotEmpty)
                        Text('Checked by ${session.checkedBy}', style: const TextStyle(color: Brand.muted)),
                    ]),
                  ),
                  StatusChip(st, label: st == TempStatus.ok ? 'All OK' : '${session.issues} issue${session.issues == 1 ? '' : 's'}'),
                ]),
              ),
            ),
            const SectionLabel('Readings'),
            Card(
              child: Column(children: [
                for (var i = 0; i < session.readings.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
                  _ReadingTile(r: session.readings[i], scale: scale),
                ],
              ]),
            ),
            if (justSaved) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  final Reading r;
  final TempScale scale;
  const _ReadingTile({required this.r, required this.scale});
  @override
  Widget build(BuildContext context) {
    final a = assess(r.unitType, r.tempC, scale);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(r.unitType.icon, color: Brand.iceDeep, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(r.unitName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
          Text(formatTemp(r.tempC, scale),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: r.status == TempStatus.ok ? Brand.ink : r.status.color)),
          const SizedBox(width: 8),
          Icon(r.status.icon, color: r.status.color, size: 20),
        ]),
        if (r.status != TempStatus.ok) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(a.title, style: TextStyle(color: r.status.color, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 2),
            child: Text('Action: ${r.action.isEmpty ? 'Not recorded' : r.action}',
                style: const TextStyle(color: Brand.muted, fontSize: 13)),
          ),
        ],
      ]),
    );
  }
}
