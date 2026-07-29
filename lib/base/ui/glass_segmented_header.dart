import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_surface.dart';

/// 列表页顶部筛选条（全部 / 运行中 / 未使用 / 已禁用 之类）的玻璃底板。
///
/// 这个条是 `SliverPersistentHeader(pinned: true)`，列表内容会从它下面滚过去，
/// 所以它是除底栏之外最值得上玻璃的地方 —— 原来那层
/// `ColoredBox(scaffoldBackgroundColor)` 是**完全不透明**的，
/// 滚过去的内容直接消失在色块后面，看着就是一块贴上去的挡板。
///
/// 任务页、环境变量页、依赖管理页三处各写了一份一模一样的
/// `SliverTabBarDelegate`（连 padding 数值都相同），所以底板抽出来共用。
class GlassSegmentedBar extends StatelessWidget {
  const GlassSegmentedBar({
    Key? key,
    required this.child,
    this.blurSigma = 12,
  }) : super(key: key);

  final Widget child;

  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 比底栏淡一档：这条一直挂在屏幕上，压太重会把整页压暗。
    const double opacity = 0.42;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                isDark
                    ? GlassSurface.tint(0.06, opacity)
                    : GlassSurface.tint(0.16, opacity),
                isDark
                    ? GlassSurface.tint(0.02, opacity)
                    : GlassSurface.tint(0.06, opacity),
              ],
            ),
            // 下沿一条发丝线，把筛选条和列表分开。
            // 没有它的话内容滚上来会和条糊成一片。
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
                width: 0.6,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 分段控件的未选中轨道。
///
/// 原来是不透明的 `segmentedUnCheckBg()`（浅色 #F0F0F0 / 深色 #333333）。
/// 底板换成玻璃后这里仍然实心的话，看上去还是一块灰色药片压在玻璃上
/// —— 观感上等于什么都没改，所以轨道必须一起透。
BoxDecoration glassSegmentedTrack(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.05),
    borderRadius: BorderRadius.circular(9),
    border: Border.all(
      color: isDark
          ? Colors.white.withOpacity(0.09)
          : Colors.white.withOpacity(0.45),
      width: 0.8,
    ),
  );
}

/// 选中滑块。
///
/// 保持 [ThemeColor.blackAndWhite] 的明暗逻辑（浅色白、深色近黑），
/// 只是略微透一点并加一圈亮边，让它像浮在玻璃上的一块更厚的玻璃。
/// 这块**不能太透** —— 选中项的文字要压得住下面滚动的内容。
BoxDecoration glassSegmentedThumb(BuildContext context, WidgetRef ref) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: ref
        .watch(themeProvider)
        .themeColor
        .blackAndWhite()
        .withOpacity(isDark ? 0.72 : 0.86),
    borderRadius: BorderRadius.circular(7),
    border: Border.all(
      color: isDark
          ? Colors.white.withOpacity(0.14)
          : Colors.white.withOpacity(0.75),
      width: 0.8,
    ),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.22 : 0.10),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );
}
