import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../classifier/image_classifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

// ═══════════════════════════════════════════════════════
//  HOME SCREEN — 2‑column dashboard layout
// ═══════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final ImageClassifier _classifier = createClassifier();

  Uint8List? _selectedImageBytes;
  String _status = 'Loading model...';
  String? _predictionLabel;
  double? _confidence;
  bool _isLoading = true;
  bool _isClassifying = false;
  bool _isDashboardLoading = true;
  String? _dashboardError;

  int _totalPoints = 0;
  int _communityRank = 0;
  int _classificationCount = 0;
  double _carbonSavedKg = 0;
  int _streakDays = 0;
  int _badgesEarned = 0;
  List<_ScanData> _recentScans = const [];

  late final AnimationController _ringCtrl;

  bool get _showResult => _predictionLabel != null;
  bool get _highConf => (_confidence ?? 0) >= 0.8;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadModelAndLabels();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _classifier.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModelAndLabels() async {
    try {
      await _classifier.load();
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _status = 'Model ready. Tap to capture or upload an image.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _status = 'Failed to load model: $error';
      });
    }
  }

  Future<void> _pickAndClassifyImage(ImageSource source) async {
    final pickedImage = await _picker.pickImage(
      source: source,
      imageQuality: 95,
    );

    if (pickedImage == null) {
      return;
    }

    final imageBytes = await pickedImage.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImageBytes = imageBytes;
      _isClassifying = true;
      _predictionLabel = null;
      _confidence = null;
      _status = 'Running classification...';
    });

    try {
      final prediction = await _classifier.classify(imageBytes);
      if (!mounted) {
        return;
      }

      setState(() {
        _predictionLabel = prediction.label;
        _confidence = prediction.confidence;
        _status = 'Predicted ${prediction.label}';
        _isClassifying = false;
      });

      _ringCtrl.forward(from: 0);
      await _recordClassificationActivity(prediction);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isClassifying = false;
        _status = 'Classification failed: $error';
      });
      _ringCtrl.reset();
    }
  }

  Future<void> _chooseImageSourceAndClassify() async {
    if (_isLoading || _isClassifying) {
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

    await _pickAndClassifyImage(source);
  }

  Future<void> _loadDashboardData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isDashboardLoading = false;
        _dashboardError = 'Please log in to load dashboard data.';
      });
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select(
            'total_points, community_rank, classification_count, carbon_saved_kg, streak_days, badges_earned',
          )
          .eq('id', user.id)
          .maybeSingle();

      final scansRaw = await Supabase.instance.client
          .from('user_scans')
          .select(
            'item_name, category_label, points_awarded, confirmed, created_at',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(5);

      if (!mounted) {
        return;
      }

      final scans = (scansRaw as List)
          .map(
            (row) => _ScanData(
              _iconForCategory((row['category_label'] ?? '').toString()),
              (row['item_name'] ?? 'Unknown Item').toString(),
              (row['category_label'] ?? 'Uncategorized').toString(),
              _formatPoints(
                (row['points_awarded'] as num?)?.toInt() ?? 0,
                (row['confirmed'] as bool?) ?? false,
              ),
              (row['confirmed'] as bool?) ?? false,
            ),
          )
          .toList();

      setState(() {
        _isDashboardLoading = false;
        _dashboardError = null;
        _totalPoints = _toInt(profile?['total_points']);
        _communityRank = _toInt(profile?['community_rank']);
        _classificationCount = _toInt(profile?['classification_count']);
        _carbonSavedKg = _toDouble(profile?['carbon_saved_kg']);
        _streakDays = _toInt(profile?['streak_days']);
        _badgesEarned = _toInt(profile?['badges_earned']);
        _recentScans = scans;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isDashboardLoading = false;
        _dashboardError = 'Failed to load dashboard data: $error';
      });
    }
  }

  Future<void> _recordClassificationActivity(
    PredictionResult prediction,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final confirmed = prediction.confidence >= 0.8;
    final pointsAwarded = confirmed ? 10 : 0;
    final carbonDelta = confirmed ? 0.3 : 0.0;
    final category = confirmed ? 'Recyclable' : 'Needs Review';
    final previousClassificationCount = _classificationCount;

    // Optimistic UI update so the user immediately sees the scan.
    _prependRecentScan(
      _ScanData(
        _iconForCategory(category),
        prediction.label,
        category,
        _formatPoints(pointsAwarded, confirmed),
        confirmed,
      ),
    );

    try {
      await Supabase.instance.client.from('user_scans').insert({
        'user_id': user.id,
        'item_name': prediction.label,
        'category_label': category,
        'confidence': prediction.confidence,
        'points_awarded': pointsAwarded,
        'confirmed': confirmed,
      });

      await Supabase.instance.client.from('user_activity_days').upsert({
        'user_id': user.id,
        'activity_date': DateTime.now()
            .toUtc()
            .toIso8601String()
            .split('T')
            .first,
        'activities_count': 1,
        'last_activity_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,activity_date');

      await Supabase.instance.client.rpc(
        'refresh_user_streak',
        params: {'p_user_id': user.id},
      );

      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'classification_count': previousClassificationCount + 1,
            'total_points': _totalPoints + pointsAwarded,
            'carbon_saved_kg': _carbonSavedKg + carbonDelta,
          })
          .eq('id', user.id);

      await _loadDashboardData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _dashboardError =
            'Scan saved locally, but database sync failed: $error';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scan captured, but failed to sync to database. Check RLS/policies and tables.',
          ),
        ),
      );
    }
  }

  void _prependRecentScan(_ScanData scan) {
    if (!mounted) {
      return;
    }

    setState(() {
      _recentScans = [scan, ..._recentScans].take(5).toList();
      _classificationCount += 1;
    });
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _rankLabel(int rank) {
    if (rank <= 0) {
      return 'ranked';
    }
    if (rank % 100 >= 11 && rank % 100 <= 13) {
      return '${rank}th';
    }
    switch (rank % 10) {
      case 1:
        return '${rank}st';
      case 2:
        return '${rank}nd';
      case 3:
        return '${rank}rd';
      default:
        return '${rank}th';
    }
  }

  String _formatPoints(int points, bool confirmed) {
    if (!confirmed) {
      return 'Pending';
    }
    return '+$points';
  }

  IconData _iconForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('paper')) {
      return Icons.newspaper_outlined;
    }
    if (lower.contains('food')) {
      return Icons.fastfood_outlined;
    }
    if (lower.contains('plastic') || lower.contains('recycl')) {
      return Icons.local_drink_outlined;
    }
    return Icons.delete_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, box) {
        final wide = box.maxWidth >= 760;
        return Padding(
          padding: EdgeInsets.all(wide ? 40 : 20),
          child: Column(
            children: [
              _TopBar(
                showResult: _showResult,
                highConf: _highConf,
                isBusy: _isLoading || _isClassifying,
                onPickImage: _chooseImageSourceAndClassify,
                pointsValue: _totalPoints.toString(),
                rankValue: _rankLabel(_communityRank),
              ),
              SizedBox(height: wide ? 32 : 20),
              Expanded(child: wide ? _desktopLayout() : _mobileLayout()),
            ],
          ),
        );
      },
    );
  }

  // ── Desktop: two columns ─────────────────────────────
  Widget _desktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column (flex 6) — action area
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: Column(
              children: [
                GlassContainer(
                  hoverable: true,
                  padding: const EdgeInsets.all(24),
                  child: _UploadContent(
                    onTap: _chooseImageSourceAndClassify,
                    isLoading: _isLoading,
                    isClassifying: _isClassifying,
                    status: _status,
                    imageBytes: _selectedImageBytes,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  child: _showResult
                      ? Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: GlassContainer(
                            hoverable: true,
                            padding: const EdgeInsets.all(24),
                            child: _ResultContent(
                              animation: _ringCtrl,
                              highConf: _highConf,
                              imageBytes: _selectedImageBytes,
                              predictionLabel: _predictionLabel!,
                              confidence: _confidence ?? 0,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Right column (flex 4) — context area
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              children: [
                GlassContainer(
                  hoverable: true,
                  padding: const EdgeInsets.all(24),
                  child: _ImpactCard(
                    isLoading: _isDashboardLoading,
                    error: _dashboardError,
                    itemsScanned: _classificationCount,
                    carbonSavedKg: _carbonSavedKg,
                    streakDays: _streakDays,
                    badgesEarned: _badgesEarned,
                  ),
                ),
                const SizedBox(height: 20),
                GlassContainer(
                  hoverable: true,
                  padding: const EdgeInsets.all(24),
                  child: _RecentScansCard(
                    isLoading: _isDashboardLoading,
                    error: _dashboardError,
                    scans: _recentScans,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile: single scrollable column ─────────────────
  Widget _mobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          GlassContainer(
            hoverable: true,
            padding: const EdgeInsets.all(24),
            child: _UploadContent(
              onTap: _chooseImageSourceAndClassify,
              isLoading: _isLoading,
              isClassifying: _isClassifying,
              status: _status,
              imageBytes: _selectedImageBytes,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: _showResult
                ? Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: GlassContainer(
                      hoverable: true,
                      padding: const EdgeInsets.all(24),
                      child: _ResultContent(
                        animation: _ringCtrl,
                        highConf: _highConf,
                        imageBytes: _selectedImageBytes,
                        predictionLabel: _predictionLabel!,
                        confidence: _confidence ?? 0,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          GlassContainer(
            hoverable: true,
            padding: const EdgeInsets.all(24),
            child: _ImpactCard(
              isLoading: _isDashboardLoading,
              error: _dashboardError,
              itemsScanned: _classificationCount,
              carbonSavedKg: _carbonSavedKg,
              streakDays: _streakDays,
              badgesEarned: _badgesEarned,
            ),
          ),
          const SizedBox(height: 20),
          GlassContainer(
            hoverable: true,
            padding: const EdgeInsets.all(24),
            child: _RecentScansCard(
              isLoading: _isDashboardLoading,
              error: _dashboardError,
              scans: _recentScans,
            ),
          ),
        ],
      ),
    );
  }
}

//  [REMOVE _HoverGlassCard Logic - redundant with GlassContainer(hoverable: true)]

// ═══════════════════════════════════════════════════════
//  TOP BAR  — demo toggles + stat pills
// ═══════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showResult,
    required this.highConf,
    required this.isBusy,
    required this.onPickImage,
    required this.pointsValue,
    required this.rankValue,
  });

  final bool showResult;
  final bool highConf;
  final bool isBusy;
  final VoidCallback onPickImage;
  final String pointsValue;
  final String rankValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DemoToggle(
          icon: Icons.add_a_photo_outlined,
          tooltip: isBusy ? 'Please wait...' : 'Capture or upload image',
          isActive: showResult || isBusy,
          onTap: onPickImage,
        ),
        const SizedBox(width: 6),
        if (showResult)
          _DemoToggle(
            icon: highConf
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            tooltip: highConf ? 'High confidence' : 'Needs review',
            isActive: !highConf,
            accentColor: Colors.amber,
            onTap: onPickImage,
          ),
        const Spacer(),
        _StatPill(label: 'Points', value: pointsValue),
        const SizedBox(width: 10),
        _StatPill(label: 'Rank', value: rankValue),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  STAT PILL
// ═══════════════════════════════════════════════════════

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.neonGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  DEMO TOGGLE
// ═══════════════════════════════════════════════════════

class _DemoToggle extends StatefulWidget {
  const _DemoToggle({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  State<_DemoToggle> createState() => _DemoToggleState();
}

class _DemoToggleState extends State<_DemoToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? AppColors.neonGreen;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isActive
                  ? accent.withValues(alpha: 0.15)
                  : _hovered
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.isActive
                  ? accent
                  : isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppColors.lightText.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  UPLOAD CONTENT  (inside hover glass card)
// ═══════════════════════════════════════════════════════

class _UploadContent extends StatelessWidget {
  const _UploadContent({
    required this.onTap,
    required this.isLoading,
    required this.isClassifying,
    required this.status,
    required this.imageBytes,
  });

  final VoidCallback onTap;
  final bool isLoading;
  final bool isClassifying;
  final String status;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.photo_camera_outlined,
              size: 28,
              color: AppColors.neonGreen.withValues(alpha: 0.7),
            ),
          ),

          SizedBox(height: 20),
          Text(
            'Identify Waste',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: GoogleFonts.inter(fontSize: 13, color: muted),
            textAlign: TextAlign.center,
          ),
          if (isLoading || isClassifying) ...[
            const SizedBox(height: 12),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
          const SizedBox(height: 16),
          // Row(
          //   mainAxisSize: MainAxisSize.min,
          //   children: [
          //     Icon(
          //       Icons.cloud_upload_outlined,
          //       size: 14,
          //       color: AppColors.neonGreen.withValues(alpha: 0.45),
          //     ),
          //     const SizedBox(width: 6),
          //     Text(
          //       'or drag & drop',
          //       style: GoogleFonts.inter(
          //         fontSize: 11,
          //         color: isDark
          //             ? Colors.white.withValues(alpha: 0.22)
          //             : Colors.black.withValues(alpha: 0.25),
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  RESULT CONTENT
// ═══════════════════════════════════════════════════════

class _ResultContent extends StatelessWidget {
  const _ResultContent({
    required this.animation,
    required this.highConf,
    required this.imageBytes,
    required this.predictionLabel,
    required this.confidence,
  });

  final AnimationController animation;
  final bool highConf;
  final Uint8List? imageBytes;
  final String predictionLabel;
  final double confidence;

  double get _score => confidence.clamp(0, 1).toDouble();
  String get _label => '${(confidence * 100).toStringAsFixed(0)}%';
  Color get _ringColor =>
      highConf ? AppColors.neonGreen : const Color(0xFFFFA726);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : AppColors.lightTextSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(
              highConf ? Icons.check_circle_rounded : Icons.info_rounded,
              size: 16,
              color: _ringColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Classification Result',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Body: thumbnail + details + ring
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageBytes == null
                  ? Container(
                      width: 80,
                      height: 80,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.04),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 24,
                        color: muted,
                      ),
                    )
                  : Image.memory(
                      imageBytes!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 16),

            // Text details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: GoogleFonts.inter(fontSize: 11, color: muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    predictionLabel,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confidence ${(confidence * 100).toStringAsFixed(2)}%',
                    style: GoogleFonts.inter(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),

            // Ring
            _ConfidenceRing(
              animation: animation,
              score: _score,
              label: _label,
              color: _ringColor,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Status badge
        _StatusBadge(highConf: highConf, color: _ringColor),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  MY IMPACT CARD  (right column)
// ═══════════════════════════════════════════════════════

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({
    required this.isLoading,
    required this.error,
    required this.itemsScanned,
    required this.carbonSavedKg,
    required this.streakDays,
    required this.badgesEarned,
  });

  final bool isLoading;
  final String? error;
  final int itemsScanned;
  final double carbonSavedKg;
  final int streakDays;
  final int badgesEarned;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.eco_outlined,
              size: 16,
              color: AppColors.neonGreen.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              'My Impact',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (isLoading) ...[
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 12),
        ],
        if (error != null) ...[
          Text(
            error!,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Stats grid
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.qr_code_scanner_rounded,
                value: itemsScanned.toString(),
                label: 'Items Scanned',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                icon: Icons.co2_rounded,
                value: carbonSavedKg.toStringAsFixed(1),
                label: 'Carbon Saved (kg)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.local_fire_department_outlined,
                value: streakDays.toString(),
                label: 'Day Streak',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                icon: Icons.emoji_events_outlined,
                value: badgesEarned.toString(),
                label: 'Badges Earned',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.5),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.neonGreen.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.35)
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  RECENT SCANS CARD  (right column)
// ═══════════════════════════════════════════════════════

class _RecentScansCard extends StatelessWidget {
  const _RecentScansCard({
    required this.isLoading,
    required this.error,
    required this.scans,
  });

  final bool isLoading;
  final String? error;
  final List<_ScanData> scans;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 16,
              color: AppColors.neonGreen.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              'Recent Scans',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const Spacer(),
            Text(
              'View All',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.neonGreen.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (isLoading)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else if (error != null)
          Text(
            error!,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppColors.lightTextSecondary,
            ),
          )
        else if (scans.isEmpty)
          Text(
            'No scans yet. Classify your first item to build activity.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppColors.lightTextSecondary,
            ),
          )
        else
          ...List.generate(scans.length, (i) {
            final s = scans[i];
            return Padding(
              padding: EdgeInsets.only(top: i > 0 ? 10 : 0),
              child: _ScanTile(data: s),
            );
          }),
      ],
    );
  }
}

class _ScanData {
  const _ScanData(
    this.icon,
    this.item,
    this.category,
    this.points,
    this.confirmed,
  );
  final IconData icon;
  final String item;
  final String category;
  final String points;
  final bool confirmed;
}

class _ScanTile extends StatelessWidget {
  const _ScanTile({required this.data});
  final _ScanData data;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.white.withValues(alpha: 0.4),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.04),
            ),
            child: Icon(
              data.icon,
              size: 16,
              color: AppColors.neonGreen.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 12),

          // Item + category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.item,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                Text(
                  data.category,
                  style: GoogleFonts.inter(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),

          // Points badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: data.confirmed
                  ? AppColors.neonGreen.withValues(alpha: 0.10)
                  : const Color(0xFFFFA726).withValues(alpha: 0.10),
            ),
            child: Text(
              data.points,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: data.confirmed
                    ? AppColors.neonGreen
                    : const Color(0xFFFFA726),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  CONFIDENCE RING
// ═══════════════════════════════════════════════════════

class _ConfidenceRing extends StatelessWidget {
  const _ConfidenceRing({
    required this.animation,
    required this.score,
    required this.label,
    required this.color,
  });

  final AnimationController animation;
  final double score;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(animation.value) * score;
        return SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (animation.value > 0.3)
                CustomPaint(
                  size: const Size(56, 56),
                  painter: _GlowRingPainter(
                    progress: progress,
                    color: color.withValues(alpha: 0.12),
                    strokeWidth: 7,
                  ),
                ),
              CustomPaint(
                size: const Size(56, 56),
                painter: _RingPainter(
                  progress: progress,
                  color: color,
                  trackColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                  strokeWidth: 3.5,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
//  RING PAINTERS
// ═══════════════════════════════════════════════════════

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width - strokeWidth) / 2;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) =>
      o.progress != progress || o.color != color;
}

class _GlowRingPainter extends CustomPainter {
  _GlowRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width - strokeWidth) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowRingPainter o) =>
      o.progress != progress || o.color != color;
}

// ═══════════════════════════════════════════════════════
//  STATUS BADGE
// ═══════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.highConf, required this.color});
  final bool highConf;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (highConf) {
      return _badge(
        icon: Icons.stars_rounded,
        text: '+10 Points Awarded',
        color: AppColors.neonGreen,
        isDark: isDark,
      );
    }
    return _badge(
      icon: Icons.hourglass_top_rounded,
      text: 'Under Review by Moderators. Points pending.',
      color: const Color(0xFFFFA726),
      isDark: isDark,
    );
  }

  Widget _badge({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color: color.withValues(alpha: isDark ? 0.08 : 0.06),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
