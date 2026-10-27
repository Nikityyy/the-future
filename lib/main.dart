import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo.dart';
import 'platform/haptics.dart';
import 'platform/web_glue.dart';
import 'screens/lock.dart';
import 'screens/shell.dart';
import 'screens/welcome.dart';
import 'state.dart';
import 'theme.dart';
import 'ui/basics.dart';
import 'ui/warmup.dart';

final _warm = ValueNotifier(true);
final _booted = ValueNotifier(false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads the glass shaders; only reads files, so it is quick.
  final (prefs, _) = await (SharedPreferences.getInstance(), LiquidGlassWidgets.initialize(enablePerformanceMonitor: false)).wait;
  final state = AppState(prefs);
  final demo = AppState(prefs)
    ..mode = Mode.demo
    ..snapshot = demoSnapshot()
    ..locked = false;
  final app = LiquidGlassWidgets.wrap(theme: const GlassThemeData(
        // iOS 27 optics, drawn as a plain blur: the refraction shader costs a
        // phone browser too much on every button that scrolls. The tab bar
        // keeps the full shader (see Dock).
        light: GlassThemeVariant(settings: GlassThemeSettings.ios27Light, quality: GlassQuality.minimal),
        dark: GlassThemeVariant(settings: GlassThemeSettings.ios27Dark, quality: GlassQuality.minimal),
      ), child: FutureApp(state, demo));
  // runApp builds in one task and lays out in the next frame. In between,
  // the browser hands the page focus and Flutter measures every focusable
  // widget, none of which has a size yet. Nothing takes focus until then.
  runApp(ValueListenableBuilder(valueListenable: _booted, child: app, builder: (_, booted, app) => ExcludeFocus(excluding: !booted, child: app!)));
  WidgetsBinding.instance.addPostFrameCallback((_) => _booted.value = true);
  state.checkBio();

  // The first frames also paint the warm-up under the page (the very first
  // one can come before the canvas is ready); then it goes and the splash lifts.
  _afterFrames(2, () {
    _warm.value = false;
    Haptics.init();
    hideSplash();
  });
}

void _afterFrames(int n, VoidCallback done) => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (n <= 1) return done();
      WidgetsBinding.instance.scheduleFrame();
      _afterFrames(n - 1, done);
    });

class FutureApp extends StatelessWidget {
  const FutureApp(this.state, this.demo, {super.key});

  final AppState state;

  /// Sample numbers for the warm-up frame.
  final AppState demo;

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
          child: Stack(
            children: [
              ValueListenableBuilder(
                valueListenable: _warm,
                builder: (context, warm, _) {
                  if (!warm) return const SizedBox();
                  instantEntrances = true;
                  return Positioned(left: 0, top: 0, child: Warmup(demo));
                },
              ),
              // Built right after the warm-up: the page's own entrances play as usual.
              Builder(builder: (_) {
                instantEntrances = false;
                return const SizedBox();
              }),
              Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child)),
            ],
          ),
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
              // Instant: fading two whole pages into each other is the heaviest
              // thing a phone browser can be asked to draw.
              duration: Duration.zero,
              switchInCurve: Curves.easeOut,
              child: KeyedSubtree(key: ValueKey(page.runtimeType), child: page),
            );
          },
        ),
      );
}
