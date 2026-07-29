import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 液态玻璃折射层（路线 2）。
///
/// 工作方式与 wekit 的 AGSL 版本不同，原因是 Flutter 3.7 没有
/// `ImageFilter.shader`（那是 Impeller-only 的新 API），也没有 AGSL
/// `content.eval()` 那种"直接采样当前图层"的能力。所以这里的流程是：
///
/// 1. 页面 body 外面套一个 [RepaintBoundary]，拿 [backdropKey] 引用它。
/// 2. 每帧在 paint 里 `toImageSync()` 抓一张背景位图。
/// 3. 把位图当 `sampler2D` 喂给 `shaders/liquid_glass_lens.frag`，
///    着色器只在圆角矩形的边缘带上做折射采样，内部输出透明。
///
/// 因此本层只负责"边缘折射 + 色散"，底下的 `BackdropFilter` 模糊照旧生效，
/// 两者叠加才是完整效果。
///
/// 抓图用 `pixelRatio: 1.0`：背景本来就要被模糊和折射，多余的分辨率看不出来，
/// 但每帧全屏拷贝的开销会按平方增长，低端机吃不消。
///
/// 着色器不可用时（加载失败、平台不支持）本层渲染为空，
/// 视觉自动退回路线 1 的纯 Dart 玻璃，不会崩也不会留白。
class LiquidLensLayer extends StatefulWidget {
  const LiquidLensLayer({
    Key? key,
    required this.backdropKey,
    required this.borderRadius,
    this.refractionHeight = 22,
    this.refractionAmount = 20,
    this.depthEffect = 0.35,
    this.chromaticAberration = 0.4,
    this.opacity = 1.0,
  }) : super(key: key);

  /// 指向包裹页面内容的 [RepaintBoundary]。为空或尚未挂载时本层不绘制。
  final GlobalKey backdropKey;

  final double borderRadius;

  /// 边缘带宽度，视觉上等于"玻璃厚度"。
  final double refractionHeight;

  /// 采样偏移量，越大边缘扭曲越强。
  final double refractionAmount;

  /// 球面凸起感，0 关闭。
  final double depthEffect;

  /// 色散强度，0 关闭。
  final double chromaticAberration;

  /// 整体强度。
  final double opacity;

  @override
  State<LiquidLensLayer> createState() => _LiquidLensLayerState();
}

class _LiquidLensLayerState extends State<LiquidLensLayer> {
  /// 着色器编译一次就够，多个实例共享。
  static Future<ui.FragmentProgram?>? _programFuture;

  static Future<ui.FragmentProgram?> _loadProgram() {
    return _programFuture ??= ui.FragmentProgram.fromAsset(
      'shaders/liquid_glass_lens.frag',
    ).then<ui.FragmentProgram?>((ui.FragmentProgram p) => p).catchError(
      (Object e, StackTrace st) {
        // 老设备 / 不支持 runtime shader 的平台会走到这里。
        // 静默降级，不要把整个底栏搞挂。
        debugPrint('[LiquidLensLayer] shader 加载失败，降级为普通玻璃: $e');
        return null;
      },
    );
  }

  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _loadProgram().then((ui.FragmentProgram? program) {
      if (!mounted || program == null) return;
      setState(() {
        _shader = program.fragmentShader();
      });
    });
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui.FragmentShader? shader = _shader;
    if (shader == null) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: _LensPainter(
        shader: shader,
        backdropKey: widget.backdropKey,
        selfContext: context,
        borderRadius: widget.borderRadius,
        refractionHeight: widget.refractionHeight,
        refractionAmount: widget.refractionAmount,
        depthEffect: widget.depthEffect,
        chromaticAberration: widget.chromaticAberration,
        opacity: widget.opacity,
      ),
      size: Size.infinite,
    );
  }
}

class _LensPainter extends CustomPainter {
  _LensPainter({
    required this.shader,
    required this.backdropKey,
    required this.selfContext,
    required this.borderRadius,
    required this.refractionHeight,
    required this.refractionAmount,
    required this.depthEffect,
    required this.chromaticAberration,
    required this.opacity,
  });

  final ui.FragmentShader shader;
  final GlobalKey backdropKey;
  final BuildContext selfContext;
  final double borderRadius;
  final double refractionHeight;
  final double refractionAmount;
  final double depthEffect;
  final double chromaticAberration;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || opacity <= 0) return;

    final RenderObject? backdropRender =
        backdropKey.currentContext?.findRenderObject();
    if (backdropRender is! RenderRepaintBoundary) return;
    // 布局还没跑完时抓图会抛异常，直接跳过这一帧。
    if (!backdropRender.hasSize || backdropRender.debugNeedsPaint) return;

    final RenderObject? selfRender = selfContext.findRenderObject();
    if (selfRender is! RenderBox || !selfRender.hasSize) return;

    ui.Image? backdrop;
    try {
      backdrop = backdropRender.toImageSync(pixelRatio: 1.0);

      // 本层左上角在背景图坐标系里的位置。
      // pixelRatio 取 1.0，所以逻辑坐标和图像像素是 1:1，不用再换算。
      final Offset globalSelf = selfRender.localToGlobal(Offset.zero);
      final Offset globalBackdrop = backdropRender.localToGlobal(Offset.zero);
      final Offset origin = globalSelf - globalBackdrop;

      shader
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, backdrop.width.toDouble())
        ..setFloat(3, backdrop.height.toDouble())
        ..setFloat(4, origin.dx)
        ..setFloat(5, origin.dy)
        ..setFloat(6, borderRadius)
        // 边缘带不能宽过短边的一半，否则内部判定失效、整条会被涂满
        ..setFloat(
          7,
          refractionHeight.clamp(0.0, size.shortestSide / 2).toDouble(),
        )
        ..setFloat(8, refractionAmount)
        ..setFloat(9, depthEffect)
        ..setFloat(10, chromaticAberration)
        ..setFloat(11, opacity.clamp(0.0, 1.0).toDouble())
        ..setImageSampler(0, backdrop);

      final RRect rrect = RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(borderRadius),
      );
      canvas.save();
      // 着色器自己也用 SDF 挡了形状外，这里再夹一次是为了防抗锯齿溢出
      canvas.clipRRect(rrect);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
      canvas.restore();
    } catch (e) {
      debugPrint('[LiquidLensLayer] 折射绘制失败，本帧跳过: $e');
    } finally {
      // 每帧一张全屏图，不回收会迅速吃满显存
      backdrop?.dispose();
    }
  }

  @override
  bool shouldRepaint(_LensPainter old) {
    // 背景每帧都可能变（列表滚动），所以恒为 true。
    // 外层已经用 RepaintBoundary 把重绘范围限制在底栏内。
    return true;
  }
}
