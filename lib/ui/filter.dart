import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../platform/haptics.dart';

import '../projection.dart';
import '../state.dart';
import '../theme.dart';

const kindNames = {Kind.fund: 'Funds and stocks', Kind.crypto: 'Crypto', Kind.metal: 'Metals'};
const kindColors = {Kind.fund: C.green, Kind.crypto: C.navy, Kind.metal: C.sand};

/// Hides every amount, like the eye in a trading app.
class EyeButton extends StatelessWidget {
  const EyeButton(this.state, {super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => GlassIconButton(
        size: 40,
        quality: GlassQuality.minimal,
        semanticLabel: state.hide ? 'Show amounts' : 'Hide amounts',
        icon: Icon(state.hide ? CupertinoIcons.eye_slash : CupertinoIcons.eye, size: 20, color: C.ink),
        onPressed: () {
          Haptics.tick();
          state.setHide(!state.hide);
        },
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
  const KindChip(this.label, this.on, this.onTap, {super.key});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Center(
          child: GlassChip(
            label: label,
            selected: on,
            quality: GlassQuality.minimal,
            selectedColor: C.navy,
            semanticLabel: label,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            labelStyle: sans(14.5, weight: FontWeight.w500, color: on ? C.ground : C.ink),
            onTap: () {
              if (!on) Haptics.selection();
              onTap();
            },
          ),
        ),
      );
}
