import 'dart:ui';

import 'package:flutter/material.dart';

/// 纯透明玻璃 tab 栏，无模糊。
class GlassBottomBar extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double height;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? rippleColor;

  const GlassBottomBar({
    Key? key,
    required this.child,
    required this.height,
    // 关闭模糊：完全不糊
    this.blurSigma = 0,
    this.margin,
    this.borderRadius = 28,
    this.rippleColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 纯透明：几乎不填充，只靠边框和高光显形
    final fillTop = isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.white.withOpacity(0.10);
    final fillBottom = isDark
        ? Colors.white.withOpacity(0.02)
        : Colors.white.withOpacity(0.06);
    final border = isDark
        ? Colors.white.withOpacity(0.50)
        : Colors.white.withOpacity(0.90);
    final highlight = isDark
        ? Colors.white.withOpacity(0.30)
        : Colors.white.withOpacity(0.80);
    final shadow = isDark
        ? Colors.black.withOpacity(0.15)
        : Colors.black.withOpacity(0.08);
    final ripple = rippleColor ??
        (isDark
            ? Colors.white.withOpacity(0.30)
            : Colors.white.withOpacity(0.40));

    final bar = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        // blurSigma=0，完全不糊
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [fillTop, fillBottom],
              ),
              border: Border.all(color: border, width: 1.2),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 1.4,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      color: highlight,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(borderRadius),
                    splashColor: ripple,
                    highlightColor: ripple.withOpacity(0.85),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      left: false,
      right: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: margin ?? const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: bar,
      ),
    );
  }
}