import 'package:flutter_test/flutter_test.dart';
import 'package:gecx_banking_acn/main.dart';

void main() {
  testWidgets('App smoke test — renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BankingApp());
    expect(find.text('ACN Bank'), findsWidgets);
  });
}
