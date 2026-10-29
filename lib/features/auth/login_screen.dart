import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../ui/hulka_look.dart';
import '../../ui/motion_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final displayName = TextEditingController();
  bool loading = false;
  bool registerMode = false;
  String? error;
  String? info;
  Offset pointer = Offset.zero;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    displayName.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
      info = null;
    });

    try {
      if (registerMode) {
        final name = displayName.text.trim();
        if (name.isEmpty) throw FirebaseAuthException(code: 'missing-name', message: 'Display name is required.');
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
        await credential.user!.updateDisplayName(name);
        await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
          'email': email.text.trim(),
          'displayName': name,
          'role': 'patient',
          'verified': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('patients').doc(credential.user!.uid).set({
          'displayName': name,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await credential.user!.sendEmailVerification();
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? e.code);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    final value = email.text.trim();
    if (value.isEmpty) {
      setState(() => error = 'Enter your email address first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: value);
      setState(() {
        error = null;
        info = 'Password reset instructions were sent to $value.';
      });
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? e.code);
    }
  }

  void _trackPointer(PointerEvent event, Size size) {
    if (hulkaReduceMotion(context) || size.width == 0 || size.height == 0) return;
    setState(() {
      pointer = Offset(
        (event.localPosition.dx / size.width) - 0.5,
        (event.localPosition.dy / size.height) - 0.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HulkaLook.ink,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          return Listener(
            onPointerHover: (e) => _trackPointer(e, Size(constraints.maxWidth, constraints.maxHeight)),
            onPointerMove: (e) => _trackPointer(e, Size(constraints.maxWidth, constraints.maxHeight)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ParallaxBackdrop(pointer: pointer),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        HulkaLook.ink.withValues(alpha: wide ? 0.55 : 0.72),
                        HulkaLook.ink.withValues(alpha: 0.28),
                        HulkaLook.atrium.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: wide
                      ? Row(
                          children: [
                            Expanded(flex: 6, child: _Showcase(pointer: pointer)),
                            Expanded(
                              flex: 5,
                              child: Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                                  child: _form(maxWidth: 430),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              const OrbitGallery(size: 240),
                              const SizedBox(height: 12),
                              CoverflowCarousel(height: 220),
                              const SizedBox(height: 20),
                              _form(maxWidth: 460),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _form({required double maxWidth}) {
    return Tilt3D(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: FrostPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Hulka',
                style: TextStyle(fontSize: 18, color: HulkaLook.pulse, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                registerMode ? 'Write yourself into the record.' : 'Care that keeps the same story.',
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.12,
                  color: HulkaLook.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                registerMode
                    ? 'A patient identity that hospitals, pharmacies and devices can share with your consent.'
                    : 'Hospitals, pharmacies, devices and clinicians read one consent-aware timeline.',
                style: TextStyle(color: HulkaLook.atrium.withValues(alpha: 0.9), height: 1.35),
              ),
              const SizedBox(height: 22),
              if (registerMode) ...[
                TextField(
                  controller: displayName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                onSubmitted: (_) => submit(),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: HulkaLook.ember)),
              ],
              if (info != null) ...[
                const SizedBox(height: 12),
                Text(info!, style: const TextStyle(color: HulkaLook.atrium)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: loading ? null : submit,
                child: Text(loading
                    ? 'Please wait…'
                    : registerMode
                        ? 'Create account'
                        : 'Sign in'),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () => setState(() {
                          registerMode = !registerMode;
                          error = null;
                          info = null;
                        }),
                child: Text(registerMode ? 'Already have an account? Sign in' : 'Create a patient account'),
              ),
              if (!registerMode)
                TextButton(
                  onPressed: loading ? null : resetPassword,
                  child: const Text('Forgot password?'),
                ),
              const SizedBox(height: 8),
              Text(
                'Photographs: Unsplash License. National Cancer Institute, Hal Gatewood, Daniel Korpai.',
                style: TextStyle(fontSize: 11, color: HulkaLook.atrium.withValues(alpha: 0.7), height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Showcase extends StatelessWidget {
  const _Showcase({required this.pointer});
  final Offset pointer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 20, 12, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final orbit = (constraints.maxHeight * 0.40).clamp(150.0, 300.0);
          final carousel = (constraints.maxHeight * 0.30).clamp(140.0, 210.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: Offset(pointer.dx * -10, pointer.dy * -8),
                child: const Text(
                  'The file that walks with the patient.',
                  style: TextStyle(color: HulkaLook.linen, fontSize: 36, height: 1.08, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Longitudinal care across wards, pharmacies and wrists.',
                style: TextStyle(color: HulkaLook.copper, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Expanded(child: Center(child: OrbitGallery(size: orbit))),
              CoverflowCarousel(height: carousel),
            ],
          );
        },
      ),
    );
  }
}
