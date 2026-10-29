import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/safety_tips_catalog.dart';
import '../../ui/hulka_board.dart';
import '../../ui/hulka_look.dart';

class SafetyTipsScreen extends StatefulWidget {
  const SafetyTipsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SafetyTipsScreen> createState() => _SafetyTipsScreenState();
}

class _SafetyTipsScreenState extends State<SafetyTipsScreen> {
  SafetyTipCategory? filter;

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final tips = filter == null
        ? SafetyTipsCatalog.tips
        : SafetyTipsCatalog.byCategory(filter!);
    final canPop = Navigator.of(context).canPop();

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text(
          'Safety from the agencies that publish it.',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: HulkaLook.ink,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          SafetyTipsCatalog.disclaimer,
          style: TextStyle(
            color: HulkaLook.atrium.withValues(alpha: 0.95),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: filter == null,
              onSelected: (_) => setState(() => filter = null),
            ),
            for (final c in SafetyTipCategory.values)
              ChoiceChip(
                label: Text(SafetyTipsCatalog.label(c)),
                selected: filter == c,
                onSelected: (_) => setState(() => filter = c),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _open('tel:999'),
          icon: const Icon(Icons.call),
          label: const Text('Call 999'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _open('tel:112'),
          icon: const Icon(Icons.call_outlined),
          label: const Text('Call 112'),
        ),
        const SizedBox(height: 18),
        for (final tip in tips) ...[
          HulkaBoard(
            title: tip.title,
            subtitle: '${SafetyTipsCatalog.label(tip.category)} · ${tip.year}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.body,
                  style: const TextStyle(color: HulkaLook.ink, height: 1.4),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _open(tip.sourceUrl),
                  child: Text('Source: ${tip.source}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );

    if (!canPop || widget.embedded) return body;
    return Scaffold(
      backgroundColor: HulkaLook.linen,
      appBar: AppBar(title: const Text('Safety tips')),
      body: body,
    );
  }
}
