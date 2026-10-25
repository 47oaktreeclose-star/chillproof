import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../config.dart';
import '../temperature.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'legal_screen.dart';
import 'paywall_screen.dart';
import 'register_screen.dart';
import 'schedule_screen.dart';
import 'units_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _go(BuildContext context, Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  Future<void> _restore(BuildContext context) async {
    await AppState.instance.refreshEntitlements();
    if (!context.mounted) return;
    final s = AppState.instance;
    showSnack(
        context,
        s.subscribed
            ? 'Purchases restored: subscription active, ${s.extraFridges} extra fridge(s), ${s.extraFreezers} extra freezer(s).'
            : 'No active subscription found for this Google account.');
  }

  Future<void> _deleteAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
            'This permanently deletes your business details, fridges, freezers and ALL temperature '
            'records from this phone. Email yourself a log first if you need to keep your records.\n\n'
            'This does not cancel your subscription – do that in Google Play.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await AppState.instance.deleteEverything();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        final p = s.profile;
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              const SectionLabel('Business'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront_rounded, color: Brand.iceDeep),
                  title: Text(p?.businessName ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([p?.email, p?.phone, if ((p?.companyNumber ?? '').isNotEmpty) 'Co. ${p!.companyNumber}']
                      .whereType<String>()
                      .join('\n')),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _go(context, const RegisterScreen(editing: true)),
                ),
              ),
              const SectionLabel('Checks'),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.kitchen_rounded, color: Brand.iceDeep),
                    title: const Text('Fridges & freezers'),
                    subtitle: Text('${s.fridges.length} fridges · ${s.freezers.length} freezers'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _go(context, const UnitsScreen()),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
                  ListTile(
                    leading: const Icon(Icons.alarm_rounded, color: Brand.iceDeep),
                    title: const Text('Checks & reminders'),
                    subtitle: Text('${s.settings.checksPerDay}× a day · '
                        '${s.settings.remindersOn ? (s.settings.style.name == 'alarm' ? 'Alarm' : 'Notification') : 'Reminders off'}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _go(context, const ScheduleScreen()),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
                  ListTile(
                    leading: const Icon(Icons.thermostat_rounded, color: Brand.iceDeep),
                    title: const Text('Temperature units'),
                    trailing: SegmentedButton<TempScale>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: TempScale.celsius, label: Text('°C')),
                        ButtonSegment(value: TempScale.fahrenheit, label: Text('°F')),
                      ],
                      selected: {s.settings.scale},
                      onSelectionChanged: (v) =>
                          s.saveSettings(s.settings.copyWith(scale: v.first), reschedule: false),
                    ),
                  ),
                ]),
              ),
              const SectionLabel('Subscription'),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: Icon(s.subscribed ? Icons.verified_rounded : Icons.error_outline_rounded,
                        color: s.subscribed ? Brand.mint : const Color(0xFFD97706)),
                    title: Text(s.subscribed ? 'ChillProof monthly – active' : 'No active subscription'),
                    subtitle: Text('Extras owned: ${s.extraFridges} fridge(s), ${s.extraFreezers} freezer(s)'),
                    onTap: s.subscribed ? null : () => _go(context, const PaywallScreen(fromSettings: true)),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
                  ListTile(
                    leading: const Icon(Icons.restore_rounded, color: Brand.iceDeep),
                    title: const Text('Restore purchases'),
                    onTap: () => _restore(context),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
                  ListTile(
                    leading: const Icon(Icons.open_in_new_rounded, color: Brand.iceDeep),
                    title: const Text('Manage or cancel in Google Play'),
                    onTap: () => launchUrl(Uri.parse(AppConfig.playSubscriptionsUrl),
                        mode: LaunchMode.externalApplication),
                  ),
                ]),
              ),
              const SectionLabel('Help & legal'),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.gavel_rounded, color: Brand.iceDeep),
                    title: const Text('Food safety rules'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _go(context, const LegalScreen()),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_rounded, color: Brand.iceDeep),
                    title: const Text('Privacy policy'),
                    onTap: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl),
                        mode: LaunchMode.externalApplication),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
                  ListTile(
                    leading: const Icon(Icons.support_agent_rounded, color: Brand.iceDeep),
                    title: const Text('Contact support'),
                    subtitle: const Text(AppConfig.supportEmail),
                    onTap: () => launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}?subject=ChillProof%20support')),
                  ),
                ]),
              ),
              const SectionLabel('Your data'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626)),
                  title: const Text('Delete all data', style: TextStyle(color: Color(0xFFDC2626))),
                  subtitle: const Text('Removes your account details and records from this phone'),
                  onTap: () => _deleteAll(context),
                ),
              ),
              const SizedBox(height: 24),
              const Center(child: Wordmark(size: 18)),
              const SizedBox(height: 4),
              const Center(
                child: Text('Version 1.0.0', style: TextStyle(color: Brand.muted, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}
