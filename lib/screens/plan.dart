import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../format.dart';
import '../platform/haptics.dart';
import '../platform/web_glue.dart';
import '../projection.dart';
import '../state.dart';
import '../theme.dart';
import '../ui/basics.dart';
import '../ui/chrome.dart';
import '../ui/lists.dart';
import '../ui/ruler.dart';
import '../ui/filter.dart' show KindChip, kindNames;

class _Stepper extends StatelessWidget {
  const _Stepper({required this.text, required this.onMinus, required this.onPlus});

  final String text;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Round('−', onMinus),
          SizedBox(width: 62, child: Text(text, textAlign: TextAlign.center, style: figures(sans(15, weight: FontWeight.w500)))),
          _Round('+', onPlus),
        ],
      );
}

class _Round extends StatelessWidget {
  const _Round(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassButton.custom(
        onTap: () {
          Haptics.selection();
          onTap();
        },
        label: label == '+' ? 'Increase' : 'Decrease',
        width: 34,
        height: 34,
        child: Text(label, style: sans(19, color: C.ink)),
      );
}

String _pct(double v) => '${v < 0 ? '−' : ''}${v.abs().toStringAsFixed(v % 1 == 0 ? 0 : (v * 10) % 1 == 0 ? 1 : 2)}%';

/// Returns per asset type and scenario, inflation and the yearly raise.
class AssumptionsSheet extends StatelessWidget {
  const AssumptionsSheet(this.state, {super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          void setReturn(Kind k, int i, double d) {
            final r = {for (final e in state.returns.entries) e.key: [...e.value]};
            r[k]![i] = ((r[k]![i] + d) * 2).round() / 2;
            state.setPlan(returns: r);
          }

          return CustomScrollView(
            controller: SheetScroll.of(context),
            slivers: [
              const SliverToBoxAdapter(child: SheetHeader('Assumptions')),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
                  child: Text('Nobody knows the future, so the app shows three: a cautious, an expected and a hopeful yearly return per asset type. Change them to what you believe.', style: sans(15, color: C.ink2, height: 1.45)),
                ),
              ),
              SliverToBoxAdapter(
                child: Group(
                  header: 'YOUR MONEY',
                  children: [
                    Row2(title: 'Inflation', trailing: _Stepper(text: _pct(state.inflation), onMinus: () => state.setPlan(inflation: (state.inflation - 0.5).clamp(0, 10)), onPlus: () => state.setPlan(inflation: (state.inflation + 0.5).clamp(0, 10)))),
                    Row2(title: 'Savings account rate', subtitle: 'What the comparison with a savings account pays a year', trailing: _Stepper(text: _pct(state.savingsRate), onMinus: () => state.setPlan(savingsRate: (state.savingsRate - 0.25).clamp(0, 10)), onPlus: () => state.setPlan(savingsRate: (state.savingsRate + 0.25).clamp(0, 10)))),
                    Row2(title: 'Yearly raise', subtitle: 'Add more each year, such as with your pay', trailing: _Stepper(text: _pct(state.raisePercent), onMinus: () => state.setPlan(raisePercent: (state.raisePercent - 1).clamp(0, 30)), onPlus: () => state.setPlan(raisePercent: (state.raisePercent + 1).clamp(0, 30)))),
                  ],
                ),
              ),
              for (final k in Kind.values)
                SliverToBoxAdapter(
                  child: Group(
                    header: '${kindNames[k]!.toUpperCase()}, YEARLY RETURN',
                    children: [
                      for (final i in [0, 1, 2])
                        Row2(
                          title: const ['Cautious', 'Expected', 'Hopeful'][i],
                          trailing: _Stepper(text: _pct(state.returns[k]![i]), onMinus: () => setReturn(k, i, -0.5), onPlus: () => setReturn(k, i, 0.5)),
                        ),
                    ],
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: AppButton('Back to defaults', filled: false, onTap: () => state.setPlan(returns: {for (final e in defaultReturns.entries) e.key: [...e.value]}, inflation: defaultInflation, savingsRate: defaultSavingsRate, raisePercent: 0)),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 40 + browserSafeArea().bottom)),
            ],
          );
        },
      );
}

class Switch2 extends StatelessWidget {
  const Switch2({super.key, required this.on, required this.onChanged});
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GlassSwitch(
        value: on,
        onChanged: onChanged,
        activeColor: C.green,
        width: 54,
        height: 30,
        semanticLabel: on ? 'On' : 'Off',
      );
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Money you will put in once, such as a bonus in March.
class OneOffsSheet extends StatefulWidget {
  const OneOffsSheet(this.state, {super.key});

  final AppState state;

  @override
  State<OneOffsSheet> createState() => _OneOffsSheetState();
}

class _OneOffsSheetState extends State<OneOffsSheet> {
  late DateTime _when = DateTime(DateTime.now().year, DateTime.now().month + 3);
  double _amount = 1000;

