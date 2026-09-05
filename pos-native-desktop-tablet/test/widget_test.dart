import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:goldenity_pos_native/main.dart';

void main() {
  testWidgets('App mounts StyleGuide screen without errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GoldenityPOSApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Design System'), findsOneWidget);
  });
}
