import 'package:flutter/material.dart';

import '../../services/nutrition_health_sync.dart';
import '../../services/sokonis_client.dart';
import '../../ui/hulka_look.dart';
import '../../ui/motion_widgets.dart';

/// Presentational Nutrition tab. Firebase stays in [WellnessScreen].
class NutritionWorkspace extends StatelessWidget {
  const NutritionWorkspace({
    super.key,
    this.healthSyncCard,
    required this.restoring,
    required this.linking,
    required this.loading,
    required this.saving,
    required this.analyzing,
    required this.cartBusy,
    required this.linkedEmail,
    required this.intelligence,
    required this.entries,
    required this.products,
    required this.entryType,
    required this.email,
    required this.password,
    required this.search,
    required this.note,
    required this.value,
    required this.unit,
    required this.error,
    required this.message,
    required this.onLink,
    required this.onUnlink,
    required this.onRefresh,
    required this.onSearch,
    required this.onAnalyze,
    required this.onAddEntry,
    required this.onAddToCart,
    required this.onEntryType,
  });

  final Widget? healthSyncCard;
  final bool restoring;
  final bool linking;
  final bool loading;
  final bool saving;
  final bool analyzing;
  final bool cartBusy;
  final String? linkedEmail;
  final SokonisIntelligence? intelligence;
  final List<NutritionLogRow> entries;
  final List<SokonisProduct> products;
  final String entryType;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController search;
  final TextEditingController note;
  final TextEditingController value;
  final TextEditingController unit;
  final String? error;
  final String? message;
  final VoidCallback onLink;
  final VoidCallback onUnlink;
  final VoidCallback onRefresh;
  final VoidCallback onSearch;
  final VoidCallback onAnalyze;
  final VoidCallback onAddEntry;
  final ValueChanged<List<String>> onAddToCart;
  final ValueChanged<String> onEntryType;

  bool get linked => linkedEmail != null && linkedEmail!.isNotEmpty;

