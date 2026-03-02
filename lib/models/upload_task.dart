import 'package:equatable/equatable.dart';

/// 上传状态枚举
enum UploadStatus {
  pending,    // 待上传
  uploading,  // 上传中
  completed,  // 已完成
  failed,     // 失败
  cancelled,  // 已取消
}

/// 上传任务模型
class UploadTask extends Equatable {
  final String id;
  final String localPath;
  final String remotePath;
  final UploadStatus status;
  final double progress;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const UploadTask({
    required this.id,
    required this.localPath,
    required this.remotePath,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });
  
  /// 从 Map 创建（数据库反序列化）
  factory UploadTask.fromMap(Map<String, dynamic> map) {
    return UploadTask(
      id: map['id'] as String,
      localPath: map['localPath'] as String,
      remotePath: map['remotePath'] as String,
      status: UploadStatus.values[map['status'] as int],
      progress: (map['progress'] as num).toDouble(),
      errorMessage: map['errorMessage'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
  
  /// 转换为 Map（数据库序列化）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'localPath': localPath,
      'remotePath': remotePath,
      'status': status.index,
      'progress': progress,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
  
  /// 创建副本（不可变更新）
  UploadTask copyWith({
    String? id,
    String? localPath,
    String? remotePath,
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UploadTask(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  /// 便捷创建方法
  factory UploadTask.create({
    required String id,
    required String localPath,
    required String remotePath,
  }) {
    final now = DateTime.now();
    return UploadTask(
      id: id,
      localPath: localPath,
      remotePath: remotePath,
      status: UploadStatus.pending,
      progress: 0.0,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  /// 是否完成
  bool get isCompleted => status == UploadStatus.completed;
  
  /// 是否失败
  bool get isFailed => status == UploadStatus.failed;
  
  /// 是否取消
  bool get isCancelled => status == UploadStatus.cancelled;
  
  /// 是否进行中
  bool get isInProgress => status == UploadStatus.uploading;
  
  /// 是否可重试
  bool get canRetry => isFailed || isCancelled;
  
  /// 获取文件名
  String get fileName {
    return localPath.split('/').last;
  }
  
  /// 获取远程目录
  String get remoteDir {
    final parts = remotePath.split('/');
    return parts.sublist(0, parts.length - 1).join('/');
  }
  
  @override
  List<Object?> get props => [
        id,
        localPath,
        remotePath,
        status,
        progress,
        errorMessage,
        createdAt,
        updatedAt,
      ];
  
  @override
  String toString() {
    return 'UploadTask(id: $id, file: $fileName, status: ${status.name}, progress: ${progress.toStringAsFixed(1)}%)';
  }
}
