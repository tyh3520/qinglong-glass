import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// 可复用的玻璃面板。
///
/// 从 [GlassBottomBar] 抽出来的视觉本体，参数含义与那边一致，
/// 好处是底栏、编辑栏、卡片能共用同一套配色规律 —— 不然每处各写一份
/// `withOpacity` 常数，改一次要翻好几个文件，而且很容易调不到一起去。
///
/// 不含药丸和光斑，那些是底栏独有的。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    Key? key,
    required this.child,
    this.blurSigma = 14,
    this.glassOpacity = 0.35,
    this.borderRadius = 28,
    this.shadow = true,
    this.rimHighlight = true,
  }) : super(key: key);

  final Widget child;

  /// 背景模糊强度。0 = 不模糊。
  ///
  /// 别调太大：半径一大背景就糊成一团分辨不出的东西，
  /// 而"分辨不出"看起来就等于不透明，白蒙层压多低都救不回来。
  final double blurSigma;

  /// 白色蒙层浓度总控，等比缩放所有叠加层。
  final double glassOpacity;

  final double borderRadius;

  final bool shadow;

  /// 顶部那道细高光。玻璃上沿的反光，横向长条时才有意义。
  final bool rimHighlight;

  /// 按 [glassOpacity] 缩放的白色蒙层。
  static Color tint(double alpha, double glassOpacity) =>
      Colors.white.withOpacity((alpha * glassOpacity).clamp(0.0, 1.0));

  /// 边缘专用：用平方根衰减，降透明度时边缘比填充掉得慢。
  ///
  /// 玻璃「有形状」全靠边缘。填充和边缘同比例变淡的话，整块会散成一片雾，
  /// 看起来像没渲染出来 —— 反而更不像玻璃。
  static Color edgeTint(double alpha, double glassOpacity) =>
      Colors.white.withOpacity(
          (alpha * math.sqrt(glassOpacity)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fillTop =
        isDark ? tint(0.05, glassOpacity) : tint(0.12, glassOpacity);
    final Color fillBottom =
        isDark ? tint(0.02, glassOpacity) : tint(0.05, glassOpacity);
    final Color border =
        isDark ? edgeTint(0.20, glassOpacity) : edgeTint(0.42, glassOpacity);
    final Color rim =
        isDark ? edgeTint(0.30, glassOpacity) : edgeTint(0.70, glassOpacity);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[fillTop, fillBottom],
        ),
        border: Border.all(color: border, width: 1.0),
      ),
      child: rimHighlight
          ? Stack(
              children: <Widget>[
                child,
                // 必须是 Positioned，不能是 Align。
                //
                // Stack 默认 fit: StackFit.loose，非定位子节点拿到松约束；
                // Align 在 widthFactor/heightFactor 都为 null 且约束有界时会撑到
                // constraints.biggest，于是 Stack 的尺寸变成整个可用区域 ——
                // 编辑栏那条 56 高的玻璃条就糊满全屏，按钮还被 Stack 默认的
                // topStart 甩到左上角。GlassBottomBar 里同样的写法没炸，
                // 只因为它外面套了 Container(height:) 把高度钉死了。
                //
                // 定位子节点不参与 Stack 尺寸计算，高度重新由 child 决定。
                Positioned(
                  top: 0,
                  left: 22,
                  right: 22,
                  height: 1.2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        colors: <Color>[
                          rim.withOpacity(0),
                          rim,
                          rim.withOpacity(0),
                        ],
                        stops: const <double>[0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : child,
    );

    content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: blurSigma > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: content,
            )
          : content,
    );

    if (!shadow) return content;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.28)
                : Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: content,
    );
  }
}
