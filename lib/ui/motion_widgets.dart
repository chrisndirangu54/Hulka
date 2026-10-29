import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'care_scenes.dart';
import 'hulka_look.dart';

class ScenePhoto extends StatelessWidget {
  const ScenePhoto({super.key, required this.scene, this.alignment = Alignment.center});

  final CareScene scene;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      scene.asset,
      fit: BoxFit.cover,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Image.network(
        scene.url,
        fit: BoxFit.cover,
        alignment: alignment,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: HulkaLook.atrium,
          child: Center(child: Icon(scene.icon, color: HulkaLook.copper, size: 56)),
        ),
      ),
    );
  }
}

/// Full-bleed autoplay backdrop. Layers drift at different rates for parallax.
class ParallaxBackdrop extends StatefulWidget {
  const ParallaxBackdrop({super.key, this.pointer = Offset.zero});

  final Offset pointer;

  @override
  State<ParallaxBackdrop> createState() => _ParallaxBackdropState();
}

class _ParallaxBackdropState extends State<ParallaxBackdrop> {
  late final PageController _pages;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || hulkaReduceMotion(context) || !_pages.hasClients) return;
      final next = (_index + 1) % careScenes.length;
      _pages.animateToPage(next, duration: HulkaLook.carousel, curve: HulkaLook.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = hulkaReduceMotion(context);
    final px = reduce ? 0.0 : widget.pointer.dx * 18;
    final py = reduce ? 0.0 : widget.pointer.dy * 12;

    return Transform.translate(
      offset: Offset(px, py),
      child: Transform.scale(
        scale: 1.08,
        child: PageView.builder(
          controller: _pages,
          physics: reduce ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
          onPageChanged: (i) => _index = i,
          itemCount: careScenes.length,
          itemBuilder: (context, i) {
            return AnimatedBuilder(
              animation: _pages,
              builder: (context, child) {
                var delta = 0.0;
                if (_pages.hasClients && _pages.position.haveDimensions) {
                  delta = (_pages.page ?? i.toDouble()) - i;
                }
                final shift = reduce ? 0.0 : delta * 56;
                return ClipRect(
                  child: Transform.translate(
                    offset: Offset(shift, 0),
                    child: child,
                  ),
                );
              },
              child: ScenePhoto(scene: careScenes[i]),
            );
          },
        ),
      ),
    );
  }
}

/// Pointer-driven 3D tilt. Transform and opacity only.
class Tilt3D extends StatefulWidget {
  const Tilt3D({super.key, required this.child, this.maxTilt = 0.16, this.padding = EdgeInsets.zero});

  final Widget child;
  final double maxTilt;
  final EdgeInsets padding;

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> {
  double _rx = 0;
  double _ry = 0;

  void _aim(Offset local, Size size) {
    if (hulkaReduceMotion(context) || size.width == 0 || size.height == 0) return;
    setState(() {
      _ry = ((local.dx / size.width) - 0.5) * 2 * widget.maxTilt;
      _rx = ((local.dy / size.height) - 0.5) * -2 * widget.maxTilt;
    });
  }

  void _reset() => setState(() {
        _rx = 0;
        _ry = 0;
      });

  @override
  Widget build(BuildContext context) {
    final reduce = hulkaReduceMotion(context);
    return MouseRegion(
      onHover: (e) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        _aim(e.localPosition, box.size);
      },
      onExit: (_) => _reset(),
      child: Listener(
        onPointerMove: (e) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          _aim(box.globalToLocal(e.position), box.size);
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: reduce ? 0 : 1),
          duration: HulkaLook.ui,
          curve: HulkaLook.easeOut,
          builder: (context, t, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.00115)
                ..rotateX(_rx * t)
                ..rotateY(_ry * t),
              child: child,
            );
          },
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

/// 3D coverflow carousel with inner-image parallax.
class CoverflowCarousel extends StatefulWidget {
  const CoverflowCarousel({super.key, this.height = 320, this.onChanged});

  final double height;
  final ValueChanged<int>? onChanged;

