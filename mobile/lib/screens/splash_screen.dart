import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:bulker/providers/bulker_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _routeAfterStartup();
  }

  Future<void> _routeAfterStartup() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    for (var index = 0; index < 30; index++) {
      if (!mounted) return;
      final state = context.read<BulkerState>();
      if (state.isAppReady) {
        context.go(state.hasCompletedLogin ? '/' : '/auth');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    final state = context.read<BulkerState>();
      context.go(state.hasCompletedLogin ? '/' : '/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x5525D366), blurRadius: 22),
                ],
              ),
              child: const Text(
                'B',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Bulker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            const CircularProgressIndicator(color: Color(0xFF6DF084)),
          ],
        ),
      ),
    );
  }
}
