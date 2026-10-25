import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../billing.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets/common.dart';


class PaywallScreen extends StatefulWidget {
  /// True when opened from settings rather than as part of setup.
  final bool fromSettings;
  const PaywallScreen({super.key, this.fromSettings = false});
  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _busy = false;

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    final billing = Billing.instance;
    if (!billing.available || !billing.hasProduct(ProductIds.subscription)) {
      await AppState.instance.refreshEntitlements();
    }
    if (!billing.hasProduct(ProductIds.subscription)) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Google Play is not available right now. Check your connection and try again.');
      }
      return;
    }
    final r = await billing.buy(ProductIds.subscription);
    if (r == BuyResult.success) AppState.instance.grantPurchase(ProductIds.subscription);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case BuyResult.success:
        showSnack(context, 'Welcome to ChillProof!');
        if (widget.fromSettings) Navigator.pop(context);
      case BuyResult.pending:
        showSnack(context, 'Your payment is pending. We\'ll unlock ChillProof as soon as it completes.');
      case BuyResult.cancelled:
        break;
      case BuyResult.error:
      case BuyResult.unavailable:
        showSnack(context, 'The purchase could not be completed. Please try again.');
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    await AppState.instance.refreshEntitlements();
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(
        context,
        AppState.instance.subscribed
            ? 'Subscription restored'
            : 'No active subscription found for this Google account.');
  }

  @override
  Widget build(BuildContext context) {
    final price = Billing.instance.subscriptionPrice;
    return Scaffold(
      appBar: widget.fromSettings ? AppBar(title: const Text('Subscription')) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (!widget.fromSettings) ...[
              const StepHeader(
                step: 2,
                of: 4,
                title: 'Start your subscription',
                subtitle: 'Everything you need to keep your temperature records inspection-ready.',
              ),
              const SizedBox(height: 20),
            ],
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(gradient: Brand.headerGradient, borderRadius: BorderRadius.circular(22)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const BrandLogo(size: 44),
                  const SizedBox(width: 12),
                  const Wordmark(size: 24, onDark: true),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Brand.mint, borderRadius: BorderRadius.circular(99)),
                    child: const Text('MONTHLY',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
                  ),
                ]),
                const SizedBox(height: 18),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(price,
                      style: const TextStyle(
                          fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 40, color: Colors.white)),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 4),
                    child: Text('/ month', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ),
                ]),
                const SizedBox(height: 4),
                const Text('Cancel anytime in Google Play.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                for (final f in const [
                  'Up to ${AppState.baseFridges} fridges and ${AppState.baseFreezers} freezers included',
                  'Unlimited temperature checks and records',
                  'Reminders and alarms at your chosen times',
                  'Instant high and low temperature alerts',
                  'Professional PDF logs sent to your email',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3))),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            const InfoBanner(
              icon: Icons.add_circle_outline_rounded,
              text: 'Need more? Add extra fridges or freezers any time for a one-off £0.99 each.',
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _subscribe,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text('Subscribe for $price a month'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _busy ? null : _restore, child: const Text('Restore purchase')),
            const SizedBox(height: 16),
            const Text(
              'Payment is charged to your Google Play account. The subscription renews '
              'automatically each month unless cancelled at least 24 hours before the '
              'end of the current period. Manage or cancel in Google Play > Payments & subscriptions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Brand.muted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                onPressed: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl), mode: LaunchMode.externalApplication),
                child: const Text('Privacy policy'),
              ),
              TextButton(
                onPressed: () => launchUrl(Uri.parse(AppConfig.playSubscriptionsUrl), mode: LaunchMode.externalApplication),
                child: const Text('Manage subscription'),
              ),
            ]),
            if (kDebugMode && !widget.fromSettings)
              TextButton(
                onPressed: AppState.instance.enableDebugBypass,
                child: const Text('Skip (debug builds only)'),
              ),
          ],
        ),
      ),
    );
  }
}
