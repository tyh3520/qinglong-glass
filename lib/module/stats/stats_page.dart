import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/module/stats/stats_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/utils.dart';

/// 对齐青龙网页版仪表盘（2.21.0+ /api/dashboard/*）
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  StatsPageState createState() => StatsPageState();
}

class StatsPageState extends ConsumerState<StatsPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey();

  bool loading = true;
  bool unsupported = false;
  String? error;

  DashboardOverview overview = DashboardOverview();
  List<TrendPoint> trend = <TrendPoint>[];
  RuntimeOverview runtime = RuntimeOverview();
  List<RankItem> topTime = <RankItem>[];
  List<RankItem> topCount = <RankItem>[];
  List<LabelStatItem> labels = <LabelStatItem>[];
  DashboardSystemInfo? system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (int i = 0; i < 8; i++) {
        if (_trySystemBean() != null) break;
        await Future.delayed(const Duration(milliseconds: 150));
      }
      if (mounted) {
        await loadData(showLoading: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  Future<void> move2Top() async {
    if (_scrollController.hasClients &&
        _scrollController.offset != _scrollController.position.minScrollExtent) {
      await scrollToTop();
    } else if (refreshKey.currentState?.mounted ?? false) {
      await refreshKey.currentState?.show();
    } else {
      await loadData(showLoading: false);
    }
  }

  SystemBean? _trySystemBean() {
    try {
      return getIt<SystemBean>(instanceName: getProviderName(context));
    } catch (_) {
      return null;
    }
  }

  /// 低版本青龙没有 /api/dashboard/* 时，常见 html 404 / 非 json 体，
  /// http 层会落到 message=json解析失败、code=-1000。
  bool _isDashboardUnsupportedResp(HttpResponse resp) {
    final msg = (resp.message ?? '').toLowerCase();
    final code = resp.code;
    if (code == 404 || code == -1000) return true;
    return msg.contains('not found') ||
        msg.contains('404') ||
        msg.contains('cannot get') ||
        msg.contains('json解析失败') ||
        msg.contains('json') && msg.contains('parse') ||
        msg.contains('unexpected token') ||
        msg.contains('syntaxerror') ||
        msg.contains('no such file') ||
        msg.contains('cannot find');
  }

  Future<void> loadData({bool showLoading = false}) async {
    if (!mounted) return;

    final systemBean = _trySystemBean();
    // 明确低于 2.21.0：直接友好提示，不打 dashboard 接口
    if (systemBean != null && !systemBean.isUpperVersion2_21_0()) {
      setState(() {
        unsupported = true;
        loading = false;
        error = null;
      });
      return;
    }

    if (showLoading) {
      setState(() {
        loading = true;
        error = null;
        unsupported = false;
      });
    }

    try {
      final api = SingleAccountPageState.ofApi(context);
      final overviewResp = await api.dashboardOverview();

      // 版本号偶发拿不到 / 判断失败时，用 overview 探测是否支持仪表盘
      if (!overviewResp.success && _isDashboardUnsupportedResp(overviewResp)) {
        if (!mounted) return;
        setState(() {
          unsupported = true;
          loading = false;
          error = null;
        });
        return;
      }

      final trendResp = await api.dashboardTrend(days: 7);
      final runtimeResp = await api.dashboardRuntime();
      final topTimeResp = await api.dashboardTopTime();
      final topCountResp = await api.dashboardTopCount();
      final systemResp = await api.dashboardSystem();
      final labelsResp = await api.dashboardLabels();

      if (!overviewResp.success) {
        if (_isDashboardUnsupportedResp(overviewResp)) {
          if (!mounted) return;
          setState(() {
            unsupported = true;
            loading = false;
            error = null;
          });
          return;
        }
      }

      final nextOverview = overviewResp.bean ?? DashboardOverview();
      final nextRuntime = runtimeResp.bean ?? RuntimeOverview();
      nextOverview.runningCount = nextRuntime.runningCount;

      if (!mounted) return;
      setState(() {
        overview = nextOverview;
        runtime = nextRuntime;
        trend = _parseTrend(trendResp);
        topTime = _parseRank(topTimeResp);
        topCount = _parseRank(topCountResp);
        labels = _parseLabels(labelsResp);
        system = systemResp.success ? systemResp.bean : null;
        loading = false;
        error = overviewResp.success ? null : (overviewResp.message ?? '加载失败');
        unsupported = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final lookLikeUnsupported = msg.contains('json') ||
          msg.contains('404') ||
          msg.contains('not found') ||
          msg.contains('format');
      setState(() {
        loading = false;
        if (lookLikeUnsupported) {
          unsupported = true;
          error = null;
        } else {
          error = e.toString();
        }
      });
    }
  }

  List<TrendPoint> _parseTrend(HttpResponse<String> resp) {
    if (!resp.success || resp.bean == null) return <TrendPoint>[];
    return parseTrendList(resp.bean);
  }

  List<RankItem> _parseRank(HttpResponse<String> resp) {
    if (!resp.success || resp.bean == null) return <RankItem>[];
    return parseRankList(resp.bean);
  }

  List<LabelStatItem> _parseLabels(HttpResponse<String> resp) {
    if (!resp.success || resp.bean == null) return <LabelStatItem>[];
    return parseLabelList(resp.bean);
  }

  Future<void> stopRunning(RunningInstanceItem item) async {
    final id = item.id;
    if (id == null) {
      "无法停止：缺少任务 id".toast();
      return;
    }
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('停止任务'),
        content: Text('确定停止「${item.name}」？'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消', style: TextStyle(color: Color(0xff999999))),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CupertinoDialogAction(
            child: Text('停止', style: TextStyle(color: ref.read(themeProvider).primaryColor)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final resp = await SingleAccountPageState.ofApi(context).stopTasks([id.toString()]);
    if (resp.success) {
      "已发送停止请求".toast();
      await loadData(showLoading: false);
    } else {
      (resp.message ?? '停止失败').toast();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: theme.themeColor.bg2Color(),
      appBar: QlAppBar(
        title: '仪表盘',
        canBack: false,
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minSize: 0,
            onPressed: () => loadData(showLoading: true),
            child: Icon(CupertinoIcons.refresh, size: 20, color: theme.primaryColor),
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeViewModel theme) {
    if (loading) {
      return const Center(child: LoadingWidget());
    }
    if (unsupported) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.chart_bar, size: 42, color: theme.themeColor.descColor()),
              const SizedBox(height: 12),
              Text(
                '仪表盘暂不可用',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.themeColor.titleColor(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '需要青龙 2.21.0 及以上版本\n（/api/dashboard 系列接口）',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.themeColor.descColor(), height: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, style: TextStyle(color: theme.themeColor.descColor())),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: () => loadData(showLoading: true),
              child: Text('重试', style: TextStyle(color: theme.primaryColor)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      key: refreshKey,
      color: theme.primaryColor,
      onRefresh: () => loadData(showLoading: false),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          24 + MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight,
        ),
        children: [
          _overviewGrid(theme),
          const SizedBox(height: 12),
          _sectionCard(
            theme,
            title: '近 7 日趋势',
            child: trend.isEmpty
                ? _emptyLine(theme, '暂无数据')
                : _TrendArea(points: trend, theme: theme),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            theme,
            title: '今日耗时 Top 5',
            child: topTime.isEmpty
                ? _emptyLine(theme, '暂无数据')
                : _topTimeTable(theme, topTime.take(5).toList()),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            theme,
            title: '今日执行次数 Top 5',
            child: topCount.isEmpty
                ? _emptyLine(theme, '暂无数据')
                : _topCountTable(theme, topCount.take(5).toList()),
          ),
          if (labels.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionCard(
              theme,
              title: '标签统计',
              child: _labelsTable(theme, labels),
            ),
          ],
          const SizedBox(height: 12),
          _sectionCard(
            theme,
            title: '实时运行态',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _miniTag(theme, '运行中 ${runtime.runningCount}', const Color(0xff1677ff)),
                const SizedBox(width: 6),
                // 对齐网页文案：排队中
                _miniTag(theme, '排队中 ${runtime.queuedCount}', const Color(0xfffa8c16)),
              ],
            ),
            // 对齐网页 Table：定时任务 / PID / 已运行 / 停止
            child: _runtimeBlock(theme),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            theme,
            title: '系统资源',
            child: system == null
                ? _emptyLine(theme, '暂无系统信息')
                : _systemBlock(theme, system!),
          ),
        ],
      ),
    );
  }

  Widget _overviewGrid(ThemeViewModel theme) {
    final items = <_Metric>[
      _Metric('总任务', '${overview.total}', null),
      _Metric('已启用', '${overview.enabled}', const Color(0xff1677ff)),
      _Metric('今日执行', '${overview.todayRuns}', const Color(0xff1677ff)),
      _Metric('成功率', '${overview.successRate}%', const Color(0xff52c41a)),
      _Metric('今日成功', '${overview.todaySuccess}', const Color(0xff52c41a)),
      _Metric('今日失败', '${overview.todayFail}', const Color(0xffff4d4f)),
      _Metric(
        '平均耗时',
        overview.avgTime > 0 ? _fmtMs(overview.avgTime) : '-',
        null,
      ),
      _Metric('已禁用', '${overview.disabled}', null),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((m) {
            return SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.themeColor.settingBgColor(),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.themeColor.settingBordorColor()),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.label,
                      style: TextStyle(fontSize: 12, color: theme.themeColor.descColor()),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: m.color ?? theme.themeColor.titleColor(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// 对齐网页「实时运行态」Table：
  /// 运行中：定时任务 / PID / 已运行 / 停止
  /// 24h 未运行：任务名 / lastRun（无表头）
  Widget _runtimeBlock(ThemeViewModel theme) {
    // 手机宽度有限：名称列弹性，PID / 已运行 / 操作列固定
    const widths = <double?>[null, 56.0, 72.0, 44.0];
    final running = runtime.running;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (running.isEmpty)
          _emptyLine(theme, '暂无运行中任务')
        else ...[
          _tableHeader(theme, const ['定时任务', 'PID', '已运行', '操作'], widths),
          Divider(height: 12, thickness: 0.5, color: theme.themeColor.settingBordorColor()),
          ...List.generate(running.length, (i) {
            final item = running[i];
            final same = running.where((r) => r.id == item.id).length;
            return _runtimeRunningRow(
              theme,
              item: item,
              sameCount: same,
              widths: widths,
              zebra: i.isOdd,
            );
          }),
        ],
        if (runtime.idleTasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '24小时未运行 (${runtime.idleTasks.length})',
            style: const TextStyle(fontSize: 13, color: Color(0xffff7a00)),
          ),
          const SizedBox(height: 6),
          // 网页 idle 表 showHeader=false：任务名 + lastRun
          ...List.generate(runtime.idleTasks.length, (i) {
            final e = runtime.idleTasks[i];
            return _tableRow(
              theme,
              cells: [e.name, e.lastRun],
              widths: const [null, 110.0],
              emphasize: 0,
              zebra: i.isOdd,
            );
          }),
        ],
      ],
    );
  }

  Widget _runtimeRunningRow(
    ThemeViewModel theme, {
    required RunningInstanceItem item,
    required int sameCount,
    required List<double?> widths,
    bool zebra = false,
  }) {
    final nameStyle = TextStyle(
      fontSize: 13,
      height: 1.25,
      color: theme.themeColor.titleColor(),
    );
    final cellStyle = TextStyle(
      fontSize: 12,
      height: 1.25,
      color: theme.themeColor.titleColor(),
    );

    final nameCell = Row(
      children: [
        Flexible(
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        ),
        if (sameCount > 1) ...[
          const SizedBox(width: 4),
          _miniTag(theme, '×$sameCount', const Color(0xff1677ff)),
        ],
      ],
    );

    final row = Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: nameCell,
          ),
        ),
        SizedBox(
          width: widths[1],
          child: Text(
            '${item.pid ?? '-'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: cellStyle,
          ),
        ),
        SizedBox(
          width: widths[2],
          child: Text(
            _fmtSec(item.elapsed),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: cellStyle,
          ),
        ),
        SizedBox(
          width: widths[3],
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => stopRunning(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '停止',
                  style: TextStyle(fontSize: 12, color: theme.primaryColor),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: zebra ? theme.themeColor.settingBordorColor().withOpacity(0.18) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: row,
    );
  }

  Widget _systemBlock(ThemeViewModel theme, DashboardSystemInfo s) {
    final mem = double.tryParse(s.memUsagePercent) ?? 0;
    final load0 = s.loadAvg.isNotEmpty ? s.loadAvg[0].toStringAsFixed(2) : '-';
    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: _GaugePainter(
              percent: mem.clamp(0, 100) / 100.0,
              color: theme.primaryColor,
              track: theme.themeColor.bg2Color(),
              textColor: theme.themeColor.titleColor(),
              label: '内存 ${s.memUsagePercent}%',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv(theme, '系统运行', _fmtSec(s.uptime)),
              const SizedBox(height: 6),
              _kv(theme, '堆内存', '${s.heapUsed} MB'),
              const SizedBox(height: 6),
              Text(
                '负载 1m: $load0 · CPU ${s.cpus} 核 · ${s.platform}',
                style: TextStyle(fontSize: 12, color: theme.themeColor.descColor(), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(ThemeViewModel theme, String k, String v) {
    return Row(
      children: [
        Text(k, style: TextStyle(fontSize: 12, color: theme.themeColor.descColor())),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.themeColor.titleColor(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(
    ThemeViewModel theme, {
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.themeColor.settingBgColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.themeColor.settingBordorColor()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.themeColor.descColor(),
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  /// 对齐网页版 Table：# / 定时任务 / 平均耗时 / 最长单次
  Widget _topTimeTable(ThemeViewModel theme, List<RankItem> items) {
    // 手机宽：数值列固定右对齐，名称列取剩余宽度（类 antd small table）
    const widths = <double?>[32.0, null, 72.0, 72.0];
    return Column(
      children: [
        _tableHeader(theme, const ['#', '定时任务', '平均耗时', '最长单次'], widths),
        Divider(height: 12, thickness: 0.5, color: theme.themeColor.settingBordorColor()),
        ...List.generate(items.length, (i) {
          final e = items[i];
          final rank = e.rank > 0 ? e.rank : i + 1;
          return _tableRow(
            theme,
            cells: [
              '$rank',
              e.name,
              e.avgTime > 0 ? _fmtMs(e.avgTime) : '-',
              e.maxTime > 0 ? _fmtMs(e.maxTime) : '-',
            ],
            widths: widths,
            emphasize: 1,
            zebra: i.isOdd,
          );
        }),
      ],
    );
  }

  /// 对齐网页版 Table：# / 定时任务 / 次数 / 平均耗时 / 成功率
  Widget _topCountTable(ThemeViewModel theme, List<RankItem> items) {
    const widths = <double?>[32.0, null, 40.0, 68.0, 54.0];
    return Column(
      children: [
        _tableHeader(theme, const ['#', '定时任务', '次数', '平均耗时', '成功率'], widths),
        Divider(height: 12, thickness: 0.5, color: theme.themeColor.settingBordorColor()),
        ...List.generate(items.length, (i) {
          final e = items[i];
          final rank = e.rank > 0 ? e.rank : i + 1;
          return _tableRow(
            theme,
            cells: [
              '$rank',
              e.name,
              '${e.runCount}',
              e.avgTime > 0 ? _fmtMs(e.avgTime) : '-',
              '${e.successRate}%',
            ],
            widths: widths,
            emphasize: 1,
            zebra: i.isOdd,
          );
        }),
      ],
    );
  }

  /// 对齐网页版标签统计表：标签 / 任务数 / 今日执行 / 成功率 / 平均耗时
  Widget _labelsTable(ThemeViewModel theme, List<LabelStatItem> items) {
    return Column(
      children: [
        _tableHeader(theme, const ['标签', '任务数', '今日执行', '成功率', '平均耗时'], const [null, 52.0, 64.0, 58.0, 72.0]),
        const SizedBox(height: 6),
        ...items.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        e.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: theme.primaryColor),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${e.count}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: theme.themeColor.titleColor()),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${e.todayRuns}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: theme.themeColor.titleColor()),
                  ),
                ),
                SizedBox(
                  width: 58,
                  child: Text(
                    '${e.successRate}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: theme.themeColor.titleColor()),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    e.avgTime > 0 ? _fmtMs(e.avgTime) : '-',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: theme.themeColor.descColor()),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _tableHeader(ThemeViewModel theme, List<String> titles, List<double?> widths) {
    return Row(
      children: List.generate(titles.length, (i) {
        final w = widths[i];
        final isFirst = i == 0;
        final isFlex = w == null;
        final align = isFlex || isFirst ? TextAlign.left : TextAlign.right;
        final child = Text(
          titles[i],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: theme.themeColor.descColor(),
          ),
        );
        if (isFlex) {
          return Expanded(child: child);
        }
        return SizedBox(
          width: w,
          child: isFirst ? child : Align(alignment: Alignment.centerRight, child: child),
        );
      }),
    );
  }

  Widget _tableRow(
    ThemeViewModel theme, {
    required List<String> cells,
    required List<double?> widths,
    int emphasize = -1,
    bool zebra = false,
  }) {
    final row = Row(
      children: List.generate(cells.length, (i) {
        final w = widths[i];
        final isName = i == emphasize;
        final isFirst = i == 0;
        final isFlex = w == null;
        final align = isFlex || isFirst || isName ? TextAlign.left : TextAlign.right;
        final child = Text(
          cells[i],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
            fontSize: isName ? 13 : 12,
            height: 1.25,
            color: isName
                ? theme.themeColor.titleColor()
                : (isFirst ? theme.themeColor.descColor() : theme.themeColor.titleColor()),
          ),
        );
        if (isFlex) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: child,
            ),
          );
        }
        return SizedBox(
          width: w,
          child: isFirst || isName
              ? child
              : Align(alignment: Alignment.centerRight, child: child),
        );
      }),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: zebra ? theme.themeColor.settingBordorColor().withOpacity(0.18) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: row,
    );
  }

  Widget _miniTag(ThemeViewModel theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _emptyLine(ThemeViewModel theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(text, style: TextStyle(color: theme.themeColor.descColor(), fontSize: 13)),
      ),
    );
  }

  String _fmtMs(int ms) {
    if (ms <= 0) return '-';
    final s = ms / 1000.0;
    if (s < 60) return '${s.toStringAsFixed(1)}s';
    final m = (s / 60).floor();
    final rem = (s % 60).round();
    return '${m}m ${rem}s';
  }

  String _fmtSec(int s) {
    if (s <= 0) return '-';
    if (s < 60) return '${s}s';
    if (s < 3600) return '${s ~/ 60}m ${s % 60}s';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
}

class _Metric {
  final String label;
  final String value;
  final Color? color;
  _Metric(this.label, this.value, this.color);
}

class _TrendArea extends StatelessWidget {
  final List<TrendPoint> points;
  final ThemeViewModel theme;

  const _TrendArea({required this.points, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            _LegendDot(color: Color(0xff1677ff), label: '总执行'),
            SizedBox(width: 12),
            _LegendDot(color: Color(0xff52c41a), label: '成功'),
            SizedBox(width: 12),
            _LegendDot(color: Color(0xffff4d4f), label: '失败'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          // 网页 Area 高 260；手机稍低，但留足够 y 轴刻度空间
          height: 220,
          width: double.infinity,
          child: CustomPaint(
            painter: _TrendPainter(
              points: points,
              totalColor: const Color(0xff1677ff),
              successColor: const Color(0xff52c41a),
              failColor: const Color(0xffff4d4f),
              gridColor: theme.themeColor.settingBordorColor(),
              labelColor: theme.themeColor.descColor(),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> points;
  final Color totalColor;
  final Color successColor;
  final Color failColor;
  final Color gridColor;
  final Color labelColor;

  _TrendPainter({
    required this.points,
    required this.totalColor,
    required this.successColor,
    required this.failColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 预先计算 y 轴刻度，再决定左侧留白（对齐网页 Area yAxis label）
    final rawMax = points
        .map((e) => math.max(e.total, math.max(e.success, e.fail)))
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = _niceMax(rawMax <= 0 ? 1 : rawMax).toDouble();
    const yTicks = 4; // 0..max 共 5 根网格线

    final yLabels = <String>[];
    for (int i = 0; i <= yTicks; i++) {
      final v = maxY * (yTicks - i) / yTicks;
      yLabels.add(_fmtY(v));
    }
    final measure = TextPainter(textDirection: TextDirection.ltr);
    double maxLabelW = 0;
    for (final t in yLabels) {
      measure.text = TextSpan(text: t, style: TextStyle(fontSize: 10, color: labelColor));
      measure.layout();
      if (measure.width > maxLabelW) maxLabelW = measure.width;
    }

    final left = math.max(28.0, maxLabelW + 10);
    const right = 8.0;
    const bottom = 24.0;
    const top = 10.0;
    final chartW = size.width - left - right;
    final chartH = size.height - bottom - top;
    if (chartW <= 0 || chartH <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.85)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // y 轴网格 + 刻度数字
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= yTicks; i++) {
      final y = top + chartH * i / yTicks;
      canvas.drawLine(Offset(left, y), Offset(left + chartW, y), gridPaint);
      final text = yLabels[i];
      tp.text = TextSpan(text: text, style: TextStyle(fontSize: 10, color: labelColor));
      tp.layout();
      tp.paint(canvas, Offset(left - 6 - tp.width, y - tp.height / 2));
    }

    // y 轴 / x 轴 基线
    canvas.drawLine(Offset(left, top), Offset(left, top + chartH), axisPaint);
    canvas.drawLine(Offset(left, top + chartH), Offset(left + chartW, top + chartH), axisPaint);

    Path buildPath(List<double> ys) {
      final path = Path();
      for (int i = 0; i < ys.length; i++) {
        final x = left + (ys.length == 1 ? chartW / 2 : chartW * i / (ys.length - 1));
        final y = top + chartH * (1 - (ys[i] / maxY).clamp(0.0, 1.0));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          // 简单平滑：中点二次贝塞尔（接近网页 smooth area）
          final prevX = left + (ys.length == 1 ? chartW / 2 : chartW * (i - 1) / (ys.length - 1));
          final prevY = top + chartH * (1 - (ys[i - 1] / maxY).clamp(0.0, 1.0));
          final cx = (prevX + x) / 2;
          path.cubicTo(cx, prevY, cx, y, x, y);
        }
      }
      return path;
    }

    void drawSeries(List<double> ys, Color color) {
      if (ys.isEmpty) return;
      final line = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = buildPath(ys);
      // soft area under curve
      final lastX = left + (ys.length == 1 ? chartW / 2 : chartW);
      final area = Path.from(path)
        ..lineTo(lastX, top + chartH)
        ..lineTo(left, top + chartH)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withOpacity(0.12));
      canvas.drawPath(path, line);

      // 端点小圆点，更像 antd plots
      final dotFill = Paint()..color = color;
      final dotBorder = Paint()
        ..color = const Color(0xffffffff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (int i = 0; i < ys.length; i++) {
        final x = left + (ys.length == 1 ? chartW / 2 : chartW * i / (ys.length - 1));
        final y = top + chartH * (1 - (ys[i] / maxY).clamp(0.0, 1.0));
        canvas.drawCircle(Offset(x, y), 2.6, dotFill);
        canvas.drawCircle(Offset(x, y), 2.6, dotBorder);
      }
    }

    drawSeries(points.map((e) => e.total.toDouble()).toList(), totalColor);
    drawSeries(points.map((e) => e.success.toDouble()).toList(), successColor);
    drawSeries(points.map((e) => e.fail.toDouble()).toList(), failColor);

    // x 轴日期
    for (int i = 0; i < points.length; i++) {
      final x = left + (points.length == 1 ? chartW / 2 : chartW * i / (points.length - 1));
      final raw = points[i].date;
      // 网页 xField 用原始 date；手机窄展示 MM-DD
      final label = raw.length >= 10
          ? raw.substring(5, 10)
          : (raw.length >= 5 ? raw.substring(raw.length - 5) : raw);
      tp.text = TextSpan(text: label, style: TextStyle(fontSize: 10, color: labelColor));
      tp.layout();
      var px = x - tp.width / 2;
      if (px < left) px = left;
      if (px + tp.width > left + chartW) px = left + chartW - tp.width;
      tp.paint(canvas, Offset(px, size.height - 16));
    }
  }

  /// 把最大值收整到好读刻度
  static int _niceMax(int raw) {
    if (raw <= 1) return 1;
    if (raw <= 5) return 5;
    if (raw <= 10) return 10;
    final exp = (math.log(raw) / math.ln10).floor();
    final base = math.pow(10, exp).toDouble();
    final n = raw / base;
    double nice;
    if (n <= 1) {
      nice = 1;
    } else if (n <= 2) {
      nice = 2;
    } else if (n <= 5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return (nice * base).round();
  }

  static String _fmtY(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.roundToDouble() ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
    }
    if (v == v.roundToDouble()) return '${v.toInt()}';
    return v.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color track;
  final Color textColor;
  final String label;

  _GaugePainter({
    required this.percent,
    required this.color,
    required this.track,
    required this.textColor,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 6);
    final r = math.min(size.width, size.height) / 2 - 6;
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep, false, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      sweep * percent.clamp(0.0, 1.0),
      false,
      valuePaint,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, c.dy - 6));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.label != label;
  }
}
