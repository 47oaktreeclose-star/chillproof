import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../legal.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  IconData _icon(String key) => switch (key) {
        'fridge' => Icons.kitchen_rounded,
        'freezer' => Icons.ac_unit_rounded,
        'check' => Icons.fact_check_rounded,
        'hse' => Icons.health_and_safety_rounded,
        'fgas' => Icons.eco_rounded,
        _ => Icons.info_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food safety rules')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: Brand.headerGradient, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                _Limit(label: 'Fridges', value: '≤ 8°C', note: 'by law*\naim for ≤ 5°C'),
                SizedBox(width: 12),
                _Limit(label: 'Freezers', value: '≤ -18°C', note: 'or colder'),
              ]),
              const SizedBox(height: 12),
              Text('*England, Wales & Northern Ireland. Recommended in Scotland.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 16),
          const Text(legalIntro, style: TextStyle(height: 1.5, fontSize: 15)),
          const SizedBox(height: 8),
          for (final s in legalSections) ...[
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                initiallyExpanded: s == legalSections.first,
                leading: Icon(_icon(s.icon), color: Brand.iceDeep),
                title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                shape: const Border(),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final p in s.points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 7, right: 10),
                          child: CircleAvatar(radius: 3, backgroundColor: Brand.iceDeep),
                        ),
                        Expanded(child: Text(p, style: const TextStyle(height: 1.45))),
                      ]),
                    ),
                  for (final l in s.links)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                      onPressed: () => launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(l.label),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          const InfoBanner(
            icon: Icons.info_outline_rounded,
            text: legalDisclaimer,
            color: Brand.muted,
            tint: Color(0xFFEFF3F7),
          ),
        ],
      ),
    );
  }
}

class _Limit extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  const _Limit({required this.label, required this.value, required this.note});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(color: Colors.white, fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 26)),
            Text(note, style: const TextStyle(color: Color(0xFF5ED3F3), fontSize: 12.5)),
          ]),
        ),
      );
}
