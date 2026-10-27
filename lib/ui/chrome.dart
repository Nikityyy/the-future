
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPageRoute;
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../platform/haptics.dart';
import '../platform/web_glue.dart';
import '../theme.dart';
import 'basics.dart' show AppScrollBehavior, Pressable;

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

/// A sheet that rises over the page and closes with a drag down, from its
/// handle or from a list already at its top. [height] makes a short sheet only
/// as tall as it needs, up to the usual 88%. Solid, not glass: it covers the
/// page, so glass would only cost a blur on every frame it scrolls.
Future<T?> showSheet<T>(BuildContext context, WidgetBuilder builder, {double? height}) {
  Haptics.tick();
  return Navigator.of(context, rootNavigator: true).push(_SheetRoute<T>(builder, height));
}

class _SheetRoute<T> extends PopupRoute<T> {
  _SheetRoute(this.builder, this.height);

  final WidgetBuilder builder;
  final double? height;

  @override
  Color get barrierColor => const Color(0x5216170F);
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => 'Close';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 280);

  double _tall = 1;

  /// Follows the finger: [dy] pixels down closes that much of the sheet.
  void _drag(double dy) {
    if (controller!.isAnimating) controller!.stop();
    controller!.value = (controller!.value - dy / _tall).clamp(0.0, 1.0);
  }

  /// Closes on a flick down or past 40% of the way; otherwise springs back.
  void _release(double velocity) {
    if (controller!.value >= 1) return;
    if (velocity > 700 || controller!.value < 0.6) {
      navigator?.pop();
    } else {
      controller!.animateTo(1, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondary) {
    final most = MediaQuery.sizeOf(context).height * 0.88;
    _tall = height == null ? most : (height! + browserSafeArea().bottom).clamp(0, most);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
        child: GestureDetector(
          onVerticalDragUpdate: (d) => _drag(d.delta.dy),
          onVerticalDragEnd: (d) => _release(d.velocity.pixelsPerSecond.dy),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: ColoredBox(
              color: C.ground,
              child: SizedBox(
                height: _tall,
                child: Column(
                  children: [
                    // The handle.
                    Container(
                      width: 38,
                      height: 5,
                      margin: const EdgeInsets.fromLTRB(0, 8, 0, 9),
                      decoration: BoxDecoration(color: C.ink3.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3)),
                    ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.depth != 0) return false;
                          // Pulled down past the top of the list: the sheet follows.
                          if (n is OverscrollNotification && n.dragDetails != null && n.overscroll < 0) _drag(-n.overscroll);
                          if (n is ScrollUpdateNotification && n.dragDetails != null && controller!.value < 1) _drag(-n.scrollDelta!);
                          if (n is ScrollEndNotification) _release(n.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
                          return false;
                        },
                        // Clamped, so pulling down at the top moves the sheet and not the list.
                        child: ScrollConfiguration(
                          behavior: const _SheetScrollBehavior(),
                          child: Builder(builder: builder),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The slide below is linear so a finger moves the sheet one to one; the
  // easing goes on the runs the sheet makes by itself.
  @override
  TickerFuture didPush() {
    super.didPush();
    return controller!.animateTo(1, curve: Curves.easeOutCubic);
  }

  @override
  bool didPop(T? result) {
    final popped = super.didPop(result);
    controller!.animateBack(0, duration: reverseTransitionDuration, curve: Curves.easeInCubic);
    return popped;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondary, Widget child) =>
      SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(animation), child: child);
}

class _SheetScrollBehavior extends AppScrollBehavior {
  const _SheetScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
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
          Pressable(
            haptic: false,
            scale: 0.98,
            semanticLabel: action,
            onTap: () {
              Haptics.confirm();
              Navigator.of(context).pop(true);
            },
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.fill, borderRadius: BorderRadius.circular(27)),
              child: Text(action, style: sans(16, weight: FontWeight.w600, color: C.loss)),
            ),
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
/// under it, softened by a fade at the top edge. Once the page's own large
/// title ([titleKey]) has scrolled under the bar, [title] settles into the
/// bar, as on iOS.
class BackPage extends StatefulWidget {
  const BackPage({super.key, this.onBack, this.title, this.titleKey, required this.child});

  final VoidCallback? onBack;
  final String? title;
  final GlobalKey? titleKey;
  final Widget child;

  /// Room to leave at the top of the content for the button.
  static double space() => 62 + browserSafeArea().top;

  @override
  State<BackPage> createState() => _BackPageState();
}

class _BackPageState extends State<BackPage> {
  bool _under = false;

  bool _onScroll(ScrollNotification n) {
    // Positions settle at the next layout, so look after the frame.
    if (n.depth == 0 && widget.title != null) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    return false;
  }

  void _check() {
    if (!mounted) return;
    final big = widget.titleKey?.currentContext?.findRenderObject() as RenderBox?;
    final page = context.findRenderObject() as RenderBox?;
    if (big == null || page == null || !big.attached) return;
    // Under once most of the large title has gone behind the bar.
    final under = big.localToGlobal(Offset(0, big.size.height * 0.75), ancestor: page).dy < BackPage.space() - 8;
    if (under != _under) setState(() => _under = under);
  }

  @override
  Widget build(BuildContext context) {
    final top = browserSafeArea().top;
    return Stack(
      children: [
        Positioned.fill(child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Stack(
              children: [
                Container(
                  height: BackPage.space(),
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.55, 1], colors: [C.ground, C.ground.withValues(alpha: 0)])),
                ),
                if (widget.title != null)
                  AnimatedOpacity(
                    opacity: _under ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      height: BackPage.space(),
                      padding: EdgeInsets.fromLTRB(72, 10 + top, 72, 4),
                      decoration: const BoxDecoration(color: C.ground, border: Border(bottom: BorderSide(color: C.rule, width: 0.5))),
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: 44,
                        child: Center(child: Text(widget.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(16, weight: FontWeight.w600))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(top: 0, left: 0, child: BackBar(onBack: widget.onBack)),
      ],
    );
  }
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

/// A small grey capsule with a word on it, like Done or Close.
class PillButton extends StatelessWidget {
  const PillButton(this.label, {super.key, required this.onTap, this.strong = false});

  final String label;
  final VoidCallback onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.95,
        semanticLabel: label,
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(color: C.fill, borderRadius: BorderRadius.circular(19)),
          // As wide as the word, wherever the capsule sits.
          child: Center(widthFactor: 1, child: Text(label, style: sans(15, weight: strong ? FontWeight.w600 : FontWeight.w500, color: C.ink))),
        ),
      );
}

/// A segmented control, iOS style: a grey track and a white thumb that slides.
class Segments extends StatelessWidget {
  const Segments({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: C.fill, borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: Alignment(labels.length < 2 ? 0 : -1 + 2 * index / (labels.length - 1), 0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: FractionallySizedBox(
                widthFactor: 1 / labels.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: C.raised,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: const [BoxShadow(color: Color(0x1A16170F), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final (i, l) in labels.indexed)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == index,
                      label: l,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (i != index) Haptics.selection();
                          onChanged(i);
                        },
                        child: Center(child: Text(l, maxLines: 1, style: sans(14, weight: i == index ? FontWeight.w600 : FontWeight.w500, color: i == index ? C.ink : C.ink2))),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}
