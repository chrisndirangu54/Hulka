import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hulka/features/more/more_health_screen.dart';
import 'package:hulka/ui/health_workspace.dart';
import 'package:hulka/ui/hulka_board.dart';
import 'package:hulka/ui/hulka_look.dart';

final boundaryKey = GlobalKey();

Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['HULKA_UI_REVIEW_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    if (Platform.environment['HULKA_UI_REVIEW_DIR'] != null) {
      for (final font in [
        ('Segoe UI', 'segoeui.ttf'),
        ('Georgia', 'georgia.ttf'),
      ]) {
        final loader = FontLoader(font.$1)
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/${font.$2}').readAsBytesSync(),
              ),
            ),
          );
        await loader.load();
      }
    }
  });

  for (final viewport in [
    (390.0, 844.0, 'mobile'),
    (1440.0, 1000.0, 'desktop'),
    (320.0, 740.0, 'large-text'),
  ]) {
    testWidgets('More directory stays usable on ${viewport.$3}', (
      tester,
    ) async {
      tester.view.physicalSize = Size(viewport.$1, viewport.$2);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: HulkaLook.theme(),
          home: RepaintBoundary(
            key: boundaryKey,
            child: MediaQuery(
              data: MediaQueryData(
                size: Size(viewport.$1, viewport.$2),
                textScaler: TextScaler.linear(
                  viewport.$3 == 'large-text' ? 1.6 : 1,
                ),
              ),
              child: const Scaffold(body: MoreHealthScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Health profile'), findsOneWidget);
      await capture(tester, 'more-${viewport.$3}');
      await tester.ensureVisible(find.text('Safety tips'));
      await tester.tap(find.text('Safety tips'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Your health, connected.'), findsOneWidget);
    });
  }

  testWidgets('detail frame constrains forms and preserves back navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: HulkaLook.theme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HealthDetailPage(
                    title: 'Health profile',
                    child: HealthPageBody(
                      children: [
                        Text(
                          'Your health details',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        const HulkaBoard(
                          title: 'Personal details',
                          child: HealthFieldPair(
                            first: TextField(
                              decoration: InputDecoration(
                                labelText: 'Full name',
                              ),
                            ),
                            second: TextField(
                              decoration: InputDecoration(
                                labelText: 'Date of birth',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const HealthEmptyState(
                          icon: Icons.favorite_outline,
                          title: 'Your record stays with you',
                          message:
                              'Keep the details your care team relies on up to date.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('Open profile'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    expect(
      tester.getSize(find.byType(HealthPageBody)).width,
      lessThanOrEqualTo(960),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open profile'), findsOneWidget);
  });
}
