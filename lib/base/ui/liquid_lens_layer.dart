import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 液态玻璃折射层（路线 2）。
///
/// Flutter 3.7 没有 `ImageFilter.shader`（Impeller-only 的新 API），也没有
/// AGSL `content.eval()` 那种"直接采样当前图层"的能力。所以背景位图由 Dart 侧
/// 从 [backdropKey] 指向的 [RepaintBoundary] 抓取，当 `sampler2D` 喂给
/// `shaders/liquid_glass_lens.frag`。
///
/// 着色器只在圆角矩形的**边缘带**上做折射采样，带内以外输出全透明，
/// 底下的 `BackdropFilter` 模糊照旧生效，两者叠加才是完整效果。
///
/// ## 抓图时机
///
/// 抓图**不能在 paint 里做**。`toImageSync()` 会同步 raster 目标图层，
/// 在 `CustomPainter.paint` 执行期间调用它，等于在绘制途中递归进合成器，
/// 抛出的异常会让当前 canvas 的 save/clip 栈失衡 —— 后续同一 Stack 里的
/// 兄弟节点（包括导航栏的图标和文字）会被残留的裁剪吃掉，表现为整块消失。
///
/// 所以改成 [SchedulerBinding.addPostFrameCallback] 里抓，画的时候用**上一帧**
/// 的位图。折射是背景的镜像，延迟一帧完全看不出来。
///
/// 抓图用 `pixelRatio: 1.0`：背景本来就要被模糊和折射，多余的分辨率看不出来，
/// 但全屏拷贝的开销按平方增长，低端机吃不消。
///
/// 着色器不可用时（加载失败、平台不支持）本层渲染为空，
/// 视觉自动退回纯 Dart 玻璃，不崩也不留白。
class LiquidLensLayer extends StatefulWidget {
  const LiquidLensLayer({
    Key? key,
    required this.backdropKey,
    required this.borderRadius,
    this.refractionHeight = 14,
    this.refractionAmount = 12,
    this.depthEffect = 0.3,
    this.chromaticAberration = 0.35,
    this.opacity = 1.0,
  }) : super(key: key);

  /// 指向包裹页面内容的 [RepaintBoundary]。
  final GlobalKey backdropKey;

  final double borderRadius;

  /// 边缘带宽度，视觉上等于"玻璃厚度"。
  /// 注意别超过图标到边框的留白，否则折射会盖到图标上。
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
        // 静默降级，别把整个底栏搞挂。
        debugPrint('[LiquidLensLayer] shader 加载失败，降级为普通玻璃: $e');
        return null;
      },
    );
  }

  ui.FragmentShader? _shader;

  /// 上一帧抓到的背景。画的时候用它，抓的时候换新的。
  ui.Image? _backdrop;

  /// 本层左上角在 [_backdrop] 坐标系里的偏移。
  Offset _origin = Offset.zero;

  bool _scheduled = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadProgram().then((ui.FragmentProgram? program) {
      if (_disposed || program == null) return;
      setState(() {
        _shader = program.fragmentShader();
      });
      _scheduleCapture();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _backdrop?.dispose();
    _backdrop = null;
    _shader?.dispose();
    super.dispose();
  }

  /// 每帧结束后抓一次背景，并立刻排下一次，形成持续更新。
  void _scheduleCapture() {
    if (_disposed || _scheduled || _shader == null) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      _capture();
      // 背景可能一直在动（列表滚动），所以持续抓。
      _scheduleCapture();
    });
  }

  void _capture() {
    final RenderObject? backdropRender =
        widget.backdropKey.currentContext?.findRenderObject();
    if (backdropRender is! RenderRepaintBoundary) return;
    if (!backdropRender.hasSize || backdropRender.size.isEmpty) return;

    final RenderObject? selfRender = context.findRenderObject();
    if (selfRender is! RenderBox || !selfRender.hasSize) return;

    ui.Image? fresh;
    try {
      // 不要用 debugNeedsPaint 做守卫：它的实现把返回值写在 assert 里，
      // release 构建 assert 被剥掉 → 读到未初始化的 late 变量 → 抛
      // LateInitializationError。debug 跑得好好的，正式包每帧都炸，
      // 结果就是永远抓不到背景、折射整个消失。
      // postFrameCallback 本身已经保证这一帧画完了，无需额外守卫。
      fresh = backdropRender.toImageSync(pixelRatio: 1.0);
      // pixelRatio 取 1.0，逻辑坐标与图像像素 1:1，不用再换算
      final Offset origin = selfRender.localToGlobal(Offset.zero) -
          backdropRender.localToGlobal(Offset.zero);

      final ui.Image? stale = _backdrop;
      _backdrop = fresh;
      _origin = origin;
      fresh = null; // 交出所有权，下面的 finally 不该回收它
      stale?.dispose();

      if (!_disposed) setState(() {});
    } catch (e) {
      debugPrint('[LiquidLensLayer] 背景抓取失败，沿用上一帧: $e');
    } finally {
      fresh?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui.FragmentShader? shader = _shader;
    final ui.Image? backdrop = _backdrop;
    if (shader == null || backdrop == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        painter: _LensPainter(
          shader: shader,
          backdrop: backdrop,
          origin: _origin,
          borderRadius: widget.borderRadius,
          refractionHeight: widget.refractionHeight,
          refractionAmount: widget.refractionAmount,
          depthEffect: widget.depthEffect,
          chromaticAberration: widget.chromaticAberration,
          opacity: widget.opacity,
        ),
      ),
    );
  }
}

class _LensPainter extends CustomPainter {
  _LensPainter({
    required this.shader,
    required this.backdrop,
    required this.origin,
    required this.borderRadius,
    required this.refractionHeight,
    required this.refractionAmount,
    required this.depthEffect,
    required this.chromaticAberration,
    required this.opacity,
  });

  final ui.FragmentShader shader;
  final ui.Image backdrop;
  final Offset origin;
  final double borderRadius;
  final double refractionHeight;
  final double refractionAmount;
  final double depthEffect;
  final double chromaticAberration;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || opacity <= 0) return;

    // save/restore 必须严格配对：这里和兄弟节点（导航栏图标、文字）共用同一个
    // canvas，任何一次泄漏的 save 或 clip 都会把后面画的东西吃掉。
    canvas.save();
    try {
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

      // 着色器自己也用 SDF 挡了形状外，这里再夹一次是防抗锯齿溢出
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(borderRadius),
        ),
      );
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } catch (e) {
      debugPrint('[LiquidLensLayer] 折射绘制失败，本帧跳过: $e');
    } finally {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LensPainter old) {
    return old.backdrop != backdrop ||
        old.origin != origin ||
        old.shader != shader ||
        old.borderRadius != borderRadius ||
        old.refractionHeight != refractionHeight ||
        old.refractionAmount != refractionAmount ||
        old.depthEffect != depthEffect ||
        old.chromaticAberration != chromaticAberration ||
        old.opacity != opacity;
  }
}
