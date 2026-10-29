import 'package:flutter_test/flutter_test.dart';
import 'package:hulka/app_root.dart';

void main() {
  testWidgets('setup required screen explains missing Firebase config', (tester) async {
    await tester.pumpWidget(const HulkaSetupRequired(message: 'Firebase is not configured'));
    expect(find.text('Hulka requires Firebase configuration'), findsOneWidget);
    expect(find.text('Firebase is not configured'), findsOneWidget);
  });
}
