import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_surface.dart';

/// 多选编辑模式下浮在底部的操作栏。
///
/// 任务页和环境变量页原来各写了一份几乎一样的 [OverlayEntry]：同样的
/// `Align` + 满宽 `Container` + 不透明 `bottomNavigationBarTheme.backgroundColor`
/// + `SafeArea` + `SizedBox(height: kBottomNavigationBarHeight)`，
/// 区别只是按钮列表和是否横向滚动。两份都得改，而且实心底色跟新的玻璃底栏冲突。
///
/// 这里合成一个：外观走 [GlassSurface]，跟底栏同一套配色规律。
/// 它盖在列表上方、内容从下面穿过，所以模糊是真能看出来的。
class GlassEditBar extends ConsumerWidget {
  const GlassEditBar({
    Key? key,
    required this.buttons,
    this.scrollable = false,
  }) : super(key: key);

  final List<Widget> buttons;

  /// 按钮多到放不下时横向滚动（任务页 7 个按钮），否则居中排列。
  final bool scrollable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget row = scrollable
        ? SingleChildScrollView(
            primary: true,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[const SizedBox(width: 15), ...buttons],
            ),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: buttons,
          );

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: GlassSurface(
            child: SizedBox(
              height: kBottomNavigationBarHeight,
              width: double.infinity,
              child: row,
            ),
          ),
        ),
      ),
    );
  }
}

/// 编辑栏里的单个操作按钮（图标 + 文字）。
///
/// 原来定义在 `task_page.dart` 里，env_page 为了用它去 import 整个 task_page。
class EditModeButton extends ConsumerWidget {
  final String title;
  final GestureTapCallback onTap;
  final IconData icon;

  const EditModeButton(
    this.title, {
    Key? key,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 玻璃背景上原来那个 unselectedLabelStyle 的灰色偏淡，
    // 统一改用正文色，保证在模糊过的花背景上也读得清。
    final Color color = ref.watch(themeProvider).themeColor.titleColor();

    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 15),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
