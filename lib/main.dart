import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_root.dart';
import 'features/wellness/wellness_screen.dart';
import 'firebase_options.dart';
import 'ui/hulka_look.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? setupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    setupError = e;
  }

  runApp(
    ProviderScope(
      child: setupError == null
          ? const HulkaApp()
          : HulkaSetupRequired(message: setupError.toString()),
    ),
  );
}

class HulkaApp extends StatelessWidget {
  const HulkaApp({super.key});

  Widget? _nutritionPreview() {
    const fromDefine = String.fromEnvironment('PREVIEW');
    final preview = fromDefine.isNotEmpty
        ? fromDefine
        : (kDebugMode ? Uri.base.queryParameters['preview'] : null);
    if (preview == 'nutrition') {
      final state = Uri.base.queryParameters['state'];
      return NutritionPreviewPage(linked: state != 'link' && fromDefine != 'nutrition-link');
    }
    if (preview == 'nutrition-link') {
      return const NutritionPreviewPage(linked: false);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hulka',
      debugShowCheckedModeBanner: false,
      theme: HulkaLook.theme(),
      home: _nutritionPreview() ?? const HulkaRoot(),
    );
  }
}
