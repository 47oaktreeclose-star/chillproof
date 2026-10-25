import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.navyDark,
      body: Container(
        decoration: const BoxDecoration(gradient: Brand.headerGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLogo(size: 84),
                const SizedBox(height: 22),
                const Wordmark(size: 40, onDark: true),
                const SizedBox(height: 10),
                Text(
                  'Fridge & freezer temperature logs for UK food businesses.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 18, height: 1.35),
                ),
                const SizedBox(height: 32),
                const _Feature(Icons.thermostat_rounded, 'Log every fridge and freezer in seconds',
                    'Type the reading or use the slider, in °C or °F.'),
                const _Feature(Icons.notifications_active_rounded, 'Never miss a check',
                    'Reminders or alarms at the times you choose.'),
                const _Feature(Icons.verified_user_rounded, 'Know when something is wrong',
                    'Instant alerts based on UK food hygiene limits.'),
                const _Feature(Icons.mark_email_read_rounded, 'Records ready for inspection',
                    'Email a professional PDF log whenever you need it.'),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Brand.ice, foregroundColor: Brand.navyDark),
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Get started'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text('Your records stay on your phone.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                ),
              ],
            ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Feature(this.icon, this.title, this.body);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF5ED3F3), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text(body, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5, height: 1.35)),
            ]),
          ),
        ]),
      );
}
