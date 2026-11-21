import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xinpos/app.dart';

void main() {
  testWidgets('xinPOS dashboard loads successfully', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: XinPosApp()));

    await tester.pumpAndSettle();

    expect(find.text('xinPOS'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Total Sales'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
  });
}
