import 'package:flutter/widgets.dart';

import '../state.dart';
import '../theme.dart';
import '../ui/basics.dart' show instantEntrances;
import '../ui/chrome.dart';
import 'future.dart';
import 'portfolio.dart';
import 'settings.dart';

class Shell extends StatefulWidget {
  const Shell(this.state, {super.key, this.warmOnly = false});

  final AppState state;

  /// For the warm-up frame: the first tab and the tab bar, nothing built later.
  final bool warmOnly;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _visited = {0};

  /// A tab built in the background, painted once under the current one so
  /// its first real visit only has to show a picture that already exists.
  int? _warming;

  void _prebuild(int i) {
    if (!mounted || _visited.contains(i)) return;
    instantEntrances = true;
    setState(() {
      _visited.add(i);
      _warming = i;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      instantEntrances = false;
      if (mounted) setState(() => _warming = null);
    });
  }

  /// Made once, so switching tabs rebuilds only the bar, never the pages.
  late final _pages = [PortfolioPage(widget.state), FuturePage(widget.state), SettingsPage(widget.state)];

  @override
  void initState() {
    super.initState();
    if (widget.warmOnly) return;
    // Build the other tabs off screen, one at a time once the first is up,
    // so a switch never waits on them and no single frame does all the work.
    Future.delayed(const Duration(milliseconds: 1200), () => _prebuild(1));
    Future.delayed(const Duration(milliseconds: 1500), () => _prebuild(2));
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    return ColoredBox(
      color: C.ground,
      child: Stack(
        children: [
          // The shown tab last, so it covers one that is warming up.
          for (final i in [for (var i = 0; i < pages.length; i++) if (i != _tab) i, _tab])
            Positioned.fill(
              key: ValueKey(i),
              child: Offstage(
                offstage: _tab != i && _warming != i,
                child: RepaintBoundary(
                  child: ColoredBox(
                    color: C.ground,
                    child: TickerMode(enabled: _tab == i, child: _visited.contains(i) ? pages[i] : const SizedBox()),
                  ),
                ),
              ),
            ),
          Dock(
            index: _tab,
            onSelect: (i) => setState(() {
              _tab = i;
              _visited.add(i);
            }),
          ),
        ],
      ),
    );
  }
}
