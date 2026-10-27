import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../screens/shell.dart';
import '../state.dart';
import '../theme.dart';

/// One hidden frame of the real pages with sample numbers, painted under the
/// first page while the splash still covers it. The browser compiles a GPU
/// program the first time it meets a kind of drawing; doing it here keeps
/// that stall out of opening the app and the first tab switches.
class Warmup extends StatelessWidget {
  const Warmup(this.demo, {super.key});

  /// An app state on sample numbers, never shown.
  final AppState demo;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox(
          width: 390,
          height: 844,
          child: Stack(
            children: [
              Positioned.fill(child: Shell(demo, warmOnly: true)),
              // Entrances caught halfway: a fading layer and a few blur widths.
              for (final (i, sigma) in [2.0, 5.0, 8.0].indexed)
                Positioned(
                  top: 200.0 + i * 60,
                  left: 20,
                  child: Opacity(opacity: 0.5, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal), child: Text('Warm', style: serif(40)))),
                ),
            ],
          ),
        ),
      );
}
