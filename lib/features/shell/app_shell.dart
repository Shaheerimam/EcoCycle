import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import '../home/home_screen.dart';
import '../social/activity_feed_view.dart';
import '../social/leaderboard_view.dart';
import '../profile/user_profile_view.dart';
import '../moderator/moderator_dashboard_view.dart';
import '../admin/admin_dashboard_view.dart';
import '../auth/login_screen.dart';

enum UserRole { citizen, moderator, admin }

// ═══════════════════════════════════════════════════════
//  APP SHELL
// ═══════════════════════════════════════════════════════

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.themeProvider,
    this.role = UserRole.citizen,
  });
  final ThemeProvider themeProvider;
  final UserRole role;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  static const _breakpoint = 720.0;

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(themeProvider: widget.themeProvider),
      ),
      (route) => false,
    );
  }

  List<_NavItem> get _items {
    final base = [
      const _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
      const _NavItem(
        icon: Icons.dynamic_feed_outlined,
        activeIcon: Icons.dynamic_feed_rounded,
      ),
      const _NavItem(
        icon: Icons.leaderboard_outlined,
        activeIcon: Icons.leaderboard_rounded,
      ),
    ];
    if (widget.role != UserRole.citizen) {
      base.add(
        const _NavItem(
          icon: Icons.gavel_outlined,
          activeIcon: Icons.gavel_rounded,
        ),
      );
    }
    base.add(
      const _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    );
    return base;
  }

  List<String> get _labels {
    final base = ['Home', 'Feed', 'Leaderboard'];
    if (widget.role != UserRole.citizen) {
      base.add('Disputes');
    }
    base.add('Profile');
    return base;
  }

  // ── Page routing ────────────────────────────────────
  Widget _page(int i) {
    if (i == 0) return const HomeScreen(key: ValueKey(0));
    if (i == 1) return const ActivityFeedView(key: ValueKey(1));
    if (i == 2) return const LeaderboardView(key: ValueKey(2));

    if (widget.role != UserRole.citizen && i == 3) {
      if (widget.role == UserRole.admin) {
        return const AdminDashboardView(key: ValueKey(3));
      }
      return const ModeratorDashboardView(key: ValueKey(3));
    }

    final isProfile = widget.role != UserRole.citizen ? i == 4 : i == 3;
    if (isProfile) {
      return const UserProfileView(key: ValueKey('profile'));
    }

    // Other tabs — placeholder
    return Center(
      key: ValueKey(i),
      child: GlassContainer(
        hoverable: true,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_items[i].activeIcon, size: 48, color: AppColors.neonGreen),
            const SizedBox(height: 16),
            Text(_labels[i], style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            Text('Coming soon', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, box) {
        final wide = box.maxWidth >= _breakpoint;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // ── Layer 0: Glass Engine blobs ─────────
              const Positioned.fill(child: GlassEngineBackground()),

              // ── Layer 1: Content + Nav ──────────────
              Positioned.fill(
                child: SafeArea(child: wide ? _desktop() : _mobile()),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Desktop ──────────────────────────────────────────
  Widget _desktop() {
    return Row(
      children: [
        _FloatingSidebar(
          items: _items,
          selected: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          themeProvider: widget.themeProvider,
          onLogout: _logout,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _page(_selectedIndex),
          ),
        ),
      ],
    );
  }

  // ── Mobile ───────────────────────────────────────────
  Widget _mobile() {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 96),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _page(_selectedIndex),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 16,
          child: _FloatingBottomBar(
            items: _items,
            selected: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            themeProvider: widget.themeProvider,
            onLogout: _logout,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  DATA
// ═══════════════════════════════════════════════════════

class _NavItem {
  const _NavItem({required this.icon, required this.activeIcon});
  final IconData icon;
  final IconData activeIcon;
}

// ═══════════════════════════════════════════════════════
//  FLOATING SIDEBAR  (desktop, 70 px, icons only)
// ═══════════════════════════════════════════════════════

class _FloatingSidebar extends StatelessWidget {
  const _FloatingSidebar({
    required this.items,
    required this.selected,
    required this.onTap,
    required this.themeProvider,
    required this.onLogout,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onTap;
  final ThemeProvider themeProvider;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 70,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.06),
                  blurRadius: 32,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ── Top: brand mark ──
                const Padding(
                  padding: EdgeInsets.only(top: 28),
                  child: _BrandMark(),
                ),

                // ── Middle: nav icons ──
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(items.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: HoverIconItem(
                        icon: items[i].icon,
                        activeIcon: items[i].activeIcon,
                        isActive: i == selected,
                        onTap: () => onTap(i),
                      ),
                    );
                  }),
                ),

                // ── Bottom: actions ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout_rounded),
                        color: Colors.redAccent.withValues(alpha: 0.8),
                        tooltip: 'Logout',
                      ),
                      const SizedBox(height: 16),
                      _LiquidThemeToggle(provider: themeProvider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  FLOATING BOTTOM BAR  (mobile, icons only)
// ═══════════════════════════════════════════════════════

class _FloatingBottomBar extends StatelessWidget {
  const _FloatingBottomBar({
    required this.items,
    required this.selected,
    required this.onTap,
    required this.themeProvider,
    required this.onLogout,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onTap;
  final ThemeProvider themeProvider;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.06),
                blurRadius: 32,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...List.generate(items.length, (i) {
                return HoverIconItem(
                  icon: items[i].icon,
                  activeIcon: items[i].activeIcon,
                  isActive: i == selected,
                  onTap: () => onTap(i),
                );
              }),
              IconButton(
                onPressed: () async => onLogout(),
                icon: const Icon(Icons.logout_rounded, size: 20),
                color: Colors.redAccent.withValues(alpha: 0.8),
                tooltip: 'Logout',
              ),
              _LiquidThemeToggle(provider: themeProvider, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  HOVER ICON ITEM — custom "liquid" hover system
//
//  • Uses MouseRegion (NO InkWell, NO IconButton)
//  • AnimatedContainer with 250 ms fastOutSlowIn
//  • Hover: greenAccent 10 %, scale 1.05
//  • Active: solid neon‑green circle with dark icon + glow
// ═══════════════════════════════════════════════════════

class HoverIconItem extends StatefulWidget {
  const HoverIconItem({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    this.size = 22.0,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;
  final double size;

  @override
  State<HoverIconItem> createState() => _HoverIconItemState();
}

class _HoverIconItemState extends State<HoverIconItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve colours
    Color bg;
    Color iconColor;
    List<BoxShadow> shadows;

    if (widget.isActive) {
      bg = AppColors.neonGreen;
      iconColor = const Color(0xFF080C0A);
      shadows = [
        BoxShadow(
          color: AppColors.neonGreen.withValues(alpha: 0.45),
          blurRadius: 18,
          spreadRadius: -2,
        ),
      ];
    } else if (_hovered) {
      bg = Colors.greenAccent.withValues(alpha: 0.10);
      iconColor = isDark
          ? Colors.white.withValues(alpha: 0.8)
          : AppColors.lightText.withValues(alpha: 0.8);
      shadows = [];
    } else {
      bg = Colors.transparent;
      iconColor = isDark
          ? Colors.white.withValues(alpha: 0.5)
          : AppColors.lightText.withValues(alpha: 0.45);
      shadows = [];
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          width: 44,
          height: 44,
          transform: _hovered && !widget.isActive
              ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            boxShadow: shadows,
          ),
          child: Center(
            child: Icon(
              widget.isActive ? widget.activeIcon : widget.icon,
              size: widget.size,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  LIQUID THEME TOGGLE  (no IconButton — pure MouseRegion)
// ═══════════════════════════════════════════════════════

class _LiquidThemeToggle extends StatefulWidget {
  const _LiquidThemeToggle({required this.provider, this.size = 20});
  final ThemeProvider provider;
  final double size;

  @override
  State<_LiquidThemeToggle> createState() => _LiquidThemeToggleState();
}

class _LiquidThemeToggleState extends State<_LiquidThemeToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.provider.toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          width: 38,
          height: 38,
          transform: _hovered
              ? Matrix4.diagonal3Values(1.08, 1.08, 1.0)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovered
                ? Colors.greenAccent.withValues(alpha: 0.10)
                : Colors.transparent,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                key: ValueKey(isDark),
                size: widget.size,
                color: AppColors.neonGreen.withValues(alpha: 0.65),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  BRAND MARK
// ═══════════════════════════════════════════════════════

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.neonGreen,
                AppColors.neonGreen.withValues(alpha: 0.55),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonGreen.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: -3,
              ),
            ],
          ),
          child: const Icon(
            Icons.recycling_rounded,
            color: Color(0xFF080C0A),
            size: 22,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'ECO',
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: AppColors.neonGreen,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

//  [REMOVE _HoverFloatCard Logic - redundant with GlassContainer(hoverable: true)]