  static SokonisIntelligence sampleIntelligence() {
    return const SokonisIntelligence(
      mcpReachable: false,
      source: 'Sokonis account (Firestore)',
      overall: 72,
      level: 4,
      xp: 340,
      coins: 18,
      bodyStory:
          'Protein is holding. Leafy greens have been thin this week — sukuma, spinach or managu would lift the score.',
      systems: {'gut': 68, 'energy': 74, 'inflammation': 61, 'recovery': 70},
      pantry: [
        SokonisProduct(
          id: 'p1',
          name: 'Sukuma wiki',
          calories: 36,
          hasHealthBenefits: true,
        ),
        SokonisProduct(
          id: 'p2',
          name: 'Ndengu',
          calories: 118,
          hasHealthBenefits: true,
        ),
        SokonisProduct(id: 'p3', name: 'Mchele', calories: 206),
        SokonisProduct(id: 'p4', name: 'Mayai', calories: 78),
      ],
      meals: [
        SokonisMeal(
          name: 'Ndengu stew + rice',
          uses: ['ndengu', 'mchele', 'onion'],
        ),
        SokonisMeal(
          name: 'Sukuma with eggs',
          uses: ['sukuma wiki', 'mayai', 'tomato'],
        ),
        SokonisMeal(
          name: 'Grilled tilapia + greens',
          uses: ['tilapia', 'sukuma', 'lemon'],
        ),
      ],
      analysis: SokonisNutritionReport(
        foods: ['ugali', 'sukuma'],
        matches: [
          SokonisProduct(id: 'm1', name: 'Unga wa mahindi', calories: 130),
          SokonisProduct(
            id: 'm2',
            name: 'Sukuma wiki',
            calories: 36,
            hasHealthBenefits: true,
          ),
        ],
        notes: [
          'Matched two shelf items from the Sokonis catalog.',
          sokonisDisclaimer,
        ],
        calories: 166,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (restoring) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Hero(linked: linked, intelligence: intelligence),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          sliver: SliverList.list(
            children: [
              if (linked && healthSyncCard != null) ...[
                healthSyncCard!,
                const SizedBox(height: 18),
              ],
              if (error != null) _Banner(text: error!, tone: HulkaLook.ember),
              if (message != null)
                _Banner(text: message!, tone: HulkaLook.atrium),
              if (!linked) ...[
                StaggerIn(
                  index: 0,
                  child: _LinkPanel(
                    email: email,
                    password: password,
                    linking: linking,
                    onLink: onLink,
                  ),
                ),
                const SizedBox(height: 22),
              ] else ...[
                _AccountBar(
                  email: linkedEmail!,
                  source: intelligence?.source ?? 'Sokonis',
                  mcp: intelligence?.mcpReachable ?? false,
                  loading: loading,
                  onRefresh: onRefresh,
                  onUnlink: onUnlink,
                ),
                const SizedBox(height: 18),
                if (intelligence != null) ...[
                  _SystemsStrip(systems: intelligence!.systems),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 860;
                      final pantry = _PantryBoard(items: intelligence!.pantry);
                      final meals = _MealBoard(
                        meals: intelligence!.meals,
                        busy: cartBusy,
                        onSend: onAddToCart,
                      );
                      if (!wide) {
                        return Column(
                          children: [pantry, const SizedBox(height: 14), meals],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: pantry),
                          const SizedBox(width: 14),
                          Expanded(child: meals),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _ShelfSearch(
                    search: search,
                    products: products,
                    busy: loading,
                    cartBusy: cartBusy,
                    onSearch: onSearch,
                    onAddToCart: onAddToCart,
                  ),
                  const SizedBox(height: 18),
                  _AnalysisCard(
                    note: note,
                    analyzing: analyzing,
                    report: intelligence!.analysis,
                    onAnalyze: onAnalyze,
                  ),
                  const SizedBox(height: 18),
                ],
              ],
              _LogCard(
                type: entryType,
                note: note,
                value: value,
                unit: unit,
                saving: saving,
                onType: onEntryType,
                onSave: onAddEntry,
              ),
              const SizedBox(height: 18),
              _EntryList(entries: entries),
              const SizedBox(height: 16),
              Text(
                intelligence?.disclaimer ?? sokonisDisclaimer,
                style: TextStyle(
                  color: HulkaLook.atrium.withValues(alpha: 0.72),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NutritionLogRow {
  const NutritionLogRow({
    required this.type,
    required this.note,
    this.value,
    this.unit,
  });

  final String type;
  final String note;
  final num? value;
  final String? unit;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.linked, required this.intelligence});

  final bool linked;
  final SokonisIntelligence? intelligence;

  @override
  Widget build(BuildContext context) {
    final score = intelligence?.overall;
    return SizedBox(
      height: 228,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HulkaLook.ink, HulkaLook.atrium],
              ),
            ),
          ),
          Positioned(
            right: -40,
            top: -30,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(280, 280),
                painter: _HaloPainter(
                  progress: ((score ?? 0) / 100).clamp(0, 1).toDouble(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Row(
              children: [
                if (linked && score != null) ...[
                  _ScoreRing(score: score.toDouble()),
                  const SizedBox(width: 18),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        linked
                            ? 'Sokonis is reading the plate.'
                            : 'The plate that talks to the shelf.',
                        style: const TextStyle(
                          color: HulkaLook.linen,
                          fontSize: 28,
                          height: 1.08,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        linked
                            ? (intelligence?.bodyStory ??
                                  'Wellness score, pantry and Kenyan meal ideas come from the linked Sokonis account.')
                            : 'Link the Sokonis grocery account you already use. Hulka scores meals against that shelf.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HulkaLook.linen.withValues(alpha: 0.82),
                          height: 1.35,
                        ),
                      ),
                      if (linked && intelligence != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Level ${intelligence!.level}, ${intelligence!.xp} experience, ${intelligence!.coins} coins',
                          style: const TextStyle(
                            color: HulkaLook.copper,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: CustomPaint(
        painter: _RingPainter(progress: (score / 100).clamp(0, 1)),
        child: Center(
          child: Text(
            score.round().toString(),
            style: const TextStyle(
              color: HulkaLook.linen,
              fontSize: 34,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 6;
    final track = Paint()
      ..color = HulkaLook.linen.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    final arc = Paint()
      ..color = HulkaLook.copper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.57,
      progress * 6.2832,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HulkaLook.pulse.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.45),
      90 + progress * 20,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) => old.progress != progress;
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.tone});
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(text, style: TextStyle(color: tone, height: 1.35)),
        ),
      ),
    );
  }
}

class _LinkPanel extends StatelessWidget {
  const _LinkPanel({
    required this.email,
    required this.password,
    required this.linking,
    required this.onLink,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool linking;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Link Sokonis',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: HulkaLook.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the email and password for sokonis.shop. Hulka keeps only the account id — never the password.',
            style: TextStyle(
              color: HulkaLook.atrium.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Sokonis email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            onSubmitted: (_) => onLink(),
            decoration: const InputDecoration(labelText: 'Sokonis password'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: linking ? null : onLink,
            child: Text(linking ? 'Linking…' : 'Link Sokonis account'),
          ),
        ],
      ),
    );
  }
}

class _AccountBar extends StatelessWidget {
  const _AccountBar({
    required this.email,
    required this.source,
    required this.mcp,
    required this.loading,
    required this.onRefresh,
    required this.onUnlink,
  });

  final String email;
  final String source;
  final bool mcp;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HulkaLook.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HulkaLook.copper.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: mcp ? HulkaLook.pulse : HulkaLook.copper,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: HulkaLook.ink,
                    ),
                  ),
                  Text(
                    mcp
                        ? source
                        : '$source — MCP is offline, reading the live grocery account',
                    style: TextStyle(
                      fontSize: 12,
                      color: HulkaLook.atrium.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh intelligence',
              onPressed: loading ? null : onRefresh,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
            TextButton(onPressed: onUnlink, child: const Text('Unlink')),
          ],
        ),
      ),
    );
  }
}

class _SystemsStrip extends StatelessWidget {
  const _SystemsStrip({required this.systems});
  final Map<String, num> systems;

  @override
  Widget build(BuildContext context) {
    if (systems.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How the body is scoring',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HulkaLook.ink,
          ),
        ),
        const SizedBox(height: 10),
        for (final e in systems.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    e.key,
                    style: const TextStyle(color: HulkaLook.atrium),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (e.value / 100).clamp(0, 1).toDouble(),
                      minHeight: 8,
                      backgroundColor: HulkaLook.atrium.withValues(alpha: 0.12),
                      color: HulkaLook.pulse,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${e.value.round()}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: HulkaLook.ink),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PantryBoard extends StatelessWidget {
  const _PantryBoard({required this.items});
  final List<SokonisProduct> items;

  @override
  Widget build(BuildContext context) {
    return _Board(
      title: 'On the shelf',
      child: items.isEmpty
          ? const Text(
              'Sokonis has not listed pantry items on this account yet.',
            )
          : Column(
              children: [
                for (final p in items.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          p.hasHealthBenefits
                              ? Icons.eco_outlined
                              : Icons.circle_outlined,
                          size: 16,
                          color: p.hasHealthBenefits
                              ? HulkaLook.pulse
                              : HulkaLook.copper,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.name,
                            style: const TextStyle(color: HulkaLook.ink),
                          ),
                        ),
                        if (p.calories != null)
                          Text(
                            '${p.calories} kcal',
                            style: const TextStyle(
                              color: HulkaLook.atrium,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MealBoard extends StatelessWidget {
  const _MealBoard({
    required this.meals,
    required this.busy,
    required this.onSend,
  });
  final List<SokonisMeal> meals;
  final bool busy;
  final ValueChanged<List<String>> onSend;

  @override
  Widget build(BuildContext context) {
    return _Board(
      title: 'Cook from this shelf',
      child: meals.isEmpty
          ? const Text('No meal ideas yet. Link the account and refresh.')
          : Column(
              children: [
                for (final meal in meals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meal.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: HulkaLook.ink,
                                ),
                              ),
                              Text(
                                meal.uses.join(', '),
                                style: TextStyle(
                                  color: HulkaLook.atrium.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: busy || meal.uses.isEmpty
                              ? null
                              : () => onSend(meal.uses),
                          child: const Text('Send to cart'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HulkaLook.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HulkaLook.copper.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HulkaLook.ink,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ShelfSearch extends StatelessWidget {
  const _ShelfSearch({
    required this.search,
    required this.products,
    required this.busy,
    required this.cartBusy,
    required this.onSearch,
    required this.onAddToCart,
  });

  final TextEditingController search;
  final List<SokonisProduct> products;
  final bool busy;
  final bool cartBusy;
  final VoidCallback onSearch;
  final ValueChanged<List<String>> onAddToCart;

  @override
  Widget build(BuildContext context) {
    return _Board(
      title: 'Find it on Sokonis',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  decoration: const InputDecoration(
                    labelText: 'Sukuma, ndengu, milk…',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: busy ? null : onSearch,
                child: const Text('Search'),
              ),
            ],
          ),
          if (products.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final p in products.take(8))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(p.name),
                subtitle: Text(
                  [
                    if (p.price != null) 'KES ${p.price}',
                    if (p.calories != null) '${p.calories} kcal',
                    if (p.hasHealthBenefits) 'health tagged',
                  ].join(', '),
                ),
                trailing: TextButton(
                  onPressed: cartBusy ? null : () => onAddToCart([p.name]),
                  child: const Text('Cart'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.note,
    required this.analyzing,
    required this.report,
    required this.onAnalyze,
  });

  final TextEditingController note;
  final bool analyzing;
  final SokonisNutritionReport? report;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return _Board(
      title: 'Score what you ate',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Foods, comma separated',
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: analyzing ? null : onAnalyze,
              child: Text(analyzing ? 'Scoring…' : 'Ask Sokonis'),
            ),
          ),
          if (report != null) ...[
            const SizedBox(height: 12),
            if (report!.calories != null)
              Text(
                'About ${report!.calories} kcal from matched shelf items.',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: HulkaLook.ink,
                ),
              ),
            for (final n in report!.notes.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  n,
                  style: const TextStyle(color: HulkaLook.atrium, height: 1.35),
                ),
              ),
            for (final m in report!.matches.take(4))
              Text('· ${m.name}', style: const TextStyle(color: HulkaLook.ink)),
          ],
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.type,
    required this.note,
    required this.value,
    required this.unit,
    required this.saving,
    required this.onType,
    required this.onSave,
  });

  final String type;
  final TextEditingController note;
  final TextEditingController value;
  final TextEditingController unit;
  final bool saving;
  final ValueChanged<String> onType;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _Board(
      title: 'Keep a Hulka log',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(type),
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Entry type'),
            items: const [
              DropdownMenuItem(value: 'meal', child: Text('Meal / nutrition')),
              DropdownMenuItem(
                value: 'activity',
                child: Text('Activity / exercise'),
              ),
              DropdownMenuItem(value: 'sleep', child: Text('Sleep')),
              DropdownMenuItem(
                value: 'rehabilitation',
                child: Text('Rehabilitation'),
              ),
              DropdownMenuItem(
                value: 'symptom',
                child: Text('Symptom / wellbeing'),
              ),
            ],
            onChanged: (next) {
              if (next != null) onType(next);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Value (optional)',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit (optional)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: const Icon(Icons.add),
            label: Text(saving ? 'Saving…' : 'Add entry'),
          ),
        ],
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});
  final List<NutritionLogRow> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent entries',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: HulkaLook.ink,
          ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty) const Text('No wellness entries yet.'),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HulkaLook.paper,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.self_improvement_outlined,
                  color: HulkaLook.pulse,
                ),
                title: Text(e.type),
                subtitle: Text(e.note),
                trailing: e.value == null
                    ? null
                    : Text('${e.value} ${e.unit ?? ''}'),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// NutritionHealthSyncCard — drop-in health-aware header card for the
// nutrition tab. Insert above the main NutritionWorkspace in WellnessScreen.
// ---------------------------------------------------------------------------

/// Drop-in health-aware header card for the nutrition tab.
/// Insert above the main NutritionWorkspace in WellnessScreen.
class NutritionHealthSyncCard extends StatefulWidget {
  const NutritionHealthSyncCard({
    super.key,
    required this.sokonisClient,
    required this.uid,
    required this.recentFoods,
  });

  final SokonisClient sokonisClient;
  final String uid;
  final List<String> recentFoods;

  @override
  State<NutritionHealthSyncCard> createState() =>
      _NutritionHealthSyncCardState();
}

class _NutritionHealthSyncCardState extends State<NutritionHealthSyncCard> {
  NutritionSyncReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant NutritionHealthSyncCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.recentFoods.join('|') != widget.recentFoods.join('|')) {
      _sync();
    }
  }

  int _generation = 0;
  Future<void> _sync() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await NutritionHealthSync(
        widget.sokonisClient,
      ).sync(widget.uid, recentFoods: widget.recentFoods);
      if (mounted && generation == _generation) {
        setState(() => _report = report);
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HulkaLook.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HulkaLook.copper.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.health_and_safety_outlined,
                  color: HulkaLook.pulse,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Health & Nutrition Sync',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HulkaLook.ink,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_outlined, size: 20),
                  color: HulkaLook.atrium,
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _sync,
                ),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
            ] else if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: HulkaLook.ember, height: 1.35),
              ),
            ] else if (_report != null) ...[
              // Health alerts (amber chips)
              if (_report!.healthAlerts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _report!.healthAlerts
                      .map(
                        (alert) => Chip(
                          avatar: const Icon(
                            Icons.warning_amber_outlined,
                            size: 16,
                          ),
                          label: Text(
                            alert,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: const Color(0xFFFFF3CD),
                          side: const BorderSide(
                            color: Color(0xFFFFC107),
                            width: 0.8,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      )
                      .toList(),
                ),
              ],
              // Avoid list (red chips)
              if (_report!.avoidList.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _report!.avoidList
                      .map(
                        (item) => Chip(
                          label: Text(
                            'Avoid: $item',
                            style: const TextStyle(
                              fontSize: 12,
                              color: HulkaLook.paper,
                            ),
                          ),
                          backgroundColor: HulkaLook.ember,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      )
                      .toList(),
                ),
              ],
              // Dietary recommendations (green bullets)
              if (_report!.dietaryRecommendations.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...() {
                  // The last item is always the disclaimer — render separately
                  final recs = _report!.dietaryRecommendations;
                  final body = recs.length > 1
                      ? recs.sublist(0, recs.length - 1)
                      : recs;
                  final disclaimer = recs.length > 1 ? recs.last : null;
                  return [
                    ...body.map(
                      (rec) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                rec,
                                style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (disclaimer != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        disclaimer,
                        style: TextStyle(
                          fontSize: 11,
                          color: HulkaLook.atrium.withValues(alpha: 0.65),
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ];
                }(),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
