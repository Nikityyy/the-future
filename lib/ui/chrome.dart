
import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSheetRoute;
import 'package:flutter/widgets.dart';

import '../platform/haptics.dart';
import '../platform/web_glue.dart';
import '../theme.dart';
import 'basics.dart';

/// Floating glass tab bar. Only the navigation layer is glass.
class Dock extends StatelessWidget {
  const Dock({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const items = [
    (CupertinoIcons.chart_pie, CupertinoIcons.chart_pie_fill, 'Portfolio'),
    (CupertinoIcons.graph_square, CupertinoIcons.graph_square_fill, 'Future'),
    (
      CupertinoIcons.slider_horizontal_3,
      CupertinoIcons.slider_horizontal_3,
      'You',
    ),
  ];

  /// Room a page keeps free at its end so content scrolls clear of the dock.
  static double clearance(BuildContext context) =>
      96 + browserSafeArea().bottom;

  @override
  Widget build(BuildContext context) {
    final bottom = browserSafeArea().bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 12 + bottom,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: C.raised.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: C.ink.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: C.ink.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                Pressable(
                  scale: 0.94,
                  semanticLabel: items[i].$3,
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: 92,
                    height: 52,
                    decoration: BoxDecoration(
                      color: i == index ? C.navy : const Color(0x00000000),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i == index ? items[i].$2 : items[i].$1,
                          size: 22,
                          color: i == index ? C.ground : C.ink2,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$3,
                          style: sans(
                            10.5,
                            weight: FontWeight.w500,
                            color: i == index ? C.ground : C.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full page that pushes the one below it back, like an iPhone sheet.
Future<T?> showSheet<T>(BuildContext context, WidgetBuilder builder) {
  Haptics.tick();
  return Navigator.of(context, rootNavigator: true).push<T>(
    CupertinoSheetRoute<T>(
      showDragHandle: true,
      scrollableBuilder: (context, controller) => SheetScroll(
        controller,
        child: ColoredBox(color: C.ground, child: builder(context)),
      ),
    ),
  );
}

/// The sheet's scroll controller, so dragging down from the top closes it.
class SheetScroll extends InheritedWidget {
  const SheetScroll(this.controller, {super.key, required super.child});

  final ScrollController controller;

  static ScrollController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SheetScroll>()?.controller;

  @override
  bool updateShouldNotify(SheetScroll old) => old.controller != controller;
}

/// Title row of a sheet with its close button.
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 22, 20, 8),
    child: Row(
      children: [
        Expanded(child: Text(title, style: serif(30))),
        Pressable(
          onTap: onAction ?? () => Navigator.of(context).maybePop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: C.fill,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              action ?? 'Done',
              style: sans(15, weight: FontWeight.w500),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Segmented control with a gliding thumb.
class Segments extends StatelessWidget {
  const Segments({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: C.fill,
      borderRadius: BorderRadius.circular(20),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth / labels.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              left: w * index,
              width: w,
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: C.raised,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: C.ink.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Pressable(
                      scale: 0.96,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: Text(
                          labels[i],
                          style: sans(
                            14,
                            weight: i == index
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == index ? C.ink : C.ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
