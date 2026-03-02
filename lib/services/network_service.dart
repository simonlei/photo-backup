import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 网络状态管理服务
/// 功能：
/// - 检测网络连接状态（WiFi/移动数据/无网络）
/// - 监听网络状态变化
/// - 提供上传前网络检查
class NetworkService {
  final Connectivity _connectivity = Connectivity();
  
  // 单例模式
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();
  
  /// 当前网络状态流
  Stream<ConnectivityResult> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
  
  /// 检查当前网络连接状态
  Future<ConnectivityResult> checkConnectivity() async {
    return await _connectivity.checkConnectivity();
  }
  
  /// 是否有网络连接
  Future<bool> hasConnection() async {
    final result = await checkConnectivity();
    return result != ConnectivityResult.none;
  }
  
  /// 是否连接 WiFi
  Future<bool> isWiFiConnected() async {
    final result = await checkConnectivity();
    return result == ConnectivityResult.wifi;
  }
  
  /// 是否使用移动数据
  Future<bool> isMobileData() async {
    final result = await checkConnectivity();
    return result == ConnectivityResult.mobile;
  }
  
  /// 上传前检查网络状态
  /// 返回：
  /// - NetworkCheckResult.ok: 可以上传（WiFi）
  /// - NetworkCheckResult.mobile: 移动数据警告
  /// - NetworkCheckResult.noConnection: 无网络
  Future<NetworkCheckResult> checkBeforeUpload() async {
    final result = await checkConnectivity();
    
    switch (result) {
      case ConnectivityResult.none:
        return NetworkCheckResult.noConnection;
      
      case ConnectivityResult.mobile:
        return NetworkCheckResult.mobile;
      
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        return NetworkCheckResult.ok;
      
      default:
        return NetworkCheckResult.unknown;
    }
  }
  
  /// 获取网络类型描述
  String getNetworkTypeDescription(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return '移动数据';
      case ConnectivityResult.ethernet:
        return '以太网';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return '蓝牙';
      case ConnectivityResult.other:
        return '其他';
      case ConnectivityResult.none:
        return '无网络';
      default:
        return '未知';
    }
  }
}

/// 网络检查结果
enum NetworkCheckResult {
  /// ✅ 可以上传（WiFi 或以太网）
  ok,
  
  /// ⚠️ 移动数据警告
  mobile,
  
  /// ❌ 无网络连接
  noConnection,
  
  /// ❓ 未知网络状态
  unknown,
}

/// 网络检查异常
class NetworkException implements Exception {
  final String message;
  final NetworkCheckResult result;
  
  NetworkException(this.message, this.result);
  
  @override
  String toString() => 'NetworkException: $message';
}
