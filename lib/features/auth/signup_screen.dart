import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import 'login_screen.dart';
import '../shell/app_shell.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.themeProvider,
    this.initialRole = UserRole.citizen,
  });
  final ThemeProvider themeProvider;
  final UserRole initialRole;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _nidController = TextEditingController();
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
    _fullNameController.dispose();
    _usernameController.dispose();
    _nidController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final authResponse = await client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _fullNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'nid_number': _nidController.text.trim(),
          'role': _selectedRole.name,
        },
      );

      final userId = authResponse.user?.id;
      if (userId == null) {
        throw StateError('Signup succeeded but no user id was returned.');
      }

      await client.from('user_profiles').insert({
        'id': userId,
        'full_name': _fullNameController.text.trim(),
        'display_name': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'nid_number': _nidController.text.trim(),
        'role': _selectedRole.name,
        'avatar_initial': _fullNameController.text.trim().isNotEmpty
            ? _fullNameController.text.trim()[0].toUpperCase()
            : 'E',
        'avatar_url': null,
        'profile_bio':
            'I am passionate about the environment and love classifying waste accurately to help train better AI models!',
        'is_private_profile': false,
        'total_points': 0,
        'classification_count': 0,
        'accuracy_rate': 0,
        'carbon_saved_kg': 0,
        'community_rank': 0,
        'streak_days': 0,
        'badges_earned': 0,
        'facebook_handle': '',
        'instagram_handle': '',
        'linkedin_handle': '',
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Signup successful. Check your email if confirmation is enabled.',
          ),
        ),
      );

      final hasSession = Supabase.instance.client.auth.currentSession != null;
      if (hasSession) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AppShell(
              themeProvider: widget.themeProvider,
              role: _selectedRole,
            ),
          ),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            themeProvider: widget.themeProvider,
            initialRole: _selectedRole,
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyAuthMessage(error))));
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile save failed: ${error.message}. Check table name, columns, and RLS policies.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Signup failed: $error')));
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

    if (message.contains('user already registered')) {
      return 'This email is already registered. Please log in instead.';
    }
    if (message.contains('invalid api key') || message.contains('apikey')) {
      return 'Supabase key is invalid. Check URL and anon key in main.dart.';
    }
    if (message.contains('signup is disabled')) {
      return 'Email signups are disabled in your Supabase Auth settings.';
    }

    return 'Signup failed: ${error.message}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.darkText;

    return Scaffold(
      body: Stack(
        children: [
          const GlassEngineBackground(),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;

              final authForm = ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: GlassContainer(
                  sigma: 24,
                  padding: const EdgeInsets.all(40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: isDesktop ? 24 : 28,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join EcoCycle and start tracking your impact.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _MinimalTextField(
                          controller: _fullNameController,
                          hintText: 'Full name',
                          icon: Icons.person_outline_rounded,
                          isDark: isDark,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if ((value?.trim() ?? '').isEmpty) {
                              return 'Enter your full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _MinimalTextField(
                          controller: _usernameController,
                          hintText: 'Username',
                          icon: Icons.alternate_email_rounded,
                          isDark: isDark,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final username = value?.trim() ?? '';
                            if (username.isEmpty) {
                              return 'Enter a username';
                            }
                            if (!RegExp(
                              r'^[a-zA-Z0-9_]{3,20}$',
                            ).hasMatch(username)) {
                              return 'Use 3-20 letters, numbers, or underscore';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _MinimalTextField(
                          controller: _nidController,
                          hintText: 'NID number',
                          icon: Icons.badge_outlined,
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final nid = value?.trim() ?? '';
                            if (nid.isEmpty) {
                              return 'Enter your NID number';
                            }
                            if (!RegExp(r'^\d{6,20}$').hasMatch(nid)) {
                              return 'NID should contain only digits';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _MinimalTextField(
                          controller: _emailController,
                          hintText: 'Email address',
                          icon: Icons.email_outlined,
                          isDark: isDark,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if ((value?.trim() ?? '').isEmpty) {
                              return 'Enter your email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _MinimalTextField(
                          controller: _passwordController,
                          hintText: 'Password',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          isDark: isDark,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if ((value ?? '').length < 6) {
                              return 'Password must be at least 6 characters';
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
                        const SizedBox(height: 22),
                        _HoverButton(
                          onTap: _isLoading ? null : _signup,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.darkText,
                                      ),
                                    ),
                                  )
                                else ...[
                                  Text(
                                    'Sign Up',
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
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => LoginScreen(
                                        themeProvider: widget.themeProvider,
                                        initialRole: _selectedRole,
                                      ),
                                    ),
                                  );
                                },
                          child: Text(
                            'Already have an account? Log In',
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
                ),
              );

              if (isDesktop) {
                return Row(
                  children: [
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
                              'Build Your Green Identity',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: AppColors.neonGreen,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Create your account to classify waste, earn points, and help the community recycle smarter.',
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
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: _hovered ? 1.02 : 1.0,
          child: Opacity(
            opacity: widget.onTap == null ? 0.7 : 1,
            child: widget.child,
          ),
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
