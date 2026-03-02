import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/rclone_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  final _rcloneService = RcloneService();

  // NAS 配置
  final _nasUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final nasUrl = prefs.getString('nas_url') ?? '';
      final username = await _storage.read(key: 'nas_username') ?? '';
      final password = await _storage.read(key: 'nas_password') ?? '';

      _nasUrlController.text = nasUrl;
      _usernameController.text = username;
      _passwordController.text = password;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 保存到 SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nas_url', _nasUrlController.text);

      // 保存到 FlutterSecureStorage (加密)
      await _storage.write(key: 'nas_username', value: _usernameController.text);
      await _storage.write(key: 'nas_password', value: _passwordController.text);

      // 生成 rclone 配置
      final rcloneConfig = _generateRcloneConfig();
      await _rcloneService.saveConfig(rcloneConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 测试连接
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      // 先保存配置
      final rcloneConfig = _generateRcloneConfig();
      await _rcloneService.saveConfig(rcloneConfig);

      // 测试连接
      final success = await _rcloneService.testConnection();

      setState(() {
        _testResult = success ? '连接成功！✅' : '连接失败 ❌';
      });
    } catch (e) {
      setState(() {
        _testResult = '连接失败: $e';
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  /// 生成 rclone 配置文件
  String _generateRcloneConfig() {
    return '''
[nas]
type = webdav
url = ${_nasUrlController.text}
vendor = other
user = ${_usernameController.text}
pass = ${_passwordController.text}
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // NAS 配置
            _buildSectionHeader('NAS 配置 (WebDAV)'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nasUrlController,
              decoration: const InputDecoration(
                labelText: 'NAS 地址',
                hintText: 'http://192.168.1.100:5005',
                prefixIcon: Icon(Icons.dns),
                border: OutlineInputBorder(),
                helperText: '例如: http://192.168.1.100:5005',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入 NAS 地址';
                }
                if (!value.startsWith('http://') && !value.startsWith('https://')) {
                  return '地址必须以 http:// 或 https:// 开头';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入用户名';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // 测试连接按钮
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(_isTesting ? '测试中...' : '测试连接'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            // 测试结果
            if (_testResult != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _testResult!.contains('成功')
                    ? Colors.green[50]
                    : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                      color: _testResult!.contains('成功')
                          ? Colors.green[900]
                          : Colors.red[900],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // 上传设置
            _buildSectionHeader('上传设置'),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('仅 WiFi 上传'),
              subtitle: const Text('使用移动数据时不自动上传'),
              value: true,
              onChanged: (value) {
                // TODO: 实现
              },
            ),

            SwitchListTile(
              title: const Text('充电时上传'),
              subtitle: const Text('只在充电时自动上传'),
              value: false,
              onChanged: (value) {
                // TODO: 实现
              },
            ),

            const Divider(height: 32),

            // 存储管理
            _buildSectionHeader('存储管理'),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('清理缓存'),
              subtitle: const Text('清除本地缓存数据'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: 实现
              },
            ),

            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('清理已完成任务'),
              subtitle: const Text('删除 7 天前的已完成任务记录'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: 实现
              },
            ),

            const Divider(height: 32),

            // 关于
            _buildSectionHeader('关于'),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('版本'),
              subtitle: const Text('1.0.0'),
            ),

            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('开源许可'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: 显示许可证
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveConfig,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
            child: const Text('保存配置'),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  void dispose() {
    _nasUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
