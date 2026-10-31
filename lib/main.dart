import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';
import 'utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(ChangeNotifierProvider.value(value: state, child: const AnnuaApp()));
}

class AnnuaApp extends StatelessWidget {
  const AnnuaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return DynamicColorBuilder(
      builder: (light, dark) => MaterialApp(
        title: 'Annua',
        debugShowCheckedModeBanner: false,
        navigatorKey: navKey,
        scaffoldMessengerKey: messengerKey,
        themeMode: s.themeMode,
        theme: buildTheme(Brightness.light, s, light),
        darkTheme: buildTheme(Brightness.dark, s, dark),
        home: const _Root(),
      ),
    );
  }
}

/// Shows the splash for a moment, then fades into the home screen.
class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    if (state.pendingLaunch != null) {
      // Started from a reminder: go straight to it, no splash.
      _done = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => state.consumeLaunch());
      return;
    }
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _done = true);
      // First launch only: ask for the permissions reminders need.
      state.askStartupPermissions();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _done ? const HomeScreen() : const SplashScreen(),
      );
}
