import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:qinglong_app/base/ui/liquid_lens_layer.dart';

/// 液态玻璃底部 tab 栏。
///
/// 视觉分四层，从下到上：
///
/// 1. 玻璃面板：真实背景模糊（[blurSigma]）+ 上亮下暗渐变填充 + 边框 + 顶部高光条。
///    依赖外层 `Scaffold(extendBody: true)`，否则底栏背后没有内容可模糊。
/// 2. 跟随光斑：以药丸中心为圆心的径向白光，药丸滑动时光斑跟着走，
///    这是"液态"最廉价也最有效的暗示。
/// 3. 液态药丸：选中项背后的胶囊。切换 tab 时用弹簧（[_spring]）移动，
///    并按当前速度做横向拉伸 / 纵向压扁，停下时回弹成正圆角矩形。
/// 4. [child]：真正的导航栏（图标 + 文字）。
///
/// 说明：本实现不使用 fragment shader，因此没有边缘折射和色散。
/// 好处是不要求 Impeller、不受 Flutter / Dart 版本限制，任何机型表现一致。
class GlassBottomBar extends StatefulWidget {
  const GlassBottomBar({
    Key? key,
    required this.child,
    required this.height,
    required this.currentIndex,
    required this.itemCount,
    this.blurSigma = 14,
    this.glassOpacity = 0.55,
    this.backdropKey,
    this.refraction = true,
    this.margin,
    this.borderRadius = 28,
    this.pillColor,
  })  : assert(itemCount > 0),
        assert(glassOpacity >= 0),
        super(key: key);

  final Widget child;

  /// 玻璃条自身高度，不含安全区。
  final double height;

  /// 当前选中的 tab 下标，驱动药丸位置。
  final int currentIndex;

  /// tab 总数，用于均分药丸宽度。
  final int itemCount;

  /// 背景模糊强度。0 表示完全不模糊（纯透明玻璃）。
  final double blurSigma;

  /// 玻璃「奶感」总控：等比缩放所有白色叠加层的不透明度。
  ///
  /// - `1.0` 默认
  /// - `0.5` 更透，背景看得更清
  /// - `0` 只剩模糊和边框，填充全透
  ///
  /// 不影响 [blurSigma]（模糊）和阴影，只影响白色蒙层的浓度。
  final double glassOpacity;

  /// 指向包裹页面内容的 [RepaintBoundary]，折射层靠它采样背景像素。
  /// 不传则不做折射，视觉退回纯 Dart 玻璃。
  final GlobalKey? backdropKey;

  /// 是否启用 shader 边缘折射。着色器加载失败时会自动降级，无需手动关。
  final bool refraction;

  final EdgeInsetsGeometry? margin;

  final double borderRadius;

  /// 药丸填充色。为空时按深浅色主题自动取白色半透明。
  final Color? pillColor;

  @override
  State<GlassBottomBar> createState() => _GlassBottomBarState();
}

