import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_future/demo.dart';
import 'package:the_future/projection.dart';
import 'package:the_future/ui/history.dart';

void main() {
  testWidgets('switching tabs keeps the chart in place while the new line is built', (tester) async {
    final s = demoSnapshot();
    Widget chart(Set<Kind>? only) => Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            // In a scroll view, as on the page: the chart is as tall as what it holds.
            child: SingleChildScrollView(child: ValueHistory(s, only: only, compare: true, onCompare: (_) {})),
          ),
        );
    await tester.pumpWidget(chart(null));
    await tester.pump(const Duration(seconds: 1));
    final height = tester.getSize(find.byType(ValueHistory)).height;
    expect(find.text('Compare with MSCI World'), findsOneWidget);

    // The crypto line is built from prices and arrives later; the very next frame must not move.
    await tester.pumpWidget(chart({Kind.crypto}));
    expect(tester.getSize(find.byType(ValueHistory)).height, height, reason: 'the frame right after the switch');
    expect(find.text('Compare with MSCI World'), findsOneWidget);
    expect(find.textContaining('MSCI World', skipOffstage: false), findsNWidgets(2), reason: 'the line about MSCI World stays too');

    await tester.pump(const Duration(seconds: 1));
    expect(tester.getSize(find.byType(ValueHistory)).height, height, reason: 'and once the crypto line is there');
  });
}