  void _add() {
    Haptics.confirm();
    final list = [...widget.state.oneOffs, (year: _when.year, month: _when.month, amount: _amount)]..sort((a, b) => (a.year * 12 + a.month).compareTo(b.year * 12 + b.month));
    widget.state.setPlan(oneOffs: list);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final list = widget.state.oneOffs;
          final now = DateTime.now();
          return CustomScrollView(
            controller: SheetScroll.of(context),
            slivers: [
              const SliverToBoxAdapter(child: SheetHeader('One-time additions')),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
                  child: Text('A bonus, a gift, savings you move over. It joins your plan in the month you pick.', style: sans(15, color: C.ink2, height: 1.45)),
                ),
              ),
              if (list.isNotEmpty)
                SliverToBoxAdapter(
                  child: Group(
                    header: 'PLANNED',
                    children: [
                      for (var i = 0; i < list.length; i++)
                        Row2(
                          title: '${_months[list[i].month - 1]} ${list[i].year}',
                          subtitle: (list[i].year - now.year) * 12 + list[i].month - now.month < 1 ? 'In the past, not counted' : null,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('+${eur(list[i].amount)}', style: figures(sans(16, weight: FontWeight.w500))),
                            const SizedBox(width: 12),
                            _Round('×', () => widget.state.setPlan(oneOffs: [...list]..removeAt(i))),
                          ]),
                        ),
                    ],
                  ),
                ),
              SliverToBoxAdapter(
                child: Group(
                  header: 'ADD ONE',
                  children: [
                    Row2(title: 'Month', trailing: _Stepper(text: '${_months[_when.month - 1]} ${_when.year % 100}', onMinus: () => setState(() => _when = DateTime(_when.year, _when.month - 1)), onPlus: () => setState(() => _when = DateTime(_when.year, _when.month + 1)))),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: RulerSlider(label: 'Amount', value: _amount, min: 100, max: 20000, step: 100, onChanged: (v) => setState(() => _amount = v)),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: AppButton('Add ${eur(_amount)} in ${_months[_when.month - 1]} ${_when.year}', onTap: _add))),
              SliverToBoxAdapter(child: SizedBox(height: 40 + browserSafeArea().bottom)),
            ],
          );
        },
      );
}

/// An amount you want to have by the end of a year.
class GoalSheet extends StatefulWidget {
  const GoalSheet(this.state, {super.key});

  final AppState state;

  @override
  State<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<GoalSheet> {
  static const _marks = [10e3, 25e3, 50e3, 100e3, 250e3, 500e3, 1e6, 2.5e6, 5e6, 10e6];

  /// Four round amounts just above what you have now.
  late final _picks = () {
    final v = widget.state.snapshot?.value ?? 0;
    final i = _marks.indexWhere((m) => m >= v * 1.2);
    final from = i < 0 ? _marks.length - 4 : i.clamp(0, _marks.length - 4);
    return _marks.sublist(from, from + 4);
  }();

  late double _amount = widget.state.goal?.amount ?? _suggest();
  late int _year = widget.state.goal?.year ?? DateTime.now().year + 10;

  /// A round number a good way above today's value.
  double _suggest() {
    final v = widget.state.snapshot?.value ?? 0;
    return _marks.firstWhere((m) => m >= v * 1.5, orElse: () => _marks.last);
  }

  /// Steps that fit the size of the number: 5k up to 100k, then 25k, then 100k.
  void _nudge(int dir) {
    final up = dir > 0;
    final base = up ? _amount : _amount - 1;
    final step = base < 100e3 ? 5e3 : base < 500e3 ? 25e3 : 100e3;
    final next = ((_amount + dir * step) / step).round() * step;
    setState(() => _amount = next.clamp(5e3, 10e6).toDouble());
  }

  static String _short(double v) => v >= 1e6 ? '€${(v / 1e6).toStringAsFixed(v % 1e6 == 0 ? 0 : 1)}M' : '€${(v / 1e3).round()}k';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    final had = widget.state.goal != null;
    return ListView(
      padding: EdgeInsets.only(bottom: 24 + browserSafeArea().bottom),
      children: [
        const SheetHeader('Your goal', action: 'Cancel'),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
          child: Text('What you want to have, and by when.', style: sans(15, color: C.ink2, height: 1.45)),
        ),
        Group(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Round('−', () => _nudge(-1)),
                      Expanded(child: Text(eur(_amount, mask: false), textAlign: TextAlign.center, style: figures(serif(40, tracking: -1)))),
                      _Round('+', () => _nudge(1)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [for (final v in _picks) KindChip(_short(v), _amount == v, () => setState(() => _amount = v), compact: true)],
                  ),
                ],
              ),
            ),
            Row2(title: 'By the end of', trailing: _Stepper(text: '$_year', onMinus: () => setState(() => _year = (_year - 1).clamp(now + 1, now + 60)), onPlus: () => setState(() => _year = (_year + 1).clamp(now + 1, now + 60)))),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppButton('Save goal', onTap: () {
            Haptics.confirm();
            widget.state.setPlan(goal: (amount: _amount, year: _year));
            Navigator.of(context).maybePop();
          }),
        ),
        if (had)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: PillButton('Remove goal', onTap: () {
                widget.state.setPlan(goal: null);
                Navigator.of(context).maybePop();
              }),
            ),
          ),
      ],
    );
  }
}
