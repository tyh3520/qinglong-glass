import 'dart:ui';

import 'package:flutter/material.dart';

/// ios 风格液态玻璃底部 tab 容器。
/// 只包一层视觉效果，不改 BottomNavigationBar2 逻辑。
class GlassBottomBar extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double height;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const GlassBottomBar({
    Key? key,
    required this.child,
    required this.height,
    // 更强模糊，接近系统毛玻璃
    this.blurSigma = 36,
    this.margin,
    // 更圆一点，接近悬浮 capsule
    this.borderRadius = 28,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 更透：亮色约 22%~28%，暗色约 8%~14%
    final fillTop = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.28);
    final fillBottom = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.16);
    final border = isDark
        ? Colors.white.withOpacity(0.22)
        : Colors.white.withOpacity(0.55);
    final innerHighlight = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.40);
    final shadow = isDark
        ? Colors.black.withOpacity(0.28)
        : Colors.black.withOpacity(0.10);

    final bar = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
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
              // 外层更透的液态玻璃渐变
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  fillTop,
                  fillBottom,
                ],
              ),
              border: Border.all(color: border, width: 0.8),
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
                          innerHighlight,
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
                Material(
                  type: MaterialType.transparency,
                  child: child,
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
