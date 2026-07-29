import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 全 app 自定义背景图：从本地路径读取，叠加半透明遮罩保证文字可读。
///
/// ## 为什么所有取值都走内存缓存
///
/// 这些 getter 会在 `build()` 里被调用（`pageBg` 散布在 7 个页面），
/// 而原实现每次都做 `SharedPreferences` 读 + `File.existsSync()`。
/// 也就是每帧、每页面都在同步碰磁盘 —— 列表滚动时这是实打实的卡顿源。
///
/// 现在所有值在首次访问时读一次进内存，之后只在 [_token] 变化（用户改了设置）
/// 时失效重读。磁盘访问从"每帧数次"降到"每次改设置一次"。
class CustomBg {
  /// 同路径覆盖文件时强制 Image 刷新，同时用作缓存失效信号
  static int _token = 0;

  // ---- 内存缓存 ----
  static int _cacheToken = -1;
  static bool _enabled = false;
  static String _path = '';
  static double _dim = 0.45;
  static double _blur = 0;
  static bool _fileExists = false;

  static void _ensureCache() {
    if (_cacheToken == _token) return;
    _enabled = SpUtil.getBool(spCustomBgEnabled, defValue: false);
    _path = SpUtil.getString(spCustomBgPath, defValue: '');
    _dim = _clampDim(SpUtil.getDouble(spCustomBgDim, defValue: 0.45));
    _blur = _clampBlur(SpUtil.getDouble(spCustomBgBlur, defValue: 0));
    // 整个 app 生命周期里只在这里碰磁盘
    if (_enabled && _path.isNotEmpty) {
      try {
        _fileExists = File(_path).existsSync();
      } catch (_) {
        _fileExists = false;
      }
    } else {
      _fileExists = false;
    }
    _cacheToken = _token;
  }

  static double _clampDim(double v) {
    if (v.isNaN) return 0.45;
    if (v < 0) return 0;
    if (v > 0.85) return 0.85;
    return v;
  }

  static double _clampBlur(double v) {
    if (v.isNaN) return 0;
    if (v < 0) return 0;
    if (v > 25) return 25;
    return v;
  }

  static bool get enabled {
    _ensureCache();
    return _enabled;
  }

  static String get path {
    _ensureCache();
    return _path;
  }

  static int get token => _token;

  /// 遮罩强度。0.0 最透（图最显）~ 0.85 最深遮罩。
  static double get dim {
    _ensureCache();
    return _dim;
  }

  /// 背景图自身的模糊半径。0 = 不模糊。
  ///
  /// 背景越模糊，前景文字越好读，也越能凸显底栏的玻璃质感
  /// —— 因为玻璃后面本来就该是"认得出但不清晰"的东西。
  static double get blur {
    _ensureCache();
    return _blur;
  }

  static bool get hasImage {
    _ensureCache();
    return _fileExists;
  }

  /// 卡片在背景图模式下的不透明度。
  ///
  /// 原来这个 0.88 硬编码在 stats_page 两处，改一次要找两个地方。
  static double get cardOpacity => hasImage ? 0.88 : 1.0;

  /// 页面 scaffold 在启用背景时用透明，否则用原色
  static Color? pageBg(Color? normal) => hasImage ? Colors.transparent : normal;

  static void _bump() => _token++;

  static Future<void> setEnabled(bool v) async {
    await SpUtil.putBool(spCustomBgEnabled, v);
    _bump();
  }

  static Future<void> setPath(String p) async {
    await SpUtil.putString(spCustomBgPath, p);
    _bump();
  }

  static Future<void> setDim(double v) async {
    await SpUtil.putDouble(spCustomBgDim, _clampDim(v));
    _bump();
  }

  static Future<void> setBlur(double v) async {
    await SpUtil.putDouble(spCustomBgBlur, _clampBlur(v));
    _bump();
  }

  static Future<void> clear() async {
    final old = path;
    await SpUtil.putBool(spCustomBgEnabled, false);
    await SpUtil.putString(spCustomBgPath, '');
    _bump();
    if (old.isNotEmpty) {
      try {
        final f = File(old);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
  }
}

/// 包一层：底层背景图 + 可选模糊 + 遮罩 + 子页面。
class AppBackgroundShell extends StatelessWidget {
  final Widget child;
  final Color? fallbackColor;

  const AppBackgroundShell({
    Key? key,
    required this.child,
    this.fallbackColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!CustomBg.hasImage) {
      return child;
    }

    final double dim = CustomBg.dim;
    final double blur = CustomBg.blur;
    final String path = CustomBg.path;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final MediaQueryData mq = MediaQuery.of(context);
    // 按屏幕宽度限制解码尺寸。手机相册随手一张就是 4000px 宽，
    // 全尺寸解码要几十 MB 常驻内存，而铺满屏幕根本用不到那个分辨率。
    // 模糊时更可以再省一半 —— 反正要被糊掉。
    final double targetLogicalWidth =
        blur > 0 ? mq.size.width * 0.6 : mq.size.width;
    final int decodeWidth =
        (targetLogicalWidth * mq.devicePixelRatio).round().clamp(360, 2160);

    Widget image = Image.file(
      File(path),
      key: ValueKey('custom_bg_${CustomBg.token}_$path'),
      fit: BoxFit.cover,
      cacheWidth: decodeWidth,
      // true 才不会在重建时先闪一下空白
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: fallbackColor ?? Theme.of(context).scaffoldBackgroundColor,
      ),
    );

    if (blur > 0) {
      // ImageFiltered 比 BackdropFilter 便宜：只处理这一张图，
      // 不需要把下层已合成的内容读回来。
      image = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: image,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 固定底层，避免子页面白色 scaffold 盖住
        Positioned.fill(child: image),
        // 遮罩：白天偏白、暗色偏黑，跟随主题亮度
        if (dim > 0)
          Positioned.fill(
            child: ColoredBox(
              color: (isDark ? Colors.black : Colors.white).withOpacity(dim),
            ),
          ),
        // 强制子树默认 scaffold/canvas 透明，避免各页不设 backgroundColor 时盖住背景
        Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: Colors.transparent,
            canvasColor: Colors.transparent,
            cardColor: Theme.of(context).cardColor.withOpacity(0.92),
          ),
          child: child,
        ),
      ],
    );
  }
}
