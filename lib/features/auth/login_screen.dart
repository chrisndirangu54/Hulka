import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Hulka', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(registerMode
                        ? 'Create your patient health identity.'
                        : 'Connected healthcare across hospitals, pharmacies and devices.'),
                    const SizedBox(height: 24),
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
                      Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    if (info != null) ...[
                      const SizedBox(height: 12),
                      Text(info!),
                    ],
                    const SizedBox(height: 20),
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
                      child: Text(registerMode
                          ? 'Already have an account? Sign in'
                          : 'Create a patient account'),
                    ),
                    if (!registerMode)
                      TextButton(
                        onPressed: loading ? null : resetPassword,
                        child: const Text('Forgot password?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
