import 'package:flutter/cupertino.dart';
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
  final state = AppState(await SharedPreferences.getInstance());
  runApp(FutureApp(state));
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
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOut,
              child: KeyedSubtree(key: ValueKey(page.runtimeType), child: page),
            );
          },
        ),
      );
}
