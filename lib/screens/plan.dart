import 'package:flutter/widgets.dart';

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
import 'portfolio.dart' show kindNames;

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
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.88,
        semanticLabel: label == '+' ? 'Increase' : 'Decrease',
        child: Container(width: 34, height: 34, alignment: Alignment.center, decoration: const BoxDecoration(color: C.fill, shape: BoxShape.circle), child: Text(label, style: sans(19, color: C.ink))),
      );
}

String _pct(double v) => '${v < 0 ? '−' : ''}${v.abs().toStringAsFixed(v % 1 == 0 ? 0 : 1)}%';

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
                    Row2(
                      title: 'In today’s money',
                      subtitle: 'Takes inflation off the result, so €1,000 means what €1,000 buys now',
                      trailing: _Switch(state.realTerms, (v) => state.setPlan(realTerms: v)),
                    ),
                    Row2(title: 'Inflation', trailing: _Stepper(text: _pct(state.inflation), onMinus: () => state.setPlan(inflation: (state.inflation - 0.5).clamp(0, 10)), onPlus: () => state.setPlan(inflation: (state.inflation + 0.5).clamp(0, 10)))),
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
                  child: AppButton('Back to defaults', filled: false, onTap: () => state.setPlan(returns: {for (final e in defaultReturns.entries) e.key: [...e.value]}, inflation: defaultInflation, raisePercent: 0, realTerms: false)),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 40 + browserSafeArea().bottom)),
            ],
          );
        },
      );
}

class _Switch extends StatelessWidget {
  const _Switch(this.on, this.onChanged);
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.94,
        onTap: () => onChanged(!on),
        semanticLabel: on ? 'On' : 'Off',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 51,
          height: 31,
          padding: const EdgeInsets.all(2),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(color: on ? C.green : C.ink.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
          child: Container(width: 27, height: 27, decoration: BoxDecoration(color: const Color(0xFFFFFFFF), shape: BoxShape.circle, boxShadow: [BoxShadow(color: C.ink.withValues(alpha: 0.25), blurRadius: 3, offset: const Offset(0, 1))])),
        ),
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