class _GlassBottomBarState extends State<GlassBottomBar>
    with SingleTickerProviderStateMixin {
  /// 偏硬、略欠阻尼的弹簧：切换时能看到一点过冲，但不会晃。
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 24,
  );

  /// 速度归一化基准，单位是"每秒滑过几个 tab"。
  /// 用来把原始速度映射到 0~1 的形变强度。
  static const double _velocityScale = 6.0;

  /// 最大横向拉伸比例。
  static const double _maxStretch = 0.14;

  late AnimationController _ctrl;

  /// 平滑后的速度，单位 tab/秒。同时用于形变和作为下一次弹簧的初速度，
  /// 这样连续快速点两个 tab 时药丸是接着飞而不是重新起步。
  double _velocity = 0;

  double _lastValue = 0;
  Duration? _lastStamp;

  @override
  void initState() {
    super.initState();
    _lastValue = widget.currentIndex.toDouble();
    _ctrl = AnimationController.unbounded(vsync: this, value: _lastValue)
      ..addListener(_handleTick);
  }

  @override
  void didUpdateWidget(GlassBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _ctrl.animateWith(
        SpringSimulation(
          _spring,
          _ctrl.value,
          widget.currentIndex.toDouble(),
          _velocity,
        ),
      );
    }
  }

  /// 每帧按位移差估算速度。AnimationController 不直接暴露速度，
  /// 而 SpringSimulation 的 dx() 需要自己记 elapsed，帧差更省事且够准。
  void _handleTick() {
    final Duration now = SchedulerBinding.instance.currentFrameTimeStamp;
    final Duration? last = _lastStamp;
    if (last != null) {
      final double dt =
          (now - last).inMicroseconds / Duration.microsecondsPerSecond;
      if (dt > 0) {
        final double raw = (_ctrl.value - _lastValue) / dt;
        // 低通滤波，避免个别掉帧把形变抖出来
        _velocity = _velocity * 0.55 + raw * 0.45;
      }
    }
    _lastStamp = now;
    _lastValue = _ctrl.value;
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_handleTick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    /// 按 [GlassBottomBar.glassOpacity] 缩放白色蒙层浓度。
    Color tint(double alpha) =>
        Colors.white.withOpacity((alpha * widget.glassOpacity).clamp(0.0, 1.0));

    /// 边缘专用：用平方根衰减，降透明度时边缘比填充掉得慢。
    ///
    /// 玻璃「有形状」全靠边缘。填充和边缘同比例变淡的话，整条会散成一片雾，
    /// 看起来像没渲染出来 —— 反而更不像玻璃。
    Color edgeTint(double alpha) => Colors.white.withOpacity(
        (alpha * math.sqrt(widget.glassOpacity)).clamp(0.0, 1.0));

    // 玻璃本体：上亮下暗，模拟光从上方来。
    // 填充刻意压到接近零 —— 通透感靠模糊 + 边框 + 高光撑，不靠填充。
    final Color fillTop = isDark ? tint(0.05) : tint(0.12);
    final Color fillBottom = isDark ? tint(0.02) : tint(0.05);
    final Color border = isDark ? edgeTint(0.20) : edgeTint(0.42);
    final Color rimHighlight = isDark ? edgeTint(0.30) : edgeTint(0.70);
    final Color shadow = isDark
        ? Colors.black.withOpacity(0.28)
        : Colors.black.withOpacity(0.12);

    final Color pillFill =
        widget.pillColor ?? (isDark ? tint(0.10) : tint(0.20));
    final Color pillBorder = isDark ? tint(0.26) : tint(0.55);
    final Color glow = isDark ? tint(0.07) : tint(0.14);

    return SafeArea(
      top: false,
      left: false,
      right: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: widget.margin ?? const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shadow,
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blurSigma,
                sigmaY: widget.blurSigma,
              ),
              child: Container(
                height: widget.height,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[fillTop, fillBottom],
                  ),
                  border: Border.all(color: border, width: 1.0),
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return _buildContent(
                      constraints: constraints,
                      pillFill: pillFill,
                      pillBorder: pillBorder,
                      glow: glow,
                      rimHighlight: rimHighlight,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required BoxConstraints constraints,
    required Color pillFill,
    required Color pillBorder,
    required Color glow,
    required Color rimHighlight,
  }) {
    final double innerWidth = constraints.maxWidth;
    final double innerHeight = constraints.maxHeight;
    final double tabWidth = innerWidth / widget.itemCount;

    final double maxIndex = (widget.itemCount - 1).toDouble();
    // 弹簧会过冲到区间外，这里只夹取绘制用的位置，不动 controller 的值，
    // 否则过冲的那点"活力"就没了。
    final double pos = _ctrl.value.clamp(-0.35, maxIndex + 0.35).toDouble();

    // 形变强度：0 静止，1 全速
    final double normalized =
        (_velocity / _velocityScale).clamp(-1.0, 1.0).toDouble();
    final double activity = normalized.abs();

    final double stretch = activity * _maxStretch;
    final double scaleX = 1.0 + stretch + activity * 0.04;
    final double scaleY = 1.0 - stretch * 0.55;

    final double pillHeight =
        (innerHeight - 12).clamp(24.0, innerHeight).toDouble();
    final double pillWidth = (tabWidth - 8).clamp(24.0, tabWidth).toDouble();

    // 光斑中心跟着药丸，换算成 Alignment 的 -1..1
    final double centerFraction = ((pos + 0.5) * tabWidth) / innerWidth;
    final double glowX = (centerFraction * 2 - 1).clamp(-1.0, 1.0).toDouble();

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 边缘折射：只画圆角边缘那一圈，内部透明让下层模糊透出。
        // 放在最底下是因为它属于"玻璃本体"，高光和药丸都该压在它上面。
        if (widget.refraction && widget.backdropKey != null)
          LiquidLensLayer(
            backdropKey: widget.backdropKey!,
            borderRadius: widget.borderRadius,
            // 边缘带要窄于图标到边框的留白，否则折射会盖到图标上
            refractionHeight: 13,
            refractionAmount: 12,
            depthEffect: 0.3,
            chromaticAberration: 0.35,
            opacity: 0.85,
          ),

        // 跟随光斑：滑动时更亮，停下后回落
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: RadialGradient(
              center: Alignment(glowX, 0),
              radius: 0.75,
              colors: <Color>[
                glow.withOpacity(
                  (glow.opacity * (1 + activity * 0.7)).clamp(0.0, 1.0),
                ),
                glow.withOpacity(0),
              ],
            ),
          ),
        ),

        // 液态药丸
        Positioned(
          left: pos * tabWidth,
          top: 0,
          bottom: 0,
          width: tabWidth,
          child: Center(
            child: Transform.scale(
              scaleX: scaleX,
              scaleY: scaleY,
              child: Container(
                width: pillWidth,
                height: pillHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(pillHeight / 2),
                  // 药丸自身也是上亮下暗，跟大面板同一个光源
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      pillFill,
                      pillFill.withOpacity(
                        (pillFill.opacity * 0.55).clamp(0.0, 1.0),
                      ),
                    ],
                  ),
                  border: Border.all(color: pillBorder, width: 0.9),
                ),
              ),
            ),
          ),
        ),

        // 顶部高光条：玻璃上沿的反光
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 1.2,
            margin: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: LinearGradient(
                colors: <Color>[
                  rimHighlight.withOpacity(0),
                  rimHighlight,
                  rimHighlight.withOpacity(0),
                ],
                stops: const <double>[0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // 导航栏本体
        widget.child,
      ],
    );
  }
}
