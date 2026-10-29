import 'package:flutter/material.dart';
import 'hulka_look.dart';

/// A complete route for the health tools opened from More.
class HealthDetailPage extends StatelessWidget {
  const HealthDetailPage({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(
          fontFamily: 'Segoe UI',
          bodyColor: HulkaLook.ink,
          displayColor: HulkaLook.ink,
        ),
        cardTheme: CardThemeData(
          color: HulkaLook.paper,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: HulkaLook.atrium.withValues(alpha: .12)),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: HulkaLook.linen,
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class HealthPageBody extends StatelessWidget {
  const HealthPageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
      24,
      MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
      40,
    ),
    children: children,
  );
}

class HealthEmptyState extends StatelessWidget {
  const HealthEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: HulkaLook.paper,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: HulkaLook.atrium.withValues(alpha: .12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF0E6F6A), size: 30),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          style: const TextStyle(color: HulkaLook.atrium, height: 1.5),
        ),
      ],
    ),
  );
}

class HealthFieldPair extends StatelessWidget {
  const HealthFieldPair({super.key, required this.first, required this.second});
  final Widget first;
  final Widget second;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 16), second],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      );
    },
  );
}
