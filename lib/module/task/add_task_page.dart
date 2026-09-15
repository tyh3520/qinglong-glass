import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/commit_button.dart';
import 'package:path/path.dart' as p;
import 'package:qinglong_app/base/cron_parse.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/upload_script_widget.dart';
import 'package:qinglong_app/module/others/scripts/script_upload_page.dart';
import 'package:qinglong_app/module/subscribe/add_subscribe_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/config_detail_page.dart';

class AddTaskPage extends ConsumerStatefulWidget {
  final TaskBean? taskBean;
  final bool hideUploadFile;

  const AddTaskPage({
    Key? key,
    this.taskBean,
    required this.hideUploadFile,
  }) : super(key: key);

  @override
  ConsumerState<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends ConsumerState<AddTaskPage> with LazyLoadState<AddTaskPage> {
  late TaskBean taskBean;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();

  /// 多条定时规则：第 1 条提交为 schedule，其余提交为 extra_schedules（对齐青龙网页版「新增定时规则」）
  final List<TextEditingController> _cronControllers = [];
  final List<FocusNode> _cronFocusNodes = [];

  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.taskBean != null) {
      taskBean = widget.taskBean!;
      _nameController.text = taskBean.name ?? "";
      _commandController.text = taskBean.command ?? "";
      _fillCronRules(taskBean.allSchedules.join("\n"));
    } else {
      taskBean = TaskBean();
      _fillCronRules("");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QlAppBar(
        canBack: true,
        actions: [
          CommitButton(
            onTap: () {
              submit();
            },
          ),
        ],
        title: (taskBean.sId == null || taskBean.sId!.isEmpty) ? "新增任务" : "编辑任务",
      ),
      body: SingleChildScrollView(
        primary: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  const TitleWidget(
                    "名称",
                    required: true,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  TextField(
                    focusNode: focusNode,
                    controller: _nameController,
                    maxLines: 3,
                    minLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      hintText: "请输入名称",
                    ),
                    autofocus: false,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  const TitleWidget(
                    "命令",
                    required: true,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  TextField(
                    controller: _commandController,
                    maxLines: 4,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: "请输入命令",
                    ),
                    autofocus: false,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  const TitleWidget(
                    "定时规则",
                    required: true,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  ...List.generate(_cronControllers.length, (index) => _buildCronRuleRow(index)),
                  GestureDetector(
                    onTap: _addCronRule,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            size: 16,
                            color: ref.watch(themeProvider).primaryColor,
                          ),
                          const SizedBox(
                            width: 4,
                          ),
                          Text(
                            "新增定时规则",
                            style: TextStyle(
                              fontSize: 13,
                              color: ref.watch(themeProvider).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    _cronControllers.length > 1
                        ? "已添加 ${_cronControllers.length} 条规则，满足任意一条即会运行"
                        : "可添加多条规则，满足任意一条即会运行",
                    style: TextStyle(
                      fontSize: 12,
                      color: ref.watch(themeProvider).themeColor.descColor(),
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  Visibility(
                    visible: !widget.hideUploadFile,
                    child: UploadScriptWidget(
                      key: fileKey,
                      nameCallBack: (name) async {
                        _nameController.text = name ?? "";
                        if (name == null || name.isEmpty) {
                          _commandController.text = "";
                          setState(() {
                            _fillCronRules("");
                          });
                        } else {
                          String command =
                              "task ${fileKey.currentState?.scriptPath}${(fileKey.currentState != null && fileKey.currentState!.scriptPath.isNotEmpty) ? p.separator : ""}${fileKey.currentState?.getFileName()}";

                          _commandController.text = command;

                          String data = await fileKey.currentState?.file?.readAsString() ?? "";

                          String schedule = ScriptUploadPageState.getCronString(data, name) ?? "";

                          setState(() {
                            _fillCronRules(schedule);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单条定时规则的输入行，右侧为「测试」与「删除」
  Widget _buildCronRuleRow(int index) {
    final bool canRemove = _cronControllers.length > 1;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _cronControllers[index],
              focusNode: _cronFocusNodes[index],
              minLines: 1,
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                hintText: "秒(可选) 分	时 天 月 周",
              ),
              autofocus: false,
            ),
          ),
          GestureDetector(
            onTap: () {
              _openCronTest(index);
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              child: Text(
                "在线测试",
                style: TextStyle(
                  fontSize: 12,
                  color: ref.watch(themeProvider).primaryColor,
                ),
              ),
            ),
          ),
          Visibility(
            visible: canRemove,
            child: GestureDetector(
              onTap: () {
                _removeCronRule(index);
              },
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 10,
                ),
                child: Icon(
                  Icons.remove_circle_outline,
                  size: 20,
                  color: Color(0xffFB5858),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 用给定的（可能多行的）定时规则重建输入行
  void _fillCronRules(String schedule) {
    final List<TextEditingController> oldControllers = List.of(_cronControllers);
    final List<FocusNode> oldFocusNodes = List.of(_cronFocusNodes);

    _cronControllers.clear();
    _cronFocusNodes.clear();

    final List<String> rules = schedule
        .split(RegExp(r"[\r\n]+"))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (rules.isEmpty) {
      rules.add("");
    }

    for (final String rule in rules) {
      _cronControllers.add(TextEditingController(text: rule));
      _cronFocusNodes.add(FocusNode());
    }

    _disposeLater(oldControllers, oldFocusNodes);
  }

  void _addCronRule() {
    setState(() {
      _cronControllers.add(TextEditingController());
      _cronFocusNodes.add(FocusNode());
    });
  }

  void _removeCronRule(int index) {
    if (_cronControllers.length <= 1) return;
    if (index < 0 || index >= _cronControllers.length) return;

    final TextEditingController controller = _cronControllers.removeAt(index);
    final FocusNode node = _cronFocusNodes.removeAt(index);
    setState(() {});
    _disposeLater([controller], [node]);
  }

  /// 延后到本帧绘制完成后再释放：此时对应的输入框已经和这两个对象解绑，
  /// 不会出现「控件还持有已销毁的 controller / focusNode」的情况。
  void _disposeLater(List<TextEditingController> controllers, List<FocusNode> nodes) {
    if (controllers.isEmpty && nodes.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      for (final controller in controllers) {
        controller.dispose();
      }
      for (final node in nodes) {
        node.dispose();
      }
    });
  }

  /// 去掉空行后的所有定时规则，第 1 条为主规则
  List<String> get _cronRules => _cronControllers
      .map((e) => e.text.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _openCronTest(int index) {
    if (index < 0 || index >= _cronControllers.length) return;

    String rule = _cronControllers[index].text.trim();
    if (rule.isEmpty) {
      "定时规则不能为空".toast();
      return;
    }

    String? error = validateCronRule(rule);
    if (error != null) {
      error.toast();
      return;
    }

    // crontab.guru 只支持 5 段写法，青龙的 6 段规则（带秒）去掉秒再测
    List<String> parts = rule.split(RegExp(r"\s+"));
    if (parts.length == 6) {
      rule = parts.sublist(1).join(" ");
    }

    try {
      String cron = rule.replaceAll(RegExp(r"\s+"), "_");
      launchUrl(Uri.tryParse("https://crontab.guru/#$cron")!);
    } catch (e) {}
  }

  GlobalKey<UploadScriptWidgetState> fileKey = GlobalKey();

  void submit() async {
    if (_nameController.text.isEmpty) {
      "任务名称不能为空".toast();
      return;
    }
    if (_commandController.text.isEmpty) {
      "命令不能为空".toast();
      return;
    }

    List<String> rules = _cronRules;
    if (rules.isEmpty) {
      "定时规则不能为空".toast();
      return;
    }

    for (final String rule in rules) {
      String? error = validateCronRule(rule);
      if (error != null) {
        "定时规则「$rule」$error".toast();
        return;
      }
    }

    commitReal();
  }

  void commitReal() async {
    try {
      hideKeyboardFocus();
      if (fileKey.currentState != null && fileKey.currentState!.file != null) {
        String content = await fileKey.currentState!.file!.readAsString();
        HttpResponse<NullResponse> responseS = await SingleAccountPageState.ofApi(context).addScript(
          fileKey.currentState?.getFileName() ?? _commandController.text.split(" ").last,
          fileKey.currentState?.scriptPath ?? "",
          content,
        );
        if (!responseS.success) {
          responseS.message.toast();
          return;
        }
      }

      List<String> rules = _cronRules;
      String mainCron = rules.first;
      List<String> extraCrons = rules.length > 1 ? rules.sublist(1) : <String>[];

      // 老版本青龙不支持 extra_schedules，只有确实存在（或原本就存在）附加规则时才下发该字段；
      // 原来有多条规则、现在删光了，需要下发空数组才能清空。
      bool hadExtraRules = widget.taskBean?.extraSchedules?.isNotEmpty ?? false;
      List<String>? extraCronsParam = (extraCrons.isEmpty && !hadExtraRules) ? null : extraCrons;

      taskBean.name = _nameController.text;
      taskBean.command = _commandController.text.trim();
      taskBean.schedule = mainCron;
      taskBean.extraSchedules = extraCrons.map((e) => ExtraSchedule(schedule: e)).toList();

      await EasyLoading.show(status: " 提交中");
      HttpResponse<NullResponse> response = await SingleAccountPageState.ofApi(context).addTask(
        _nameController.text,
        _commandController.text.trim(),
        mainCron,
        id: taskBean.id,
        nId: taskBean.nId,
        extraCrons: extraCronsParam,
      );
      await EasyLoading.dismiss();
      if (response.success) {
        (widget.taskBean?.sId == null) ? "新增成功" : "修改成功".toast();
        ref.read(SingleAccountPageState.ofTaskProvider(context)(getProviderName(context))).updateBean(context, taskBean);
        Navigator.of(context).pop();
      } else {
        response.message.toast();
      }
    } catch (e) {
      e.toString().toast();
      EasyLoading.dismiss();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    for (final controller in _cronControllers) {
      controller.dispose();
    }
    for (final node in _cronFocusNodes) {
      node.dispose();
    }
    focusNode.dispose();
    super.dispose();
  }

  @override
  void onLazyLoad() {
    if (widget.hideUploadFile) {
      focusNode.requestFocus();
    }
  }
}
