import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';  // 🔒 添加 @immutable
import '../services/rclone_service.dart';
import '../services/upload_queue_service.dart';
import '../services/network_service.dart';  // 🌐 网络检测
import '../models/upload_task.dart';

// ============== Events ==============

abstract class UploadEvent extends Equatable {
  const UploadEvent();

  @override
  List<Object?> get props => [];
}

/// 开始上传单个文件
class StartUpload extends UploadEvent {
  final String taskId;
  final String localPath;
  final String remotePath;

  const StartUpload({
    required this.taskId,
    required this.localPath,
    required this.remotePath,
  });

  @override
  List<Object?> get props => [taskId, localPath, remotePath];
}

/// 开始批量上传
class StartBatchUpload extends UploadEvent {
  final List<UploadTask> tasks;

  const StartBatchUpload(this.tasks);

  @override
  List<Object?> get props => [tasks];
}

/// 取消上传
class CancelUpload extends UploadEvent {
  final String taskId;

  const CancelUpload(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

/// 暂停上传
class PauseUpload extends UploadEvent {
  final String taskId;

  const PauseUpload(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

/// 恢复上传
class ResumeUpload extends UploadEvent {
  final String taskId;

  const ResumeUpload(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

/// 重试失败的上传
class RetryUpload extends UploadEvent {
  final String taskId;

  const RetryUpload(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

/// 清理已完成任务
class ClearCompleted extends UploadEvent {
  final int olderThanDays;

  const ClearCompleted({this.olderThanDays = 7});

  @override
  List<Object?> get props => [olderThanDays];
}

/// 加载上传队列
class LoadUploadQueue extends UploadEvent {
  const LoadUploadQueue();
}

// ============== States ==============

/// 🔒 @immutable 确保状态不可变
@immutable
abstract class UploadState extends Equatable {
  const UploadState();

  @override
  List<Object?> get props => [];
}

@immutable
class UploadInitial extends UploadState {
  const UploadInitial();
}

@immutable
class UploadInProgress extends UploadState {
  final String taskId;
  final double progress;
  final double speedMBps;
  final int etaSeconds;
  final List<UploadTask> queue;
  final int completedCount;
  final int failedCount;
  final int totalCount;

  const UploadInProgress({
    required this.taskId,
    required this.progress,
    required this.speedMBps,
    required this.etaSeconds,
    this.queue = const [],
    this.completedCount = 0,
    this.failedCount = 0,
    this.totalCount = 0,
  });

  @override
  List<Object?> get props => [
        taskId,
        progress,
        speedMBps,
        etaSeconds,
        queue,
        completedCount,
        failedCount,
        totalCount,
      ];

  UploadInProgress copyWith({
    String? taskId,
    double? progress,
    double? speedMBps,
    int? etaSeconds,
    List<UploadTask>? queue,
    int? completedCount,
    int? failedCount,
    int? totalCount,
  }) {
    return UploadInProgress(
      taskId: taskId ?? this.taskId,
      progress: progress ?? this.progress,
      speedMBps: speedMBps ?? this.speedMBps,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      queue: queue ?? this.queue,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

@immutable
class UploadSuccess extends UploadState {
  final String taskId;
  final UploadTask task;

  const UploadSuccess({
    required this.taskId,
    required this.task,
  });

  @override
  List<Object?> get props => [taskId, task];
}

@immutable
class UploadFailure extends UploadState {
  final String taskId;
  final String errorMessage;
  final UploadTask? failedTask;

  const UploadFailure({
    required this.taskId,
    required this.errorMessage,
    this.failedTask,
  });

  @override
  List<Object?> get props => [taskId, errorMessage, failedTask];
}

@immutable
class UploadPaused extends UploadState {
  final String taskId;
  final UploadTask task;

  const UploadPaused({
    required this.taskId,
    required this.task,
  });

  @override
  List<Object?> get props => [taskId, task];
}

@immutable
class UploadCancelled extends UploadState {
  final String taskId;
  final UploadTask task;

  const UploadCancelled({
    required this.taskId,
    required this.task,
  });

  @override
  List<Object?> get props => [taskId, task];
}

/// 🌐 上传警告状态（网络相关）
@immutable
class UploadWarning extends UploadState {
  final String taskId;
  final String warningMessage;
  final WarningType warningType;

  const UploadWarning({
    required this.taskId,
    required this.warningMessage,
    required this.warningType,
  });

  @override
  List<Object?> get props => [taskId, warningMessage, warningType];
}

/// 警告类型
enum WarningType {
  /// ⚠️ 使用移动数据
  mobileData,
  
  /// ⚠️ 网络不稳定
  unstableNetwork,
  
  /// ⚠️ 电量过低
  lowBattery,
}

@immutable
class UploadQueueLoaded extends UploadState {
  final List<UploadTask> pending;
  final List<UploadTask> uploading;
  final List<UploadTask> completed;
  final List<UploadTask> failed;

  const UploadQueueLoaded({
    this.pending = const [],
    this.uploading = const [],
    this.completed = const [],
    this.failed = const [],
  });

  @override
  List<Object?> get props => [pending, uploading, completed, failed];

  int get totalCount => pending.length + uploading.length + completed.length + failed.length;
}

// ============== BLoC ==============

/// 上传管理 BLoC
/// 负责管理上传队列状态、处理上传事件
class UploadBloc extends Bloc<UploadEvent, UploadState> {
  final RcloneService _rcloneService;
  final UploadQueueService _queueService;
  final NetworkService _networkService;  // 🌐 网络检测服务

  // 存储活跃的上传订阅
  final Map<String, StreamSubscription<UploadProgress>> _uploadSubscriptions = {};
  
  // 当前并发上传任务数限制
  static const int _maxConcurrentUploads = 3;
  final Set<String> _activeUploads = {};
  
  // 是否已暂停
  bool _isPaused = false;

  UploadBloc({
    RcloneService? rcloneService,
    UploadQueueService? queueService,
    NetworkService? networkService,  // 🌐 可选注入
  })  : _rcloneService = rcloneService ?? RcloneService(),
        _queueService = queueService ?? UploadQueueService(),
        _networkService = networkService ?? NetworkService(),  // 🌐 默认实例
        super(const UploadInitial()) {
    on<StartUpload>(_onStartUpload);
    on<StartBatchUpload>(_onStartBatchUpload);
    on<CancelUpload>(_onCancelUpload);
    on<PauseUpload>(_onPauseUpload);
    on<ResumeUpload>(_onResumeUpload);
    on<RetryUpload>(_onRetryUpload);
    on<ClearCompleted>(_onClearCompleted);
    on<LoadUploadQueue>(_onLoadUploadQueue);
  }

  /// 处理单个上传任务开始
  /// 🌐 上传前检查网络状态
  Future<void> _onStartUpload(
    StartUpload event,
    Emitter<UploadState> emit,
  ) async {
    try {
      // 🌐 检查网络连接
      final networkCheck = await _networkService.checkBeforeUpload();
      
      if (networkCheck == NetworkCheckResult.noConnection) {
        emit(UploadFailure(
          taskId: event.taskId,
          errorMessage: '❌ 无网络连接，请检查网络设置',
        ));
        return;
      }
      
      if (networkCheck == NetworkCheckResult.mobile) {
        // ⚠️ 移动数据警告（由 UI 层处理确认）
        emit(UploadWarning(
          taskId: event.taskId,
          warningMessage: '⚠️ 当前使用移动数据，建议切换到 WiFi',
          warningType: WarningType.mobileData,
        ));
        // 注意：这里仍然继续上传，由 UI 决定是否取消
      }
      
      // 创建任务
      final task = UploadTask.create(
        id: event.taskId,
        localPath: event.localPath,
        remotePath: event.remotePath,
      );

      // 添加到队列
      await _queueService.addTask(task);

      // 如果没有超出并发限制，立即开始上传
      if (_activeUploads.length < _maxConcurrentUploads && !_isPaused) {
        await _startTaskUpload(task, emit);
      } else {
        // 等待队列处理
        emit(const UploadInProgress(
          taskId: '',
          progress: 0,
          speedMBps: 0,
          etaSeconds: 0,
        ));
      }
    } catch (e) {
      emit(UploadFailure(
        taskId: event.taskId,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 处理批量上传开始
  Future<void> _onStartBatchUpload(
    StartBatchUpload event,
    Emitter<UploadState> emit,
  ) async {
    try {
      // 批量添加到队列
      await _queueService.addTasks(event.tasks);

      // 按并发限制开始上传
      final pendingTasks = await _queueService.getPendingTasks();
      _processQueue(pendingTasks, emit);
    } catch (e) {
      emit(UploadFailure(
        taskId: 'batch',
        errorMessage: '批量上传失败: ${e.toString()}',
      ));
    }
  }

  /// 处理取消上传
  Future<void> _onCancelUpload(
    CancelUpload event,
    Emitter<UploadState> emit,
  ) async {
    try {
      // 取消 Rclone 上传
      await _rcloneService.cancelUpload(event.taskId);

      // 取消流订阅
      await _uploadSubscriptions[event.taskId]?.cancel();
      _uploadSubscriptions.remove(event.taskId);
      _activeUploads.remove(event.taskId);

      // 更新队列状态
      final task = await _queueService.getTask(event.taskId);
      if (task != null) {
        final updatedTask = task.copyWith(status: UploadStatus.cancelled);
        await _queueService.updateTask(updatedTask);
        emit(UploadCancelled(taskId: event.taskId, task: task));
      }
    } catch (e) {
      emit(UploadFailure(
        taskId: event.taskId,
        errorMessage: '取消失败: ${e.toString()}',
      ));
    }
  }

  /// 处理暂停上传
  Future<void> _onPauseUpload(
    PauseUpload event,
    Emitter<UploadState> emit,
  ) async {
    _isPaused = true;

    try {
      // 取消当前所有活跃上传
      for (final taskId in _activeUploads.toList()) {
        await _rcloneService.cancelUpload(taskId);
        await _uploadSubscriptions[taskId]?.cancel();
        _uploadSubscriptions.remove(taskId);
      }
      _activeUploads.clear();

      // 更新队列状态
      final task = await _queueService.getTask(event.taskId);
      if (task != null) {
        final updatedTask = task.copyWith(status: UploadStatus.pending);
        await _queueService.updateTask(updatedTask);
        emit(UploadPaused(taskId: event.taskId, task: updatedTask));
      }
    } catch (e) {
      emit(UploadFailure(
        taskId: event.taskId,
        errorMessage: '暂停失败: ${e.toString()}',
      ));
    }
  }

  /// 处理恢复上传
  Future<void> _onResumeUpload(
    ResumeUpload event,
    Emitter<UploadState> emit,
  ) async {
    _isPaused = false;

    try {
      final pendingTasks = await _queueService.getPendingTasks();
      _processQueue(pendingTasks, emit);
    } catch (e) {
      emit(UploadFailure(
        taskId: event.taskId,
        errorMessage: '恢复失败: ${e.toString()}',
      ));
    }
  }

  /// 处理重试上传
  Future<void> _onRetryUpload(
    RetryUpload event,
    Emitter<UploadState> emit,
  ) async {
    try {
      // 重置任务状态
      final task = await _queueService.getTask(event.taskId);
      if (task != null && task.canRetry) {
        final updatedTask = task.copyWith(
          status: UploadStatus.pending,
          progress: 0.0,
          errorMessage: null,
        );
        await _queueService.updateTask(updatedTask);

        // 从队列中开始
        if (_activeUploads.length < _maxConcurrentUploads) {
          await _startTaskUpload(updatedTask, emit);
        }
      }
    } catch (e) {
      emit(UploadFailure(
        taskId: event.taskId,
        errorMessage: '重试失败: ${e.toString()}',
      ));
    }
  }

  /// 处理清理已完成任务
  Future<void> _onClearCompleted(
    ClearCompleted event,
    Emitter<UploadState> emit,
  ) async {
    try {
      await _queueService.deleteCompletedTasks(
        olderThanDays: event.olderThanDays,
      );
      add(const LoadUploadQueue());
    } catch (e) {
      emit(UploadFailure(
        taskId: 'clear',
        errorMessage: '清理失败: ${e.toString()}',
      ));
    }
  }

  /// 处理加载上传队列
  Future<void> _onLoadUploadQueue(
    LoadUploadQueue event,
    Emitter<UploadState> emit,
  ) async {
    try {
      final tasks = await _queueService.getAllTasks();

      final pending = <UploadTask>[];
      final uploading = <UploadTask>[];
      final completed = <UploadTask>[];
      final failed = <UploadTask>[];

      for (final task in tasks) {
        switch (task.status) {
          case UploadStatus.pending:
            pending.add(task);
            break;
          case UploadStatus.uploading:
            uploading.add(task);
            break;
          case UploadStatus.completed:
            completed.add(task);
            break;
          case UploadStatus.failed:
          case UploadStatus.cancelled:
            failed.add(task);
            break;
        }
      }

      emit(UploadQueueLoaded(
        pending: pending,
        uploading: uploading,
        completed: completed,
        failed: failed,
      ));
    } catch (e) {
      emit(UploadFailure(
        taskId: 'load',
        errorMessage: '加载队列失败: ${e.toString()}',
      ));
    }
  }

  /// 开始单个任务上传
  Future<void> _startTaskUpload(
    UploadTask task,
    Emitter<UploadState> emit,
  ) async {
    _activeUploads.add(task.id);

    // 更新任务状态为上传中
    final uploadingTask = task.copyWith(status: UploadStatus.uploading);
    await _queueService.updateTask(uploadingTask);

    final subscription = _rcloneService.uploadFile(
      uploadId: task.id,
      localPath: task.localPath,
      remotePath: task.remotePath,
    ).listen(
      (progress) {
        emit(UploadInProgress(
          taskId: task.id,
          progress: progress.percent,
          speedMBps: progress.speedMBps,
          etaSeconds: progress.etaSeconds,
          totalCount: _activeUploads.length,
        ));

        // 更新队列中的进度
        _queueService.updateProgress(task.id, progress.percent);
      },
      onError: (error) async {
        _activeUploads.remove(task.id);
        _uploadSubscriptions.remove(task.id);

        final failedTask = task.copyWith(
          status: UploadStatus.failed,
          errorMessage: error.toString(),
        );
        await _queueService.updateTask(failedTask);
        emit(UploadFailure(
          taskId: task.id,
          errorMessage: error.toString(),
          failedTask: failedTask,
        ));

        // 继续处理队列
        _processNextTask(emit);
      },
      onDone: () async {
        _activeUploads.remove(task.id);
        _uploadSubscriptions.remove(task.id);

        final completedTask = task.copyWith(
          status: UploadStatus.completed,
          progress: 100.0,
        );
        await _queueService.updateTask(completedTask);
        emit(UploadSuccess(taskId: task.id, task: completedTask));

        // 继续处理下一个任务
        _processNextTask(emit);
      },
    );

    _uploadSubscriptions[task.id] = subscription;
  }

  /// 处理队列中的下一个任务
  Future<void> _processNextTask(Emitter<UploadState> emit) async {
    if (_isPaused) return;

    if (_activeUploads.length < _maxConcurrentUploads) {
      final pendingTasks = await _queueService.getPendingTasks();
      _processQueue(pendingTasks, emit);
    }
  }

  /// 处理待上传队列
  Future<void> _processQueue(
    List<UploadTask> pendingTasks,
    Emitter<UploadState> emit,
  ) async {
    if (_isPaused) return;

    final availableSlots = _maxConcurrentUploads - _activeUploads.length;
    final tasksToStart = pendingTasks
        .where((task) => !_activeUploads.contains(task.id))
        .take(availableSlots)
        .toList();

    for (final task in tasksToStart) {
      await _startTaskUpload(task, emit);
    }
  }

  /// 获取当前统计信息
  Future<Map<String, int>> getStatistics() async {
    return await _queueService.getStatistics();
  }

  /// 获取总任务数
  Future<int> getTotalCount() async {
    return await _queueService.getTotalCount();
  }

  @override
  Future<void> close() async {
    // 取消所有上传
    for (final subscription in _uploadSubscriptions.values) {
      await subscription.cancel();
    }
    _uploadSubscriptions.clear();
    _activeUploads.clear();

    // 清理服务
    await _rcloneService.dispose();
    await _queueService.close();

    await super.close();
  }
}
