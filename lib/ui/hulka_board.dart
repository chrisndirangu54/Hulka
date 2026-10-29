import 'package:flutter/material.dart';

import 'hulka_look.dart';

class HulkaBoard extends StatelessWidget {
  const HulkaBoard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HulkaLook.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HulkaLook.copper.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HulkaLook.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(color: HulkaLook.atrium.withValues(alpha: 0.9), height: 1.35),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
