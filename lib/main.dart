import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'reminders.dart';
import 'screens/home_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/setup_units_screen.dart';
import 'screens/take_temps_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState.instance;
  try {
    await Reminders.init();
  } catch (e) {
    debugPrint('Reminders init failed: $e');
  }
  await state.load();
  Reminders.onOpenedFromReminder = _openTakeTemps;
  runApp(const ChillProofApp());
  // Check purchases with Google Play in the background.
  state.refreshEntitlements();
}

void _openTakeTemps() {
  final state = AppState.instance;
  if (!state.hasAccess || state.units.isEmpty) return;
  navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const TakeTempsScreen()));
}

class ChillProofApp extends StatelessWidget {
  const ChillProofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChillProof',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      home: const RootGate(),
    );
  }
}

/// Decides which screen to show based on how far setup has got.
class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _handledLaunch = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (s.profile == null) return const WelcomeScreen();
        if (!s.hasAccess) return const PaywallScreen();
        if (s.units.isEmpty) return const SetupUnitsScreen();
        if (!s.settings.scheduleConfigured) return const ScheduleScreen(onboarding: true);
        if (!_handledLaunch && Reminders.launchedFromReminder) {
          _handledLaunch = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _openTakeTemps());
        }
        return const HomeScreen();
      },
    );
  }
}
