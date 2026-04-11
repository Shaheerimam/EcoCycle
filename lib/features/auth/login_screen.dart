import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import 'signup_screen.dart';
import '../shell/app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.themeProvider,
    this.initialRole = UserRole.citizen,
  });
  final ThemeProvider themeProvider;
  final UserRole initialRole;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late UserRole _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      _enterApp(_selectedRole);
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyAuthMessage(error))));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _friendlyAuthMessage(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('email not confirmed')) {
      return 'Please verify your email first, then log in.';
    }
    if (message.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (message.contains('invalid api key') || message.contains('apikey')) {
      return 'Supabase key is invalid. Check URL and anon key in main.dart.';
    }

    return 'Login failed: ${error.message}';
  }

  void _enterApp(UserRole role) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AppShell(themeProvider: widget.themeProvider, role: role),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.darkText;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return Scaffold(
      body: Stack(
        children: [
          const GlassEngineBackground(),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;

              final authForm = ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassContainer(
                  sigma: 24,
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isDesktop) ...[
                        // Logo & Header for mobile
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.neonGreen.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AppColors.neonGreen.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.recycling_rounded,
                              size: 32,
                              color: AppColors.neonGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome Back',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to track your environmental impact.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                      if (isDesktop) ...[
                        Text(
                          'Sign In',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _MinimalTextField(
                              controller: _emailController,
                              hintText: 'Email address',
                              icon: Icons.email_outlined,
                              isDark: isDark,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) {
                                  return 'Enter your email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _MinimalTextField(
                              controller: _passwordController,
                              hintText: 'Password',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              isDark: isDark,
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return 'Enter your password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _RoleSelector(
                              isDark: isDark,
                              selectedRole: _selectedRole,
                              onRoleChanged: (role) {
                                setState(() {
                                  _selectedRole = role;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            _HoverButton(
                              onTap: _isLoading ? null : _login,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppColors.neonGreen,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.neonGreen.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isLoading)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.darkText,
                                              ),
                                        ),
                                      )
                                    else ...[
                                      Text(
                                        'Log In',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.darkText,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                        color: AppColors.darkText,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(child: Divider(color: borderColor)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'ACCOUNT',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.3)
                                          : Colors.black.withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: borderColor)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SignupScreen(
                                            themeProvider: widget.themeProvider,
                                            initialRole: _selectedRole,
                                          ),
                                        ),
                                      );
                                    },
                              child: Text(
                                "Don't have an account? Sign Up",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.neonGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );

              if (isDesktop) {
                return Row(
                  children: [
                    // Left Column
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(64.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.neonGreen.withValues(
                                  alpha: 0.1,
                                ),
                                border: Border.all(
                                  color: AppColors.neonGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Icon(
                                Icons.recycling_rounded,
                                size: 40,
                                color: AppColors.neonGreen,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'EcoCycle',
                              style: GoogleFonts.inter(
                                fontSize: 64,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: -2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Revolutionizing Waste Management',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: AppColors.neonGreen,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Sign in to track your environmental impact, classify waste with AI, and climb the community leaderboard.',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : AppColors.lightTextSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right Column
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 48,
                          ),
                          child: authForm,
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Mobile Layout
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 48,
                  ),
                  child: authForm,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MinimalTextField extends StatelessWidget {
  const _MinimalTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    required this.isDark,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final bool isDark;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.02),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        validator: validator,
        style: GoogleFonts.inter(
          color: isDark ? Colors.white : AppColors.darkText,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : AppColors.lightTextSecondary.withValues(alpha: 0.6),
          ),
          prefixIcon: Icon(
            icon,
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : AppColors.lightTextSecondary.withValues(alpha: 0.6),
            size: 20,
          ),
          border: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _HoverButton extends StatefulWidget {
  const _HoverButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: _hovered ? 1.02 : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.isDark,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  final bool isDark;
  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: UserRole.values
          .map(
            (role) => ChoiceChip(
              label: Text(
                _roleLabel(role),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selectedRole == role
                      ? AppColors.darkText
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.lightText),
                ),
              ),
              selected: selectedRole == role,
              onSelected: (_) => onRoleChanged(role),
              selectedColor: AppColors.neonGreen,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              side: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
          )
          .toList(),
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.citizen:
        return 'Citizen';
      case UserRole.moderator:
        return 'Moderator';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
