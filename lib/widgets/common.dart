import 'package:flutter/material.dart';

import '../temperature.dart';
import '../theme.dart';

// ---------------------------------------------------------------- dates

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String two(int n) => n.toString().padLeft(2, '0');
String fmtTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String fmtDateShort(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
String fmtDayDate(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
String fmtDateTime(DateTime d) => '${fmtDate(d)}, ${fmtTime(d)}';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

// ---------------------------------------------------------------- widgets

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 72});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset('assets/images/logo.png', width: size, height: size),
      );
}

class Wordmark extends StatelessWidget {
  final double size;
  final bool onDark;
  const Wordmark({super.key, this.size = 28, this.onDark = false});
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Chill', style: TextStyle(color: onDark ? Colors.white : Brand.navy)),
          TextSpan(text: 'Proof', style: TextStyle(color: onDark ? const Color(0xFF5ED3F3) : Brand.iceDeep)),
        ]),
        style: TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: size, letterSpacing: -0.5),
      );
}

class StatusChip extends StatelessWidget {
  final TempStatus status;
  final String? label;
  const StatusChip(this.status, {super.key, this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: status.tint, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(status.icon, size: 16, color: status.color),
          const SizedBox(width: 4),
          Text(label ?? status.label,
              style: TextStyle(color: status.color, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
      );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: Brand.muted)),
      );
}

class StepHeader extends StatelessWidget {
  final int step;
  final int of;
  final String title;
  final String subtitle;
  const StepHeader({super.key, required this.step, required this.of, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 1; i <= of; i++)
            Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(right: i == of ? 0 : 6),
                decoration: BoxDecoration(
                  color: i <= step ? Brand.iceDeep : Brand.line,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 20),
        Text('Step $step of $of', style: const TextStyle(color: Brand.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Brand.muted, fontSize: 15, height: 1.4)),
      ]);
}

class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color tint;
  const InfoBanner({super.key, required this.icon, required this.text, this.color = Brand.iceDeep, this.tint = const Color(0xFFE6F6FD)});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: Brand.ink.withValues(alpha: 0.85), height: 1.4))),
        ]),
      );
}

void showSnack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

Future<String?> promptText(BuildContext context,
    {required String title, String initial = '', String hint = '', String action = 'Save'}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
}
