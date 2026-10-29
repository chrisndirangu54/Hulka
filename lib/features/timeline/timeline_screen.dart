import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../ui/care_scenes.dart';
import '../../ui/hulka_look.dart';
import '../../ui/motion_widgets.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Sign in to view your timeline.'));
    final stream = FirebaseFirestore.instance
        .collection('patients')
        .doc(uid)
        .collection('timeline')
        .orderBy('occurredAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        return CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, child) {
                    final y = _scroll.hasClients ? _scroll.offset : 0.0;
                    final shift = hulkaReduceMotion(context) ? 0.0 : y * 0.38;
                    return ClipRect(
                      child: Transform.translate(
                        offset: Offset(0, shift),
                        child: Transform.scale(scale: 1.16, child: child),
                      ),
                    );
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ScenePhoto(scene: careScenes.first, alignment: Alignment.topCenter),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x3307141A), Color(0xF2F4EFE4)],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StaggerIn(
                              index: 0,
                              child: Text(
                                'The story so far.',
                                style: TextStyle(
                                  fontSize: 32,
                                  height: 1.1,
                                  color: HulkaLook.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            StaggerIn(
                              index: 1,
                              child: Text(
                                'Visits, medicines, devices and notes share one longitudinal tape.',
                                style: TextStyle(color: HulkaLook.atrium, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: CoverflowCarousel(height: 300)),
            if (snap.hasError)
              SliverFillRemaining(child: Center(child: Text('Could not load timeline: ${snap.error}')))
            else if (!snap.hasData)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (docs.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 28, 24, 48),
                  child: Text(
                    'Your longitudinal health timeline will appear here as visits, labs and device readings arrive.',
                    style: TextStyle(color: HulkaLook.atrium, height: 1.4, fontSize: 16),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                sliver: SliverList.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    return StaggerIn(
                      index: i.clamp(0, 8),
                      child: Tilt3D(
                        maxTilt: 0.08,
                        child: Card(
                          color: HulkaLook.paper,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: HulkaLook.copper.withValues(alpha: 0.28)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: HulkaLook.pulse.withValues(alpha: 0.18),
                              child: const Icon(Icons.medical_information_outlined, color: HulkaLook.atrium),
                            ),
                            title: Text((d['title'] as String?) ?? 'Health event'),
                            subtitle: Text((d['summary'] as String?) ?? (d['type'] as String?) ?? ''),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
