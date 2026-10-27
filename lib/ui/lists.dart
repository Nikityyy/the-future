import 'package:flutter/widgets.dart';

import '../platform/haptics.dart';
import '../platform/web_glue.dart';
import '../theme.dart';

/// A grouped list: one rounded surface, hairlines between the rows.
class Group extends StatelessWidget {
  const Group({super.key, this.header, this.footer, required this.children});

  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(header!, style: sans(13, weight: FontWeight.w500, color: C.ink2, tracking: 0.1)),
              ),
            DecoratedBox(
              decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.rule.withValues(alpha: 0.06))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) Container(height: 0.5, margin: const EdgeInsets.only(left: 18), color: C.rule),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(footer!, style: sans(12.5, color: C.ink2, height: 1.4)),
              ),
          ],
        ),
      );
}

class Row2 extends StatefulWidget {
  const Row2({super.key, required this.title, this.subtitle, this.trailing, this.subtrailing, this.leading, this.onTap, this.chevron = false, this.titleColor = C.ink});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? subtrailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool chevron;
  final Color titleColor;

  @override
  State<Row2> createState() => _Row2State();
}

class _Row2State extends State<Row2> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      color: _down ? C.fill : const Color(0x00000000),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          if (widget.leading != null) Padding(padding: const EdgeInsets.only(right: 14), child: widget.leading),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: sans(16, color: widget.titleColor, weight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (widget.subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(widget.subtitle!, style: sans(13, color: C.ink2), maxLines: 2)),
              ],
            ),
          ),
          if (widget.trailing != null || widget.subtrailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [if (widget.trailing != null) widget.trailing!, if (widget.subtrailing != null) widget.subtrailing!],
              ),
            ),
          if (widget.chevron) const Padding(padding: EdgeInsets.only(left: 8), child: _Chevron()),
        ],
      ),
    );
    if (widget.onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        Haptics.tick();
        widget.onTap!();
      },
      child: row,
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(8, 13), painter: _ChevronPainter());
}

class _ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = C.ink3
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(Path()..moveTo(1, 1)..lineTo(6.5, size.height / 2)..lineTo(1, size.height - 1), p);
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => false;
}

/// A large title that settles into a small one as the page scrolls.
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final top = browserSafeArea().top;
    return SliverPersistentHeader(pinned: true, delegate: _TitleDelegate(title, trailing, top));
  }
}

class _TitleDelegate extends SliverPersistentHeaderDelegate {
  _TitleDelegate(this.title, this.trailing, this.top);

  final String title;
  final Widget? trailing;
  final double top;

  static const _small = 52.0;
  static const _large = 92.0;

  @override
  double get minExtent => _small + top;
  @override
  double get maxExtent => _large + top;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) {
    final t = (shrink / (_large - _small)).clamp(0.0, 1.0);
    final size = 40 - 20 * t;
    return Container(
      decoration: BoxDecoration(
        color: C.ground.withValues(alpha: t > 0.05 ? 0.94 : 0),
        border: Border(bottom: BorderSide(color: C.rule.withValues(alpha: t >= 1 ? 1 : 0), width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(24, top, 20, 0),
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 10 + 4 * (1 - t)),
        child: Row(
          children: [
            Expanded(child: Text(title, style: serif(size, tracking: -size * 0.02))),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TitleDelegate old) => old.title != title || old.trailing != trailing || old.top != top;
}
