import 'package:bulker/providers/bulker_state.dart';
import 'package:bulker/screens/auth_screen.dart';
import 'package:bulker/screens/compose_message_screen.dart';
import 'package:bulker/screens/connect_whatsapp_screen.dart';
import 'package:bulker/screens/history_screen.dart';
import 'package:bulker/screens/manage_contacts_screen.dart';
import 'package:bulker/screens/settings_screen.dart';
import 'package:bulker/screens/sending_dashboard_screen.dart';
import 'package:bulker/screens/splash_screen.dart';
import 'package:bulker/widgets/app_shell.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase files are expected after the project is configured.
  }
  runApp(const BulkerApp());
}

class BulkerApp extends StatelessWidget {
  const BulkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BulkerState()..initialize(),
      child: Consumer<BulkerState>(
        builder: (context, state, _) => MaterialApp.router(
          title: 'Bulker',
          debugShowCheckedModeBanner: false,
          themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          routerConfig: _router,
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF05060F);
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: isDark ? const Color(0xFF111418) : const Color(0xFFF7F8FA),
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: const Color(0xFF25D366),
        primary: const Color(0xFF2F7D32),
        secondary: const Color(0xFF25D366),
        surface: isDark ? const Color(0xFF1A1E24) : Colors.white,
      ),
      fontFamily: 'Inter',
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: textColor,
          fontSize: 23,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          color: textColor,
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        bodySmall: TextStyle(color: textColor, fontSize: 12),
      ),
    );
  }
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, __) => const SplashScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/auth',
          builder: (_, __) => const AuthScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => const ConnectWhatsAppScreen(),
        ),
        GoRoute(
          path: '/compose',
          builder: (_, __) => const ComposeMessageScreen(),
        ),
        GoRoute(
          path: '/contacts',
          builder: (_, __) => const ManageContactsScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const SendingDashboardScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (_, __) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
