import 'dart:async';
import 'package:flutter/services.dart';

/// rclone 服务封装
/// 提供 Platform Channel 调用接口
class RcloneService {
  static const _methodChannel = MethodChannel('com.example.photobackup/rclone');
  static const _eventChannel = EventChannel('com.example.photobackup/rclone_progress');
  
  // 存储所有活跃订阅
  final Map<String, StreamSubscription> _subscriptions = {};
  
  // 单例模式
  static final RcloneService _instance = RcloneService._internal();
  factory RcloneService() => _instance;
  RcloneService._internal();
  
  /// 上传文件并返回进度流
  Stream<UploadProgress> uploadFile({
    required String uploadId,
    required String localPath,
    required String remotePath,
  }) async* {
    // 取消同 ID 的旧订阅（如果存在）
    await cancelUpload(uploadId);
    
    try {
      // 启动上传
      await _methodChannel.invokeMethod('uploadFile', {
        'uploadId': uploadId,
        'localPath': localPath,
        'remotePath': remotePath,
      });
      
      // 监听进度
      await for (final event in _eventChannel.receiveBroadcastStream(uploadId)) {
        final progress = UploadProgress.fromMap(event as Map<dynamic, dynamic>);
        
        // 只传递当前 uploadId 的进度
        if (progress.uploadId == uploadId) {
          yield progress;
          
          // 完成或失败时自动清理
          if (progress.isComplete || progress.isFailed) {
            break;
          }
        }
      }
      
    } catch (e) {
      throw _parseException(e);
    } finally {
      // 确保清理订阅
      _subscriptions.remove(uploadId);
    }
  }
  
  /// 取消上传
  Future<bool> cancelUpload(String uploadId) async {
    try {
      // 取消订阅
      await _subscriptions[uploadId]?.cancel();
      _subscriptions.remove(uploadId);
      
      // 通知 Native 层取消
      final success = await _methodChannel.invokeMethod('cancelUpload', {
        'uploadId': uploadId,
      });
      
      return success as bool;
    } catch (e) {
      return false;
    }
  }
  
  /// 获取活跃上传列表
  Future<List<String>> getActiveUploads() async {
    try {
      final result = await _methodChannel.invokeMethod('getActiveUploads');
      return List<String>.from(result as List);
    } catch (e) {
      return [];
    }
  }
  
  /// 保存 rclone 配置
  Future<void> saveConfig(String config) async {
    try {
      await _methodChannel.invokeMethod('saveRcloneConfig', {
        'config': config,
      });
    } catch (e) {
      throw _parseException(e);
    }
  }
  
  /// 测试连接
  Future<bool> testConnection() async {
    try {
      final result = await _methodChannel.invokeMethod('testConnection');
      return result as bool;
    } catch (e) {
      return false;
    }
  }
  
  /// 清理所有订阅（App 关闭时调用）
  Future<void> dispose() async {
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
  
  /// 解析异常
  Exception _parseException(dynamic error) {
    if (error is PlatformException) {
      switch (error.code) {
        case 'NETWORK_ERROR':
          return NetworkException(error.message ?? 'Network error');
        case 'AUTH_ERROR':
          return AuthenticationException(error.message ?? 'Authentication failed');
        case 'TIMEOUT':
          return TimeoutException(error.message ?? 'Upload timeout');
        case 'UPLOAD_FAILED':
          return UploadFailedException(error.message ?? 'Upload failed');
        default:
          return AppException(error.message ?? 'Unknown error');
      }
    }
    return AppException(error.toString());
  }
}

/// 上传进度数据类
class UploadProgress {
  final String uploadId;
  final double percent;
  final int bytesTransferred;
  final int totalBytes;
  final double speedMBps;
  final int etaSeconds;
  final UploadStatus status;
  
  UploadProgress({
    required this.uploadId,
    required this.percent,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.speedMBps,
    required this.etaSeconds,
    required this.status,
  });
  
  bool get isComplete => status == UploadStatus.completed;
  bool get isFailed => status == UploadStatus.failed;
  bool get isCancelled => status == UploadStatus.cancelled;
  
  factory UploadProgress.fromMap(Map<dynamic, dynamic> map) => UploadProgress(
    uploadId: map['uploadId'] as String,
    percent: (map['percent'] as num).toDouble(),
    bytesTransferred: map['bytesTransferred'] as int,
    totalBytes: map['totalBytes'] as int,
    speedMBps: (map['speedMBps'] as num).toDouble(),
    etaSeconds: map['etaSeconds'] as int,
    status: UploadStatus.values[map['status'] as int],
  );
  
  Map<String, dynamic> toMap() => {
    'uploadId': uploadId,
    'percent': percent,
    'bytesTransferred': bytesTransferred,
    'totalBytes': totalBytes,
    'speedMBps': speedMBps,
    'etaSeconds': etaSeconds,
    'status': status.index,
  };
  
  @override
  String toString() {
    return 'UploadProgress(id: $uploadId, ${percent.toStringAsFixed(1)}%, '
           '${(speedMBps).toStringAsFixed(1)} MB/s, ETA: ${etaSeconds}s)';
  }
}

enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
  cancelled,
}

// 自定义异常
class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message);
}

class AuthenticationException extends AppException {
  AuthenticationException(String message) : super(message);
}

class TimeoutException extends AppException {
  TimeoutException(String message) : super(message);
}

class UploadFailedException extends AppException {
  UploadFailedException(String message) : super(message);
}
