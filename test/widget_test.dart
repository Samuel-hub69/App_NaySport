import 'package:flutter_test/flutter_test.dart';
import 'package:naysport/app_state.dart';
import 'package:naysport/main.dart';

void main() {
  testWidgets('La app arranca con el splash', (tester) async {
    await tester.pumpWidget(NaySportApp(state: AppState()));
    expect(find.text('Iniciando...'), findsOneWidget);
  });
}
