import 'package:flutter_test/flutter_test.dart';

import 'package:sticky_path/main.dart';

void main() {
  testWidgets('Welcome screen shows brand, copy and CTA', (tester) async {
    await tester.pumpWidget(const StickyPathApp());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('StickyPath'), findsOneWidget);
    expect(find.textContaining('Small actions.'), findsOneWidget);
    expect(find.text('One day at a time.'), findsOneWidget);
    expect(find.text('Start your path  →'), findsOneWidget);
    expect(find.text('90 DAYS  •  ONE PATH  •  ONE DAY AT A TIME'), findsOneWidget);
  });
}
