import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hulka/features/wellness/nutrition_workspace.dart';
import 'package:hulka/ui/hulka_look.dart';

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(1280, 900)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: HulkaLook.theme(),
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: true),
        child: Scaffold(backgroundColor: HulkaLook.linen, body: child),
      ),
    ),
  );
}

NutritionWorkspace _workspace({required bool linked}) {
  return NutritionWorkspace(
    restoring: false,
    linking: false,
    loading: false,
    saving: false,
    analyzing: false,
    cartBusy: false,
    linkedEmail: linked ? 'ada@sokonis.shop' : null,
    intelligence: linked ? NutritionWorkspace.sampleIntelligence() : null,
    entries: linked
        ? const [
            NutritionLogRow(type: 'meal', note: 'Ugali and sukuma', value: 1, unit: 'plate'),
          ]
        : const [],
    products: const [],
    entryType: 'meal',
    email: TextEditingController(text: 'ada@sokonis.shop'),
    password: TextEditingController(),
    search: TextEditingController(),
    note: TextEditingController(text: 'ugali, sukuma'),
    value: TextEditingController(),
    unit: TextEditingController(),
    error: null,
    message: null,
    onLink: () {},
    onUnlink: () {},
    onRefresh: () {},
    onSearch: () {},
    onAnalyze: () {},
    onAddEntry: () {},
    onAddToCart: (_) {},
    onEntryType: (_) {},
  );
}

void main() {
  testWidgets('unlinked nutrition asks to link Sokonis', (tester) async {
    await _pump(tester, _workspace(linked: false));
    expect(find.text('The plate that talks to the shelf.'), findsOneWidget);
    expect(find.text('Link Sokonis account'), findsOneWidget);
    expect(find.text('Keep a Hulka log'), findsOneWidget);
  });

  testWidgets('linked nutrition shows score, pantry and meals', (tester) async {
    await _pump(tester, _workspace(linked: true));
    expect(find.text('Sokonis is reading the plate.'), findsOneWidget);
    expect(find.text('ada@sokonis.shop'), findsOneWidget);
    expect(find.text('On the shelf'), findsOneWidget);
    expect(find.text('Cook from this shelf'), findsOneWidget);
    expect(find.text('Sukuma wiki'), findsWidgets);
    expect(find.text('Ndengu stew + rice'), findsOneWidget);
    expect(find.text('Find it on Sokonis'), findsOneWidget);
  });
}
