import 'package:flutter/widgets.dart';

import '../state.dart';
import '../theme.dart';
import '../ui/chrome.dart';
import 'future.dart';
import 'portfolio.dart';
import 'settings.dart';

class Shell extends StatefulWidget {
  const Shell(this.state, {super.key});

  final AppState state;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _visited = {0};

  @override
  void initState() {
    super.initState();
    // Build the other tabs off screen once the first is shown, so a switch never waits on them.
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _visited.addAll({1, 2}));
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [PortfolioPage(widget.state), FuturePage(widget.state), SettingsPage(widget.state)];
    return ColoredBox(
      color: C.ground,
      child: Stack(
        children: [
          for (var i = 0; i < pages.length; i++)
            Positioned.fill(
              child: Offstage(
                offstage: _tab != i,
                child: TickerMode(enabled: _tab == i, child: _visited.contains(i) ? pages[i] : const SizedBox()),
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
