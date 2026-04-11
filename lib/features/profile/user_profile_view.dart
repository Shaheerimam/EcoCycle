import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class UserProfileView extends StatefulWidget {
  const UserProfileView({super.key});

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  int _selectedTab = 0; // 0 = Showcase, 1 = Settings
  bool _isLoading = true;
  bool _updatingPrivacy = false;
  bool _updatingProfile = false;
  bool _uploadingAvatar = false;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw StateError('No logged-in user found.');
      }

      final data = await client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = data;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = 'Failed to load profile: $error';
      });
    }
  }

  Future<void> _updatePrivateProfile(bool value) async {
    if (_profile == null || _updatingPrivacy) {
      return;
    }

    final previousValue = (_profile!['is_private_profile'] as bool?) ?? false;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _updatingPrivacy = true;
      _profile = {..._profile!, 'is_private_profile': value};
    });

    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({'is_private_profile': value})
          .eq('id', user.id);

      await _syncCommunityVisibility(userId: user.id, isPrivate: value);
    } catch (error) {
      // Keep profile and feed visibility consistent across accounts.
      // If feed sync fails, roll back privacy in user_profiles as well.
      try {
        await Supabase.instance.client
            .from('user_profiles')
            .update({'is_private_profile': previousValue})
            .eq('id', user.id);
      } catch (_) {}

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = {..._profile!, 'is_private_profile': previousValue};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update privacy: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPrivacy = false;
        });
      }
    }
  }

  Future<void> _syncCommunityVisibility({
    required String userId,
    required bool isPrivate,
  }) async {
    final displayName = _str(
      _profile?['display_name'],
      fallback: _str(
        _profile?['full_name'],
        fallback: _str(_profile?['username'], fallback: 'Eco User'),
      ),
    );
    final avatarInitial = _str(
      _profile?['avatar_initial'],
      fallback: displayName.isNotEmpty ? displayName[0].toUpperCase() : 'E',
    );

    await Supabase.instance.client
        .from('community_feed_items')
        .update({
          'is_anonymous': isPrivate,
          'display_username': isPrivate ? 'Anonymous Citizen' : displayName,
          'avatar_initial': isPrivate ? 'A' : avatarInitial,
        })
        .eq('user_id', userId);
  }

  Future<void> _updateProfileFields({
    String? displayName,
    String? profileBio,
  }) async {
    if (_profile == null || _updatingProfile) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final updates = <String, dynamic>{};
    if (displayName != null) {
      updates['display_name'] = displayName;
    }
    if (profileBio != null) {
      updates['profile_bio'] = profileBio;
    }
    if (updates.isEmpty) {
      return;
    }

    setState(() {
      _updatingProfile = true;
      _profile = {..._profile!, ...updates};
    });

    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update(updates)
          .eq('id', user.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _loadProfile();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save profile: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _updatingProfile = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_profile == null || _uploadingAvatar) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 92);
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    final path = 'avatars/${user.id}.jpg';

    setState(() {
      _uploadingAvatar = true;
    });

    try {
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);

      await Supabase.instance.client
          .from('user_profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = {..._profile!, 'avatar_url': publicUrl};
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Avatar upload failed. Ensure storage bucket "avatars" exists and allows uploads. Error: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
        });
      }
    }
  }

  String _str(dynamic value, {String fallback = ''}) {
    final text = value?.toString() ?? '';
    if (text.trim().isEmpty) {
      return fallback;
    }
    return text;
  }

  int _int(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _double(dynamic value, {double fallback = 0}) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _ordinal(int n) {
    if (n <= 0) {
      return 'Unranked';
    }
    if (n % 100 >= 11 && n % 100 <= 13) {
      return '${n}th';
    }
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadProfile,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            child: const Text('Profile row not found for current user.'),
          ),
        ),
      );
    }

    final displayName = _str(
      _profile!['display_name'],
      fallback: _str(_profile!['full_name'], fallback: 'Eco User'),
    );
    final username = _str(_profile!['username'], fallback: 'ecouser');
    final avatarInitial = _str(_profile!['avatar_initial'], fallback: 'E');
    final avatarUrl = _str(_profile!['avatar_url']);
    final rank = _int(_profile!['community_rank']);
    final totalPoints = _int(_profile!['total_points']);
    final classified = _int(_profile!['classification_count']);
    final accuracy = _double(_profile!['accuracy_rate']);
    final carbonSaved = _double(_profile!['carbon_saved_kg']);
    final streakDays = _int(_profile!['streak_days']);
    final badgesEarned = _int(_profile!['badges_earned']);
    final profileBio = _str(
      _profile!['profile_bio'],
      fallback:
          'I am passionate about the environment and love classifying waste accurately to help train better AI models!',
    );
    final isPrivateProfile =
        (_profile!['is_private_profile'] as bool?) ?? false;
    final facebookHandle = _str(
      _profile!['facebook_handle'],
      fallback: 'Not connected',
    );
    final instagramHandle = _str(
      _profile!['instagram_handle'],
      fallback: 'Not connected',
    );
    final linkedinHandle = _str(
      _profile!['linkedin_handle'],
      fallback: 'Not connected',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Profile Card
              GlassContainer(
                hoverable: true,
                sigma: 24,
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: _ProfileAvatar(
                        size: 64,
                        initial: avatarInitial,
                        avatarUrl: avatarUrl,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              color: AppColors.neonGreen.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AppColors.neonGreen.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: AppColors.neonGreen,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Community Rank: ${_ordinal(rank)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.neonGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats Grid 2x2
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 500 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _StatCard(
                        label: 'Total Points',
                        value: totalPoints.toString(),
                        icon: Icons.stars_outlined,
                      ),
                      _StatCard(
                        label: 'Items Classified',
                        value: classified.toString(),
                        icon: Icons.document_scanner_outlined,
                      ),
                      _StatCard(
                        label: 'Accuracy',
                        value: '${accuracy.toStringAsFixed(0)}%',
                        icon: Icons.check_circle_outline,
                      ),
                      _StatCard(
                        label: 'Carbon Saved',
                        value: '${carbonSaved.toStringAsFixed(1)} kg',
                        icon: Icons.eco_outlined,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 48),

              // Tabs Segments
              Row(
                children: [
                  _TabButton(
                    label: 'Showcase',
                    icon: Icons.auto_awesome_mosaic_outlined,
                    isActive: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  const SizedBox(width: 16),
                  _TabButton(
                    label: 'Settings',
                    icon: Icons.tune_outlined,
                    isActive: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tab Content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _selectedTab == 0
                    ? _ShowcaseTab(
                        streakDays: streakDays,
                        badgesEarned: badgesEarned,
                        communityRank: rank,
                      )
                    : _SettingsTab(
                        avatarInitial: avatarInitial,
                        displayName: displayName,
                        username: username,
                        avatarUrl: avatarUrl,
                        profileBio: profileBio,
                        isPrivateProfile: isPrivateProfile,
                        updatingPrivacy: _updatingPrivacy,
                        updatingProfile: _updatingProfile,
                        uploadingAvatar: _uploadingAvatar,
                        onSaveProfile: _updateProfileFields,
                        onChangePhoto: _pickAndUploadAvatar,
                        onPrivateProfileChanged: _updatePrivateProfile,
                        facebookHandle: facebookHandle,
                        instagramHandle: instagramHandle,
                        linkedinHandle: linkedinHandle,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowcaseTab extends StatelessWidget {
  const _ShowcaseTab({
    required this.streakDays,
    required this.badgesEarned,
    required this.communityRank,
  });

  final int streakDays;
  final int badgesEarned;
  final int communityRank;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
          children: [
            _BadgeCard(
              label: '$streakDays Day Streak',
              icon: Icons.local_fire_department_rounded,
              color: Colors.orangeAccent,
            ),
            _BadgeCard(
              label: 'Badges Earned: $badgesEarned',
              icon: Icons.emoji_events_rounded,
              color: Color(0xFFFFD700),
            ),
            _BadgeCard(
              label: communityRank > 0
                  ? 'Community Rank: #$communityRank'
                  : 'Community Rank: Unranked',
              icon: Icons.power_rounded,
              color: Colors.lightBlueAccent,
            ),
          ],
        );
      },
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.avatarInitial,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.profileBio,
    required this.isPrivateProfile,
    required this.updatingPrivacy,
    required this.updatingProfile,
    required this.uploadingAvatar,
    required this.onSaveProfile,
    required this.onChangePhoto,
    required this.onPrivateProfileChanged,
    required this.facebookHandle,
    required this.instagramHandle,
    required this.linkedinHandle,
  });

  final String avatarInitial;
  final String displayName;
  final String username;
  final String avatarUrl;
  final String profileBio;
  final bool isPrivateProfile;
  final bool updatingPrivacy;
  final bool updatingProfile;
  final bool uploadingAvatar;
  final Future<void> Function({String? displayName, String? profileBio})
  onSaveProfile;
  final Future<void> Function() onChangePhoto;
  final ValueChanged<bool> onPrivateProfileChanged;
  final String facebookHandle;
  final String instagramHandle;
  final String linkedinHandle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Identity & Privacy ──
        GlassContainer(
          hoverable: true,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: _ProfileAvatar(
                      size: 64,
                      initial: avatarInitial,
                      avatarUrl: avatarUrl,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton.icon(
                    onPressed: uploadingAvatar ? null : onChangePhoto,
                    icon: uploadingAvatar
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded, size: 16),
                    label: Text(
                      uploadingAvatar ? 'Uploading...' : 'Change Photo',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _EditableField(
                label: 'Display Name',
                value: displayName,
                isDark: isDark,
                onSave: (v) => onSaveProfile(displayName: v),
                saving: updatingProfile,
              ),
              const SizedBox(height: 20),
              _LabelTextField(
                label: 'Username',
                value: '@$username',
                isDark: isDark,
              ),
              const SizedBox(height: 24),
              Text(
                'Profile Bio',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 12),
              _EditableMultilineField(
                value: profileBio,
                isDark: isDark,
                onSave: (v) => onSaveProfile(profileBio: v),
                saving: updatingProfile,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Private Profile',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hide your activity from the community feed.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Switch.adaptive(
                      value: isPrivateProfile,
                      onChanged: updatingPrivacy
                          ? null
                          : onPrivateProfileChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      activeTrackColor: AppColors.neonGreen.withValues(
                        alpha: 0.4,
                      ),
                      activeThumbColor: AppColors.neonGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Social Connect ──
        GlassContainer(
          hoverable: true,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Social Connectivity',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 24),
              _SocialField(
                icon: Icons.facebook_rounded,
                label: 'Facebook',
                value: facebookHandle,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _SocialField(
                icon: Icons.camera_alt_rounded,
                label: 'Instagram',
                value: instagramHandle,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _SocialField(
                icon: Icons.work_rounded,
                label: 'LinkedIn',
                value: linkedinHandle,
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Contact Support ──
        GlassContainer(
          hoverable: true,
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.headset_mic_rounded,
                color: AppColors.neonGreen,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Contact Support / Open Ticket',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabelTextField extends StatelessWidget {
  const _LabelTextField({
    required this.label,
    required this.value,
    required this.isDark,
  });
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.darkText,
                  ),
                ),
              ),
              Icon(
                Icons.edit_rounded,
                size: 16,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppColors.lightTextSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditableField extends StatefulWidget {
  const _EditableField({
    required this.label,
    required this.value,
    required this.isDark,
    required this.onSave,
    required this.saving,
  });

  final String label;
  final String value;
  final bool isDark;
  final Future<void> Function(String value) onSave;
  final bool saving;

  @override
  State<_EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<_EditableField> {
  late final TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _EditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_editing) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _editing
                    ? TextField(
                        controller: _controller,
                        autofocus: true,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: widget.isDark
                              ? Colors.white
                              : AppColors.darkText,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                      )
                    : Text(
                        widget.value,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: widget.isDark
                              ? Colors.white
                              : AppColors.darkText,
                        ),
                      ),
              ),
              if (_editing)
                IconButton(
                  onPressed: widget.saving
                      ? null
                      : () async {
                          await widget.onSave(_controller.text.trim());
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _editing = false;
                          });
                        },
                  icon: widget.saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                )
              else
                IconButton(
                  onPressed: () {
                    setState(() {
                      _editing = true;
                    });
                  },
                  icon: const Icon(Icons.edit_rounded),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditableMultilineField extends StatefulWidget {
  const _EditableMultilineField({
    required this.value,
    required this.isDark,
    required this.onSave,
    required this.saving,
  });

  final String value;
  final bool isDark;
  final Future<void> Function(String value) onSave;
  final bool saving;

  @override
  State<_EditableMultilineField> createState() =>
      _EditableMultilineFieldState();
}

class _EditableMultilineFieldState extends State<_EditableMultilineField> {
  late final TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _EditableMultilineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_editing) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _editing
              ? TextField(
                  controller: _controller,
                  minLines: 3,
                  maxLines: 5,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: widget.isDark ? Colors.white : AppColors.darkText,
                  ),
                  decoration: const InputDecoration(border: InputBorder.none),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.value,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
          IconButton(
            onPressed: widget.saving
                ? null
                : () async {
                    if (_editing) {
                      await widget.onSave(_controller.text.trim());
                    }
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _editing = !_editing;
                    });
                  },
            icon: widget.saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.size,
    required this.initial,
    required this.avatarUrl,
    required this.isDark,
  });

  final double size;
  final String initial;
  final String avatarUrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _fallback();
          },
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }
}

class _SocialField extends StatelessWidget {
  const _SocialField({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : AppColors.lightTextSecondary,
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppColors.lightTextSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.darkText,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.edit_rounded,
            size: 16,
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : AppColors.lightTextSecondary,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      hoverable: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.neonGreen),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      hoverable: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isActive
                      ? (isDark ? Colors.white : AppColors.lightText)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.lightTextSecondary),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? (isDark ? Colors.white : AppColors.lightText)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
