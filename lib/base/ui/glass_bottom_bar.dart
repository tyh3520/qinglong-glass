import 'dart:ui';

import 'package:flutter/material.dart';

/// ios‑style liquid‑glass bottom tab bar with ripple click effect.
/// 只包一层视觉效果，不改 BottomNavigationBar2 逻辑。
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
    // 更强模糊，接近系统毛玻璃
    this.blurSigma = 6,
    this.margin,
    // 更圆一点，接近悬浮 capsule
    this.borderRadius = 28,
    // ripple color, defaults to white with slight opacity
    this.rippleColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 更透：亮色约 30%~35%，暗色约 18%~22%
    final fillTop = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.30);
    final fillBottom = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.18);
    final border = isDark
        ? Colors.white.withOpacity(0.22)
        : Colors.white.withOpacity(0.55);
    final highlight = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.40);
    final shadow = isDark
        ? Colors.black.withOpacity(0.28)
        : Colors.black.withOpacity(0.10);
    final ripple = rippleColor ??
        (isDark
            ? Colors.white.withOpacity(0.25)
            : Colors.white.withOpacity(0.35));

    final bar = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
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
                colors: [
                  fillTop,
                  fillBottom,
                ],
              ),
              border: Border.all(color: border, width: 1.0),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 顶部高光条，模拟液态玻璃反光
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 1.2,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          highlight,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // 轻微内层叠色，让图标文字更清晰，但不压透
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              Colors.white.withOpacity(0.04),
                              Colors.transparent,
                              Colors.black.withOpacity(0.08),
                            ]
                          : [
                              Colors.white.withOpacity(0.18),
                              Colors.transparent,
                              Colors.white.withOpacity(0.06),
                            ],
                    ),
                  ),
                ),
                // 包裹 child（BottomNavigationBar2）实现 ripple
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(borderRadius),
                    splashColor: ripple,
                    highlightColor: ripple.withOpacity(0.8),
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