import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/app/app.dart';

void main() {
  testWidgets('GdzsApp starts on the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GdzsApp());

    expect(tester.takeException(), isNull);
  });
}
