import 'package:flutter_test/flutter_test.dart';
import 'package:weekly_diet/main.dart';

void main() {
  testWidgets('Sin configuración muestra el aviso', (tester) async {
    await tester.pumpWidget(const WeeklyDietApp());
    expect(find.textContaining('Falta la configuración'), findsOneWidget);
  });
}
