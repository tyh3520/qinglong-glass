import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qinglong_app/base/commit_button.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/button.dart';
import 'package:qinglong_app/base/ui/custom_bg.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/home/home_page.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/module/home/version_history_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../base/ql_app_bar.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  ConsumerState createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  @override
  Widget build(BuildContext context) {
    SystemBean? systemBean;

    try {
      systemBean = getIt<SystemBean>(
          instanceName:
              (SingleAccountPageState.of(context)?.index ?? 0).toString());
    } catch (e) {
      systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
    }

    return Scaffold(
      backgroundColor: CustomBg.pageBg(
        ref.watch(themeProvider).themeColor.bg2Color(),
      ),
      appBar: QlAppBar(
        title: "系统设置",
      ),
      body: SingleChildScrollView(
        primary: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Visibility(
              visible: Platform.isIOS ||
                  SpUtil.getInt(spVIP, defValue: typeNormal) != typeNormal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 30,
                    ),
                    child: Text(
                      "VIP功能",
                      style: TextStyle(
                        color: ref.watch(themeProvider).themeColor.descColor(),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 15,
                    ),
                    decoration: BoxDecoration(
                      color: ref
                          .watch(themeProvider)
                          .themeColor
                          .settingBordorColor(),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 3,
                            horizontal: 15,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.smiley,
                                color: ref.watch(themeProvider).primaryColor,
                                size: 20,
                              ),
                              const SizedBox(
                                width: 15,
                              ),
                              Text(
                                "使用Face ID解锁",
                                style: TextStyle(
                                  color: ref
                                      .watch(themeProvider)
                                      .themeColor
                                      .titleColor(),
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Transform.scale(
                                scale: 0.9,
                                child: CupertinoSwitch(
                                  activeColor:
                                      ref.watch(themeProvider).primaryColor,
                                  value: SpUtil.getBool(spOpenAuth,
                                      defValue: false),
                                  onChanged: (open) async {
                                    await SpUtil.putBool(spOpenAuth, open);
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                          indent: 55,
                          height: 1,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 3,
                            horizontal: 15,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.wand_stars_inverse,
                                color: ref.watch(themeProvider).primaryColor,
                                size: 20,
                              ),
                              const SizedBox(
                                width: 15,
                              ),
                              Text(
                                "单实例模式",
                                style: TextStyle(
                                  color: ref
                                      .watch(themeProvider)
                                      .themeColor
                                      .titleColor(),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    showCupertinoDialog(
                                      useRootNavigator: false,
                                      context: context,
                                      builder: (context1) =>
                                          CupertinoAlertDialog(
                                        content: const Text(
                                            "开启后可关闭多容器同时在线功能，减少APP对系统内存的消耗，通过长按首页 我的 切换账号"),
                                        title: const Text("温馨提示"),
                                        actions: [
                                          CupertinoDialogAction(
                                            child: Text(
                                              "确定",
                                              style: TextStyle(
                                                color: ref
                                                    .watch(themeProvider)
                                                    .primaryColor,
                                              ),
                                            ),
                                            onPressed: () {
                                              Navigator.of(context1).pop();
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    CupertinoIcons.question_circle,
                                    size: 16,
                                    color: Colors.grey,
                                  )),
                              const Spacer(),
                              Transform.scale(
                                scale: 0.9,
                                child: CupertinoSwitch(
                                  activeColor:
                                      ref.watch(themeProvider).primaryColor,
                                  value: SpUtil.getBool(spSingleInstance,
                                      defValue: false),
                                  onChanged: (open) async {
                                    SpUtil.putBool(spSingleInstance, open);
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                          indent: 55,
                          height: 1,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 3,
                            horizontal: 15,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.sun_max,
                                color: ref.watch(themeProvider).primaryColor,
                                size: 20,
                              ),
                              const SizedBox(
                                width: 15,
                              ),
                              Text(
                                "白色主题",
                                style: TextStyle(
                                  color: ref
                                      .watch(themeProvider)
                                      .themeColor
                                      .titleColor(),
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Transform.scale(
                                scale: 0.9,
                                child: CupertinoSwitch(
                                  activeColor:
                                      ref.watch(themeProvider).primaryColor,
                                  value: SpUtil.getInt(spThemeStyle,
                                          defValue: modeLight) ==
                                      modeWhite,
                                  onChanged: (open) async {
                                    SpUtil.putBool(spThemeFollowSystem, false);
                                    if (open) {
                                      ref
                                          .read(themeProvider.notifier)
                                          .changeTheme(modeWhite);
                                    } else {
                                      ref
                                          .read(themeProvider.notifier)
                                          .changeTheme(modeLight);
                                    }
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 30,
              ),
              child: Text(
                "通用功能",
                style: TextStyle(
                  color: ref.watch(themeProvider).themeColor.descColor(),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              decoration: BoxDecoration(
                color: ref.watch(themeProvider).themeColor.settingBordorColor(),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 15,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.doc_text,
                          color: ref.watch(themeProvider).primaryColor,
                          size: 20,
                        ),
                        const SizedBox(
                          width: 15,
                        ),
                        Text(
                          "任务自动弹出日志",
                          style: TextStyle(
                            color: ref
                                .watch(themeProvider)
                                .themeColor
                                .titleColor(),
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Transform.scale(
                          scale: 0.9,
                          child: CupertinoSwitch(
                            activeColor: ref.watch(themeProvider).primaryColor,
                            value:
                                SpUtil.getBool(spAutoShowLog, defValue: true),
                            onChanged: (open) async {
                              await SpUtil.putBool(spAutoShowLog, open);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    indent: 55,
                    height: 1,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 15,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.abc_sharp,
                          color: ref.watch(themeProvider).primaryColor,
                          size: 20,
                        ),
                        const SizedBox(
                          width: 15,
                        ),
                        Text(
                          "代码显示行号",
                          style: TextStyle(
                            color: ref
                                .watch(themeProvider)
                                .themeColor
                                .titleColor(),
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Transform.scale(
                          scale: 0.9,
                          child: CupertinoSwitch(
                            activeColor: ref.watch(themeProvider).primaryColor,
                            value: SpUtil.getBool(spShowLine, defValue: false),
                            onChanged: (open) async {
                              await SpUtil.putBool(spShowLine, open);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    indent: 55,
                    height: 1,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 15,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_down_doc,
                          color: ref.watch(themeProvider).primaryColor,
                          size: 20,
                        ),
                        const SizedBox(
                          width: 15,
                        ),
                        Text(
                          "日志内容自动滚动",
                          style: TextStyle(
                            color: ref
                                .watch(themeProvider)
                                .themeColor
                                .titleColor(),
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Transform.scale(
                          scale: 0.9,
                          child: CupertinoSwitch(
                            activeColor: ref.watch(themeProvider).primaryColor,
                            value: SpUtil.getBool(spLogAutoJump2Bottom,
                                defValue: false),
                            onChanged: (open) async {
                              await SpUtil.putBool(spLogAutoJump2Bottom, open);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    indent: 55,
                    height: 1,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 15,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.moon_circle,
                          color: ref.watch(themeProvider).primaryColor,
                          size: 20,
                        ),
                        const SizedBox(
                          width: 15,
                        ),
                        Text(
                          "黑色主题",
                          style: TextStyle(
                            color: ref
                                .watch(themeProvider)
                                .themeColor
                                .titleColor(),
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Transform.scale(
                          scale: 0.9,
                          child: CupertinoSwitch(
                            activeColor: ref.watch(themeProvider).primaryColor,
                            value: SpUtil.getInt(spThemeStyle,
                                    defValue: modeLight) ==
                                modeDark,
                            onChanged: (open) async {
                              SpUtil.putBool(spThemeFollowSystem, false);
                              if (open) {
                                ref
                                    .read(themeProvider.notifier)
                                    .changeTheme(modeDark);
                              } else {
                                ref
                                    .read(themeProvider.notifier)
                                    .changeTheme(modeLight);
                              }
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    indent: 55,
                    height: 1,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 15,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          SchedulerBinding.instance.window.platformBrightness ==
                                  Brightness.dark
                              ? CupertinoIcons.moon_circle
                              : CupertinoIcons.sun_max,
                          color: ref.watch(themeProvider).primaryColor,
                          size: 20,
                        ),
                        const SizedBox(
                          width: 15,
                        ),
                        Text(
                          "跟随系统",
                          style: TextStyle(
                            color: ref
                                .watch(themeProvider)
                                .themeColor
                                .titleColor(),
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Transform.scale(
                          scale: 0.9,
                          child: CupertinoSwitch(
                            activeColor: ref.watch(themeProvider).primaryColor,
                            value: SpUtil.getBool(spThemeFollowSystem,
                                defValue: false),
                            onChanged: (open) async {
                              SpUtil.putBool(spThemeFollowSystem, open);
                              ref
                                  .read(themeProvider.notifier)
                                  .changeThemeWithSystemStatus();
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    indent: 55,
                    height: 1,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 15,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.photo,
                          color: ref.watch(themeProvider).primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            "自定义背景图",
                            style: TextStyle(
                              color: ref
                                  .watch(themeProvider)
                                  .themeColor
                                  .titleColor(),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.9,
                          child: CupertinoSwitch(
                            activeColor: ref.watch(themeProvider).primaryColor,
                            value: CustomBg.enabled && CustomBg.path.isNotEmpty,
                            onChanged: (open) async {
                              if (open) {
                                final ok = await _pickCustomBackground();
                                if (!ok) return;
                                await CustomBg.setEnabled(true);
                              } else {
                                await CustomBg.setEnabled(false);
                              }
                              // 触发全 app builder 重建背景层
                              ref.read(themeProvider).refreshUi();
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (CustomBg.path.isNotEmpty) ...[
                    const Divider(
                      indent: 55,
                      height: 1,
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final ok = await _pickCustomBackground();
                        if (!ok) return;
                        await CustomBg.setEnabled(true);
                        ref.read(themeProvider).refreshUi();
                        setState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 15,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.folder,
                              color: ref.watch(themeProvider).primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                "更换背景图",
                                style: TextStyle(
                                  color: ref
                                      .watch(themeProvider)
                                      .themeColor
                                      .titleColor(),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Icon(
                              CupertinoIcons.right_chevron,
                              size: 16,
                              color: ref
                                  .watch(themeProvider)
                                  .themeColor
                                  .descColor(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(
                      indent: 55,
                      height: 1,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 8, 15, 4),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.circle_lefthalf_fill,
                            color: ref.watch(themeProvider).primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 15),
                          Text(
                            "背景遮罩",
                            style: TextStyle(
                              color: ref
                                  .watch(themeProvider)
                                  .themeColor
                                  .titleColor(),
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${(CustomBg.dim * 100).round()}%",
                            style: TextStyle(
                              color: ref
                                  .watch(themeProvider)
                                  .themeColor
                                  .descColor(),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(50, 0, 10, 8),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          min: 0.1,
                          max: 0.85,
                          divisions: 15,
                          activeColor: ref.watch(themeProvider).primaryColor,
                          value: CustomBg.dim.clamp(0.1, 0.85),
                          onChanged: (v) async {
                            await CustomBg.setDim(v);
                            ref.read(themeProvider).refreshUi();
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    const Divider(
                      indent: 55,
                      height: 1,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 8, 15, 4),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.drop,
                            color: ref.watch(themeProvider).primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 15),
                          Text(
                            "背景模糊",
                            style: TextStyle(
                              color: ref
                                  .watch(themeProvider)
                                  .themeColor
                                  .titleColor(),
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            CustomBg.blur <= 0
                                ? "关"
                                : "${(CustomBg.blur / 25 * 100).round()}%",
                            style: TextStyle(
                              color: ref
                                  .watch(themeProvider)
                                  .themeColor
                                  .descColor(),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(50, 0, 10, 8),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          min: 0,
                          max: 25,
                          divisions: 25,
                          activeColor: ref.watch(themeProvider).primaryColor,
                          value: CustomBg.blur.clamp(0.0, 25.0),
                          onChanged: (v) async {
                            await CustomBg.setBlur(v);
                            ref.read(themeProvider).refreshUi();
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    const Divider(
                      indent: 55,
                      height: 1,
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        await CustomBg.clear();
                        ref.read(themeProvider).refreshUi();
                        setState(() {});
                        "已清除自定义背景".toast();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 15,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.trash,
                              color: ref.watch(themeProvider).primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                "清除背景图",
                                style: TextStyle(
                                  color: ref
                                      .watch(themeProvider)
                                      .themeColor
                                      .titleColor(),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Visibility(
                    visible: !(systemBean.fromAutoGet ?? false),
                    child: const Divider(
                      indent: 55,
                      height: 1,
                    ),
                  ),
                  Visibility(
                    visible: !(systemBean.fromAutoGet ?? false),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _updateVersion(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 15,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.paperplane,
                              color: ref.watch(themeProvider).primaryColor,
                              size: 20,
                            ),
                            const SizedBox(
                              width: 15,
                            ),
                            Text(
                              "变更服务器版本号",
                              style: TextStyle(
                                color: ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .titleColor(),
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "(${systemBean.version})",
                              style: TextStyle(
                                color: ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .descColor(),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(
                              width: 5,
                            ),
                            Icon(
                              CupertinoIcons.right_chevron,
                              size: 16,
                              color: ref
                                  .watch(themeProvider)
                                  .themeColor
                                  .descColor(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 40,
                child: ButtonWidget(
                    title: "退出登录",
                    onTap: () {
                      showCupertinoDialog(
                        useRootNavigator: false,
                        context: context,
                        builder: (context1) => CupertinoAlertDialog(
                          title: const Text("确认退出登录吗?"),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text(
                                "取消",
                                style: TextStyle(
                                  color: Color(0xff999999),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context1).pop();
                              },
                            ),
                            CupertinoDialogAction(
                              child: Text(
                                "确定",
                                style: TextStyle(
                                  color: ref.watch(themeProvider).primaryColor,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context1).pop();
                                SingleAccountPageState.ofUserInfo(context)
                                    .updateToken(
                                  SingleAccountPageState.of(context)?.index ??
                                      0,
                                  SingleAccountPageState.ofUserInfo(context)
                                      .host,
                                  "",
                                  false,
                                  SingleAccountPageState.ofUserInfo(context)
                                      .alias,
                                );
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  Routes.routeLogin,
                                  (p) {
                                    return false;
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 40,
                child: ButtonWidget(
                    title: "退出登录并清空本地数据",
                    onTap: () {
                      showCupertinoDialog(
                        useRootNavigator: false,
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text("确认退出登录并清空账号本地数据吗?"),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text(
                                "取消",
                                style: TextStyle(
                                  color: Color(0xff999999),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            CupertinoDialogAction(
                              child: Text(
                                "确定",
                                style: TextStyle(
                                  color: ref.watch(themeProvider).primaryColor,
                                ),
                              ),
                              onPressed: () {
                                clearData(context);
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  Routes.routeLogin,
                                  (p) {
                                    return false;
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }),
              ),
            ),
            const SizedBox(
              height: 30,
            ),
          ],
        ),
      ),
    );
  }

  void clearData(BuildContext context) {
    getIt<MultiAccountUserInfoViewModel>()
        .removeHistoryAccount(SingleAccountPageState.ofUserInfo(context).host);
    SingleAccountPageState.ofUserInfo(context)
        .clearCurrentInfo(SingleAccountPageState.of(context)?.index ?? 0);
  }

  /// 选图并复制到 app 文档目录，避免系统临时路径失效
  Future<bool> _pickCustomBackground() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return false;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        "无法读取图片路径".toast();
        return false;
      }
      final src = File(path);
      if (!src.existsSync()) {
        "图片文件不存在".toast();
        return false;
      }
      final dir = await getApplicationDocumentsDirectory();
      final name = result.files.single.name;
      final ext = name.contains('.')
          ? name.split('.').last.toLowerCase()
          : 'jpg';
      final safeExt = (ext == 'png' ||
              ext == 'jpg' ||
              ext == 'jpeg' ||
              ext == 'webp' ||
              ext == 'gif')
          ? ext
          : 'jpg';
      // 用 token 做文件名，避免同路径覆盖后 Image 缓存不刷新
      final token = DateTime.now().millisecondsSinceEpoch;
      final dest = File('${dir.path}/custom_app_bg_${token}.$safeExt');
      await src.copy(dest.path);
      // 清理旧背景文件
      final old = CustomBg.path;
      await CustomBg.setPath(dest.path);
      await CustomBg.setEnabled(true);
      if (old.isNotEmpty && old != dest.path) {
        try {
          final f = File(old);
          if (f.existsSync()) await f.delete();
        } catch (_) {}
      }
      "背景图已设置（全 app 生效）".toast();
      return true;
    } catch (e) {
      "选择背景失败: $e".toast();
      return false;
    }
  }

  void _updateVersion(BuildContext context) async {
    String? host = SingleAccountPageState.ofUserInfo(context).host;

    TextEditingController controller = TextEditingController(
        text: getIt<SystemBean>(
                instanceName:
                    (SingleAccountPageState.of(context)?.index ?? 0).toString())
            .version);
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("请输入版本号:"),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10,
              ),
              child: TextField(
                textAlign: TextAlign.center,
                controller: controller,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: "请输入版本号",
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ref.watch(themeProvider).themeColor.title2Color(),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ref.watch(themeProvider).themeColor.title2Color(),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text(
              "取消",
              style: TextStyle(
                color: Color(0xff999999),
              ),
            ),
            onPressed: () {
              Navigator.of(context1).pop();
            },
          ),
          CupertinoDialogAction(
            child: Text(
              "确定",
              style: TextStyle(
                color: ref.watch(themeProvider).primaryColor,
              ),
            ),
            onPressed: () async {
              Navigator.of(context1).pop();
              HomePageState.updateVersionHistory(VersionHistoryBean(
                  host: host, version: controller.text.trim()));
              SingleAccountPageState.of(context)
                  ?.registerSystemBean(controller.text.trim(), false);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  void commitLogDel(int time) async {
    var response = await SingleAccountPageState.ofApi(context).logDelTime(time);
    if (response.success) {
      "修改成功".toast();
    } else {
      response.message.toast();
    }
  }
}