  @override
  State<CoverflowCarousel> createState() => CoverflowCarouselState();
}

class CoverflowCarouselState extends State<CoverflowCarousel> {
  late final PageController _pages;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pages = PageController(viewportFraction: 0.78);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || hulkaReduceMotion(context) || !_pages.hasClients) return;
      final next = (_index + 1) % careScenes.length;
      _pages.animateToPage(next, duration: HulkaLook.carousel, curve: HulkaLook.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = hulkaReduceMotion(context);
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pages,
            itemCount: careScenes.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onChanged?.call(i);
            },
            itemBuilder: (context, i) {
              return AnimatedBuilder(
                animation: _pages,
                builder: (context, child) {
                  var delta = 0.0;
                  if (_pages.hasClients && _pages.position.haveDimensions) {
                    delta = (_pages.page ?? i.toDouble()) - i;
                  }
                  final rot = reduce ? 0.0 : delta * 0.72;
                  final z = reduce ? 0.0 : -delta.abs() * 90;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..translateByDouble(0.0, 0.0, z, 1.0)
                      ..rotateY(rot),
                    child: child,
                  );
                },
                child: _CoverCard(scene: careScenes[i], controller: _pages, index: i),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < careScenes.length; i++)
              AnimatedContainer(
                duration: HulkaLook.ui,
                curve: HulkaLook.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: i == _index ? 22 : 6,
                decoration: BoxDecoration(
                  color: i == _index ? HulkaLook.copper : HulkaLook.atrium.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CoverCard extends StatelessWidget {
  const _CoverCard({required this.scene, required this.controller, required this.index});

  final CareScene scene;
  final PageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                var delta = 0.0;
                if (controller.hasClients && controller.position.haveDimensions) {
                  delta = (controller.page ?? index.toDouble()) - index;
                }
                return Transform.translate(
                  offset: Offset(delta * -42, 0),
                  child: Transform.scale(scale: 1.12, child: child),
                );
              },
              child: ScenePhoto(scene: scene),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x0007141A), Color(0xCC07141A)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scene.kicker,
                    style: const TextStyle(color: HulkaLook.copper, fontSize: 13, letterSpacing: 0.2),
                  ),
                  const Spacer(),
                  Text(
                    scene.title,
                    style: const TextStyle(
                      color: HulkaLook.linen,
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rotating 3D photo ring plus a painted copper/teal helix.
class OrbitGallery extends StatefulWidget {
  const OrbitGallery({super.key, this.size = 320});

  final double size;

  @override
  State<OrbitGallery> createState() => _OrbitGalleryState();
}

class _OrbitGalleryState extends State<OrbitGallery> with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 22))..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = hulkaReduceMotion(context);
    if (reduce) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _HelixPainter(0.12)),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) {
          final t = _spin.value * math.pi * 2;
          final cards = <_OrbitCard>[];
          for (var i = 0; i < 5; i++) {
            final a = t + i * (math.pi * 2 / 5);
            final x = math.sin(a) * widget.size * 0.34;
            final z = math.cos(a) * widget.size * 0.34;
            cards.add(_OrbitCard(index: i, x: x, z: z, angle: a));
          }
          cards.sort((a, b) => a.z.compareTo(b.z));

          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: Size.square(widget.size), painter: _HelixPainter(_spin.value)),
              for (final card in cards)
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0014)
                    ..translateByDouble(card.x, math.sin(card.angle) * 10, card.z, 1.0)
                    ..rotateY(card.angle * 0.35),
                  child: Opacity(
                    opacity: (0.45 + (card.z + widget.size * 0.34) / (widget.size * 0.9)).clamp(0.35, 1),
                    child: _OrbitPhoto(scene: careScenes[card.index % careScenes.length]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OrbitCard {
  const _OrbitCard({required this.index, required this.x, required this.z, required this.angle});
  final int index;
  final double x;
  final double z;
  final double angle;
}

class _OrbitPhoto extends StatelessWidget {
  const _OrbitPhoto({required this.scene});
  final CareScene scene;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 108,
        height: 148,
        child: ScenePhoto(scene: scene),
      ),
    );
  }
}

class _HelixPainter extends CustomPainter {
  const _HelixPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final copper = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = HulkaLook.copper.withValues(alpha: 0.85);
    final teal = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = HulkaLook.pulse.withValues(alpha: 0.7);

    for (var ring = 0; ring < 4; ring++) {
      final rx = size.width * (0.18 + ring * 0.08);
      final ry = size.height * (0.08 + ring * 0.04);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(t * math.pi * 2 * (ring.isEven ? 1 : -1) * 0.35 + ring);
      canvas.scale(1, 0.42 + ring * 0.04);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), ring.isEven ? copper : teal);
      canvas.restore();
    }

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [HulkaLook.pulse.withValues(alpha: 0.55), const Color(0x00000000)],
      ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.22));
    canvas.drawCircle(c, size.width * 0.18, glow);
  }

  @override
  bool shouldRepaint(covariant _HelixPainter oldDelegate) => oldDelegate.t != t;
}

class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: HulkaLook.press,
        curve: HulkaLook.easeOut,
        child: widget.child,
      ),
    );
  }
}

class FrostPanel extends StatelessWidget {
  const FrostPanel({super.key, required this.child, this.padding = const EdgeInsets.all(28)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: HulkaLook.linen.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: HulkaLook.copper.withValues(alpha: 0.45)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class StaggerIn extends StatelessWidget {
  const StaggerIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (hulkaReduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index * 55).clamp(0, 280)),
      curve: HulkaLook.easeOut,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
