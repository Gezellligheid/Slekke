import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SlekkeColors.background,
      body: Center(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Slekke',
                style: TextStyle(
                  color: SlekkeColors.textPrimary,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your team. Your channels.',
                style: TextStyle(color: SlekkeColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: SlekkeColors.primary,
                        ),
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SlekkeColors.textPrimary,
                          side: const BorderSide(color: SlekkeColors.elevated),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          backgroundColor: SlekkeColors.surface,
                        ),
                        icon: Image.network(
                          'https://www.google.com/favicon.ico',
                          width: 18,
                          errorBuilder: (context, err, trace) =>
                              const Icon(Icons.login, size: 18),
                        ),
                        label: const Text('Continue with Google'),
                        onPressed: _signIn,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
