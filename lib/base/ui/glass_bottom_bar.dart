import 'dart:ui';

import 'package:flutter/material.dart';

/// 拟态玻璃底部 tab 容器。
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
    this.blurSigma = 24,
    this.margin,
    this.borderRadius = 22,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.55);
    final border = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.white.withOpacity(0.70);
    final highlight = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.35);
    final shadow = isDark
        ? Colors.black.withOpacity(0.35)
        : Colors.black.withOpacity(0.12);

    final bar = ClipRRect(
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
                highlight,
                fill,
              ],
            ),
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      left: false,
      right: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: margin ??
            const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: bar,
      ),
    );
  }
}
