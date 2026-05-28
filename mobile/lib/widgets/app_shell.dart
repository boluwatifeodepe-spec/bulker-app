import 'dart:io';

import 'package:bulker/providers/bulker_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const green = Color(0xFF6DF084);
  static const ink = Color(0xFF05060F);

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final showTabs = location != '/' && location != '/auth';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
                border: Border(
                  left: BorderSide(color: Color(0xFFE0E3E7)),
                  right: BorderSide(color: Color(0xFFE0E3E7)),
                ),
              ),
              child: Column(
                children: [
                  const _TopBar(),
                  Expanded(child: child),
                  if (showTabs) _BottomTabs(location: location),
                  if (location == '/') const _ConnectTabs(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BulkerState>();
    final photoPath = state.profilePhotoPath;
    return Container(
      height: 53,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'B',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Bulker',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.go('/settings'),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF173041), Color(0xFF8FD6E6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 8),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: photoPath == null
                  ? const Icon(Icons.person, color: Colors.white, size: 18)
                  : Image.file(File(photoPath), fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomTabs extends StatelessWidget {
  const _BottomTabs({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8DCE2)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TabButton(
            icon: Icons.notes_rounded,
            label: 'Compose',
            active: location == '/compose',
            onTap: () => context.go('/compose'),
          ),
          _TabButton(
            icon: Icons.group_outlined,
            label: 'Contacts',
            active: location == '/contacts',
            onTap: () => context.go('/contacts'),
          ),
          _TabButton(
            icon: Icons.insert_chart_outlined_rounded,
            label: 'Dashboard',
            active: location == '/dashboard',
            onTap: () => context.go('/dashboard'),
          ),
          _TabButton(
            icon: Icons.history,
            label: 'History',
            active: location == '/history',
            onTap: () => context.go('/history'),
          ),
          _TabButton(
            icon: Icons.settings_outlined,
            label: 'Settings',
            active: location == '/settings',
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}

class _ConnectTabs extends StatelessWidget {
  const _ConnectTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8DCE2)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _TabButton(
            icon: Icons.notes_rounded,
            label: 'Compose',
            active: false,
            onTap: () => context.go('/compose'),
          ),
          _TabButton(
            icon: Icons.group_outlined,
            label: 'Contacts',
            active: false,
            onTap: () => context.go('/contacts'),
          ),
          _TabButton(
            icon: Icons.insert_chart_outlined_rounded,
            label: 'Dashboard',
            active: false,
            onTap: () => context.go('/dashboard'),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 72,
        height: 52,
        decoration: BoxDecoration(
          color: active ? AppShell.green : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? const Color(0xFF287A35) : AppShell.ink),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: active ? const Color(0xFF287A35) : AppShell.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
