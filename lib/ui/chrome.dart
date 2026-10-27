
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPageRoute;
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../platform/haptics.dart';
import '../platform/web_glue.dart';
import '../theme.dart';

/// The Liquid Glass tab bar, floating over the pages.
class Dock extends StatelessWidget {
  const Dock({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const items = [
    (CupertinoIcons.chart_pie, CupertinoIcons.chart_pie_fill, 'Portfolio'),
    (CupertinoIcons.graph_square, CupertinoIcons.graph_square_fill, 'Future'),
    (CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill, 'You'),
  ];

  /// Room a page keeps free at its end so content scrolls clear of the bar.
  static double clearance(BuildContext context) => 104 + browserSafeArea().bottom;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        bottom: browserSafeArea().bottom,
        child: GlassTabBar.bottom(
          quality: GlassQuality.standard,
          tabs: [for (final t in items) GlassTab(icon: Icon(t.$1), activeIcon: Icon(t.$2), label: t.$3)],
          selectedIndex: index,
          onTabSelected: (i) {
            if (i != index) Haptics.selection();
            onSelect(i);
          },
          horizontalPadding: 28,
          verticalPadding: 14,
          selectedIconColor: C.navy,
          unselectedIconColor: C.ink2,
          selectedLabelColor: C.navy,
          unselectedLabelColor: C.ink2,
          textStyle: sans(10.5, weight: FontWeight.w600),
          iconSize: 23,
        ),
      );
}

/// A Liquid Glass sheet that rises over the page and closes with a drag down.
/// [height] makes a short sheet only as tall as it needs, up to the usual 88%.
Future<T?> showSheet<T>(BuildContext context, WidgetBuilder builder, {double? height}) {
  Haptics.tick();
  return GlassSheet.show<T>(
    context: context,
    useRootNavigator: true,
    isScrollable: false,
    showDragIndicator: true,
    dragIndicatorColor: C.ink3,
    margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
    settings: LiquidGlassSettings(glassColor: C.ground.withValues(alpha: 0.9), blur: 18, thickness: 22),
    builder: (context) {
      final most = MediaQuery.sizeOf(context).height * 0.88;
      return SizedBox(height: height == null ? most : (height + browserSafeArea().bottom).clamp(0, most), child: builder(context));
    },
  );
}

/// Asks before something that cannot be undone. True when confirmed.
Future<bool> confirmSheet(BuildContext context, {required String title, required String message, required String action}) async {
  final ok = await showSheet<bool>(
    context,
    height: 270,
    (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: serif(28)),
          const SizedBox(height: 8),
          Text(message, style: sans(15, color: C.ink2, height: 1.45)),
          const Spacer(),
          GlassButton.custom(
            onTap: () {
              Haptics.confirm();
              Navigator.of(context).pop(true);
            },
            label: action,
            width: double.infinity,
            height: 54,
            shape: const LiquidRoundedSuperellipse(borderRadius: 27),
            child: Text(action, style: sans(16, weight: FontWeight.w600, color: C.loss)),
          ),
          const SizedBox(height: 10),
          Center(child: PillButton('Cancel', onTap: () => Navigator.of(context).pop(false))),
          SizedBox(height: 16 + browserSafeArea().bottom),
        ],
      ),
    ),
  );
  return ok ?? false;
}

/// A full page that slides in from the right, with the iPhone back swipe.
Future<T?> showPage<T>(BuildContext context, WidgetBuilder builder) {
  Haptics.tick();
  return Navigator.of(context, rootNavigator: true).push<T>(
    CupertinoPageRoute<T>(builder: (context) => ColoredBox(color: C.ground, child: builder(context))),
  );
}

/// The glass back button at the top left of a pushed page.
class BackBar extends StatelessWidget {
  const BackBar({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 10 + browserSafeArea().top, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: GlassIconButton(
            size: 44,
            semanticLabel: 'Back',
            icon: const Icon(CupertinoIcons.chevron_left, size: 20, color: C.ink),
            onPressed: () {
              Haptics.tick();
              (onBack ?? () => Navigator.of(context).maybePop())();
            },
          ),
        ),
      );
}

/// A pushed page whose back button stays put while the content scrolls
/// under it, softened by a fade at the top edge.
class BackPage extends StatelessWidget {
  const BackPage({super.key, this.onBack, required this.child});

  final VoidCallback? onBack;
  final Widget child;

  /// Room to leave at the top of the content for the button.
  static double space() => 62 + browserSafeArea().top;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: space(),
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.55, 1], colors: [C.ground, C.ground.withValues(alpha: 0)])),
              ),
            ),
          ),
          Positioned(top: 0, left: 0, child: BackBar(onBack: onBack)),
        ],
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
        padding: const EdgeInsets.fromLTRB(24, 4, 20, 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: serif(30))),
            PillButton(action ?? 'Done', onTap: onAction ?? () => Navigator.of(context).maybePop()),
          ],
        ),
      );
}

/// A small glass capsule with a word on it, like Done or Close.
class PillButton extends StatelessWidget {
  const PillButton(this.label, {super.key, required this.onTap, this.strong = false});

  final String label;
  final VoidCallback onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) => GlassButton.custom(
        onTap: () {
          Haptics.tick();
          onTap();
        },
        label: label,
        height: 38,
        width: label.length * 8.5 + 34,
        shape: const LiquidRoundedSuperellipse(borderRadius: 19),
        child: Text(label, style: sans(15, weight: strong ? FontWeight.w600 : FontWeight.w500, color: C.ink)),
      );
}

/// Liquid Glass segmented control.
class Segments extends StatelessWidget {
  const Segments({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => GlassSegmentedControl(
        segments: [for (final l in labels) GlassSegment(label: l)],
        selectedIndex: index,
        onSegmentSelected: (i) {
          if (i != index) Haptics.selection();
          onChanged(i);
        },
        height: 40,
        selectedTextStyle: sans(14, weight: FontWeight.w600, color: C.ink),
        unselectedTextStyle: sans(14, weight: FontWeight.w500, color: C.ink2),
      );
}
