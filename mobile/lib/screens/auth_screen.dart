import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signUp = false;
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 20),
      children: [
        Text(
          _signUp ? 'Create Account' : 'Welcome Back',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Sign in to manage contacts, campaigns, and WhatsApp sessions.'),
        const SizedBox(height: 28),
        TextField(
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF05060F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => context.go('/'),
            child: Text(_signUp ? 'Create Account' : 'Sign In'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _signUp = !_signUp),
          child: Text(_signUp ? 'Already have an account?' : 'Create a new account'),
        ),
      ],
    );
  }
}
