import 'package:flutter_test/flutter_test.dart';

import 'package:leafsnap_ai/main.dart';

void main() {
  testWidgets('privacy gate leads into a single animated feature film and home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(initialization: Future<void>.value()));
    await tester.pump(const Duration(milliseconds: 5100));

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Know every plant you spot'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Identify any plant in seconds'), findsOneWidget);
    expect(find.text('Open app'), findsOneWidget);
    expect(find.text('Your tomato needs water tomorrow'), findsNothing);

    await tester.pump(const Duration(milliseconds: 6200));

    expect(find.text('Know what your plant needs'), findsOneWidget);
    expect(find.text('Open app'), findsOneWidget);

    await tester.tap(find.text('Open app'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Home'), findsOneWidget);
  });
}
