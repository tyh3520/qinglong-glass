import 'dart:convert';

import 'package:json_conversion_annotation/json_conversion_annotation.dart';

import '../../main.dart';

/// 青龙 2.19+ 的「附加定时规则」。
/// 一个任务可以有多条定时规则：第 1 条存在 `schedule` 里，
/// 其余的以 `[{ "schedule": "..." }]` 的形式存在 `extra_schedules` 里。
class ExtraSchedule {
  String? schedule;

  ExtraSchedule({this.schedule});

  ExtraSchedule.fromJson(Map<String, dynamic> json) {
    schedule = json['schedule']?.toString();
  }

  Map<String, dynamic> toJson() {
    return {"schedule": schedule};
  }
}

@JsonConversion()
class TaskBean {
  String? name;
  String? command;
  String? schedule;

  /// 附加定时规则（对应青龙接口的 extra_schedules）
  List<ExtraSchedule>? extraSchedules;
  bool? saved;
  String? sId;
  int? id;
  String? _id;
  int? created;
  int? status;
  String? timestamp;
  int? isSystem;
  int? isDisabled;
  String? logPath;
  int? isPinned;
  int? lastExecutionTime;
  int? lastRunningTime;
  String? pid;
  String? updatedAt;
  String? createdAt;

  TaskBean(
      {this.name,
      this.command,
      this.schedule,
      this.saved,
      this.sId,
      this.created,
      this.status,
      this.timestamp,
      this.isSystem,
      this.isDisabled,
      this.logPath,
      this.isPinned,
      this.lastExecutionTime,
      this.lastRunningTime,
      this.extraSchedules,
      this.pid});

  get nId => _id;

  /// 全部定时规则（主规则在前，附加规则在后），已过滤空值
  List<String> get allSchedules {
    final List<String> result = [];
    final String main = schedule?.trim() ?? "";
    if (main.isNotEmpty) result.add(main);
    for (final item in extraSchedules ?? const <ExtraSchedule>[]) {
      final String extra = item.schedule?.trim() ?? "";
      if (extra.isNotEmpty) result.add(extra);
    }
    return result;
  }

  /// 用于列表页展示 / 搜索的单行文本
  String get scheduleText => allSchedules.join(" ");

  TaskBean.fromJson(Map<String, dynamic> json) {
    try {
      name = json['name'].toString();
      command = json['command'].toString();
      schedule = json['schedule'].toString();
      final rawExtraSchedules = json['extra_schedules'];
      if (rawExtraSchedules is List) {
        extraSchedules = rawExtraSchedules
            .whereType<Map>()
            .map((e) => ExtraSchedule.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      saved = json['saved'];
      id = json['id'];
      _id = json['_id'];
      sId = json.containsKey('_id')
          ? json['_id'].toString()
          : (json.containsKey('id') ? json['id'].toString() : "");
      created = int.tryParse(json['created'].toString());
      status = json['status'];
      timestamp = json['timestamp'].toString();
      createdAt = json['createdAt'];
      updatedAt = json['updatedAt'];
      isSystem = json['isSystem'];
      isDisabled = json['isDisabled'];
      logPath = json['log_path'].toString();
      isPinned = json['isPinned'];
      lastExecutionTime = int.tryParse(json['last_execution_time'].toString());
      lastRunningTime = json['last_running_time'];
      pid = json['pid'].toString();
    } catch (e) {
      logger.e(e);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['command'] = this.command;
    data['schedule'] = this.schedule;
    data['extra_schedules'] = this.extraSchedules?.map((e) => e.toJson()).toList();
    data['saved'] = this.saved;
    data['_id'] = this.sId;
    data['created'] = this.created;
    data['status'] = this.status;
    data['timestamp'] = this.timestamp;
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    data['isSystem'] = this.isSystem;
    data['isDisabled'] = this.isDisabled;
    data['log_path'] = this.logPath;
    data['isPinned'] = this.isPinned;
    data['last_execution_time'] = this.lastExecutionTime;
    data['last_running_time'] = this.lastRunningTime;
    data['pid'] = this.pid;
    return data;
  }

  static TaskBean jsonConversion(Map<String, dynamic> json) {
    return TaskBean.fromJson(json);
  }
}
