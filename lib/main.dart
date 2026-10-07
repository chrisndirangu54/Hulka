import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? setupError;
  try {
    await Firebase.initializeApp();
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hulka',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C7C78)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const HulkaRoot(),
    );
  }
}
