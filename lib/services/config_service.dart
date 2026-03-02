import 'package:flutter/services.dart';

/// rclone 配置管理服务
/// 处理 WebDAV 凭证和密码混淆
class ConfigService {
  static const _methodChannel = MethodChannel('com.example.photobackup/rclone');
  
  // 单例模式
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();
  
  /// 保存 WebDAV 配置（自动混淆密码）
  Future<void> setCredentials({
    required String nasUrl,
    required String username,
    required String password,
  }) async {
    try {
      // 1. 调用 Native 层混淆密码
      final obscuredPassword = await _obscurePassword(password);
      
      // 2. 生成 rclone 配置（使用混淆后的密码）
      final config = '''
[nas]
type = webdav
url = $nasUrl
user = $username
pass = $obscuredPassword
vendor = other
''';
      
      // 3. 保存配置到本地
      await _methodChannel.invokeMethod('saveRcloneConfig', {
        'config': config,
      });
    } catch (e) {
      throw ConfigException('Failed to save credentials: $e');
    }
  }
  
  /// 混淆密码（调用 rclone obscure）
  Future<String> _obscurePassword(String password) async {
    try {
      final result = await _methodChannel.invokeMethod<String>(
        'obscurePassword',
        {'password': password},
      );
      
      if (result == null || result.isEmpty) {
        throw ConfigException('Password obscure returned empty result');
      }
      
      return result;
    } on PlatformException catch (e) {
      throw ConfigException('Failed to obscure password: ${e.message}');
    }
  }
  
  /// 测试连接
  Future<bool> testConnection() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('testConnection');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// 获取当前配置（不包含密码）
  Future<Map<String, String>?> getCurrentConfig() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getCurrentConfig');
      return result?.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (e) {
      return null;
    }
  }
}

/// 配置相关异常
class ConfigException implements Exception {
  final String message;
  ConfigException(this.message);
  
  @override
  String toString() => 'ConfigException: $message';
}
