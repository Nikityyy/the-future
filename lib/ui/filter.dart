import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import '../platform/haptics.dart';

import '../projection.dart';
import '../state.dart';
import '../theme.dart';
import 'basics.dart' show Pressable;

const kindNames = {Kind.fund: 'Funds and stocks', Kind.crypto: 'Crypto', Kind.metal: 'Metals'};
const kindColors = {Kind.fund: C.green, Kind.crypto: C.navy, Kind.metal: C.sand};

/// Hides every amount, like the eye in a trading app.
class EyeButton extends StatelessWidget {
  const EyeButton(this.state, {super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.9,
        semanticLabel: state.hide ? 'Show amounts' : 'Hide amounts',
        onTap: () => state.setHide(!state.hide),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: C.fill, shape: BoxShape.circle),
          child: Icon(state.hide ? CupertinoIcons.eye_slash : CupertinoIcons.eye, size: 20, color: C.ink),
        ),
      );
}

/// Pick what you look at: all, or any mix of funds, crypto and metals. Remembered.
class KindChips extends StatelessWidget {
  const KindChips(this.state, {super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final present = [for (final k in Kind.values) if (state.snapshot?.kinds.contains(k) ?? false) k];
    if (present.length < 2) return const SizedBox.shrink();
    final all = state.filter.isEmpty;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          KindChip('All', all, state.showAllKinds),
          for (final k in present) KindChip(kindNames[k]!, !all && state.active.contains(k), () => state.toggleKind(k)),
        ],
      ),
    );
  }
}

class KindChip extends StatelessWidget {
  const KindChip(this.label, this.on, this.onTap, {super.key, this.compact = false});

  final bool compact;

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Center(
          widthFactor: 1,
          child: Semantics(
            selected: on,
            child: Pressable(
              haptic: false,
              scale: 0.95,
              semanticLabel: label,
              onTap: () {
                if (!on) Haptics.selection();
                onTap();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 44,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 17),
                decoration: BoxDecoration(color: on ? C.navy : C.fill, borderRadius: BorderRadius.circular(22)),
                child: Text(label, style: sans(14.5, weight: FontWeight.w500, color: on ? C.ground : C.ink)),
              ),
            ),
          ),
        ),
      );
}
