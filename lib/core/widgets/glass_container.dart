import 'dart:ui';
import 'package:flutter/material.dart';

/// True liquid‑glass container.
///
/// Every instance uses `ClipRRect` + `BackdropFilter(σ24)` so the
/// breathing background blobs distort through it.
///
/// Dark  → `white.withOpacity(0.02)`, border `white.withOpacity(0.08)`
/// Light → `white.withOpacity(0.35)`, border `white.withOpacity(0.20)`
///
/// Shadow is a single soft black — NO green glow.
class GlassContainer extends StatefulWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 24.0,
    this.sigma = 24.0,
    this.width,
    this.height,
    this.borderOpacity,
    this.borderColor,
    this.borderWidth,
    this.customShadows,
    this.hoverable = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double sigma;
  final double? width;
  final double? height;
  final double? borderOpacity;
  final Color? borderColor;
  final double? borderWidth;
  final List<BoxShadow>? customShadows;
  final bool hoverable;

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fill = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.35);

    final border = (widget.borderColor ?? Colors.white).withValues(
      alpha: widget.borderOpacity ??
          (_hovered && widget.hoverable ? 0.20 : (isDark ? 0.12 : 0.20)),
    );

    // Dynamic shadow for Light Mode
    final defaultShadow = [
      BoxShadow(
        color: isDark ? Colors.black.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.08),
        blurRadius: 32,
        offset: const Offset(0, 8),
      ),
    ];

    Widget content = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: widget.customShadows ?? defaultShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.sigma, sigmaY: widget.sigma),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: border, width: widget.borderWidth ?? 1.0),
            ),
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.hoverable) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          child: content,
        ),
      );
    }

    return content;
  }
}
