import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'platform/haptics.dart';
import 'platform/web_glue.dart';
import 'screens/lock.dart';
import 'screens/shell.dart';
import 'screens/welcome.dart';
import 'state.dart';
import 'theme.dart';
import 'ui/basics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads the glass shaders; only reads files, so it is quick.
  final (prefs, _) = await (SharedPreferences.getInstance(), LiquidGlassWidgets.initialize(enablePerformanceMonitor: false)).wait;
  final state = AppState(prefs);
  runApp(LiquidGlassWidgets.wrap(theme: const GlassThemeData.ios27(), child: FutureApp(state)));
  state.checkBio();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Haptics.init();
    hideSplash();
  });
}

class FutureApp extends StatelessWidget {
  const FutureApp(this.state, {super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => CupertinoApp(
        title: 'The Future',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const AppScrollBehavior(),
        theme: CupertinoThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: C.ground,
          primaryColor: C.navy,
          textTheme: CupertinoTextThemeData(textStyle: sans(16)),
        ),
        // On a computer the app stays a phone-width column in the middle.
        builder: (context, child) => ColoredBox(
          color: C.ground,
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child)),
        ),
        home: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final Widget page;
            if (state.locked) {
              page = LockScreen(state);
            } else if (state.mode == Mode.none) {
              page = WelcomeScreen(state);
            } else {
              page = Shell(state);
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOut,
              child: KeyedSubtree(key: ValueKey(page.runtimeType), child: page),
            );
          },
        ),
      );
}
