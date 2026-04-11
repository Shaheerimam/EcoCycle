import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The "Glass Engine" — animated layered background with breathing
/// glowing blobs that give `BackdropFilter` widgets real colour
/// variation to distort in real-time.
///
/// Both dark and light modes now have ambient blobs.
/// Blobs gently scale (1.0→1.2) and drift vertically over 8–10 s,
/// causing glass surfaces above to shimmer with living distortion.
class GlassEngineBackground extends StatefulWidget {
  const GlassEngineBackground({super.key});

  @override
  State<GlassEngineBackground> createState() => _GlassEngineBackgroundState();
}

class _GlassEngineBackgroundState extends State<GlassEngineBackground>
    with TickerProviderStateMixin {
  late final AnimationController _breatheA;
  late final AnimationController _breatheB;
  late final AnimationController _breatheC;

  @override
  void initState() {
    super.initState();

    // Stagger the controllers so blobs don't pulse in unison
    _breatheA = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _breatheB = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _breatheC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheA.dispose();
    _breatheB.dispose();
    _breatheC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Container(
      color: isDark ? AppColors.engineBase : AppColors.lightEngineBase,
      child: Stack(
        children: [
          // ── Blob 1: top‑left ───────────────────────
          Positioned(
            top: -80,
            left: -60,
            child: _BreathingBlob(
              animation: _breatheA,
              baseSize: 420,
              color: isDark
                  ? AppColors.blobGreen.withValues(alpha: 0.15)
                  : AppColors.lightBlobMint.withValues(alpha: 0.15),
              sigma: 110,
              driftY: 12,
              maxScale: 1.2,
            ),
          ),

          // ── Blob 2: bottom‑right ───────────────────
          Positioned(
            bottom: -100,
            right: -80,
            child: _BreathingBlob(
              animation: _breatheB,
              baseSize: 380,
              color: isDark
                  ? AppColors.blobTeal.withValues(alpha: 0.10)
                  : AppColors.lightBlobBlue.withValues(alpha: 0.10),
              sigma: 100,
              driftY: -10,
              maxScale: 1.15,
            ),
          ),

          // ── Blob 3: centre accent ──────────────────
          Positioned(
            top: size.height * 0.35,
            left: size.width * 0.3,
            child: _BreathingBlob(
              animation: _breatheC,
              baseSize: 280,
              color: isDark
                  ? AppColors.blobGreen.withValues(alpha: 0.06)
                  : AppColors.lightBlobMint.withValues(alpha: 0.08),
              sigma: 90,
              driftY: 8,
              maxScale: 1.18,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  BREATHING BLOB
//
//  Gently scales from 1.0 → [maxScale] and drifts vertically
//  by ±[driftY] pixels, driven by the provided animation.
// ═══════════════════════════════════════════════════════

class _BreathingBlob extends AnimatedWidget {
  const _BreathingBlob({
    required Animation<double> animation,
    required this.baseSize,
    required this.color,
    required this.sigma,
    this.driftY = 10,
    this.maxScale = 1.2,
  }) : super(listenable: animation);

  final double baseSize;
  final Color color;
  final double sigma;
  final double driftY;
  final double maxScale;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;

    // Smooth eased value for organic feel
    final eased = Curves.easeInOutSine.transform(t);

    final scale = 1.0 + (maxScale - 1.0) * eased;
    final dy = driftY * (eased - 0.5); // centres the drift

    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform.scale(
        scale: scale,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            width: baseSize,
            height: baseSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
