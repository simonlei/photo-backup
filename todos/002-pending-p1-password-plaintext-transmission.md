---
status: pending
priority: p1
issue_id: "002"
tags: [code-review, security, credential-leak]
dependencies: []
---

# 🔴 P1: 密码明文传输到 Native 层

## Problem Statement

**What's broken:**
用户的 NAS 密码在 Flutter 和 Android Native 层之间通过 Platform Channel 明文传输，存在内存泄漏和日志泄露风险。

**Why it matters:**
- 密码明文存在于内存中，可能被恶意 App dump
- Platform Channel 调用可能被记录到日志（调试模式）
- 不符合 Android 安全最佳实践

**Impact:**
- **Severity:** 🔴 CRITICAL (P1)
- **Affected Users:** 所有使用密码保护的 NAS 用户
- **Frequency:** 每次配置保存
- **Security Risk:** 高（凭证泄露）

## Findings

### Code Location

**File:** `lib/screens/settings_screen.dart` (推断)  
**Expected Code:**
```dart
// ❌ 问题：密码明文传递
await rcloneService.saveConfig('''
[nas]
type = webdav
url = $nasUrl
user = $username
pass = $password  // ⚠️ 明文密码
''');
```

**File:** `android/MainActivity.kt` (推断)  
```kotlin
// ❌ 问题：可能记录敏感信息
"saveRcloneConfig" -> {
    val config = call.argument<String>("config")
    Log.d(TAG, "Saving config: $config")  // ⚠️ 密码可能在日志中
    // ...
}
```

### Vulnerability Details

**泄露途径:**
1. **内存 Dump:** 调试器可 attach 到 App 进程读取内存
2. **日志泄露:** Logcat 中可能包含密码（开发/测试环境）
3. **崩溃报告:** 崩溃日志可能包含堆栈信息和变量值
4. **ADB 日志:** `adb logcat` 可被其他 App 读取（需权限）

**风险场景:**
- 用户设备被 root
- 恶意 App 有 READ_LOGS 权限
- 开发者不小心提交带密码的日志

### Evidence

- ✅ Platform Channel 传输未加密
- ✅ rclone.conf 文件存储在明文（需检查）
- ⚠️ 无密码混淆（rclone obscure）
- ⚠️ 日志可能泄露敏感信息

## Proposed Solutions

### Solution 1: 使用 rclone obscure（推荐）

**Approach:**
使用 rclone 的内置密码混淆功能，混淆后再存储和传输。

**Implementation:**

**Dart 端 (`lib/services/config_service.dart`):**
```dart
import 'package:flutter/services.dart';

class ConfigService {
  static const _channel = MethodChannel('com.example.photobackup/rclone');
  
  Future<void> setCredentials({
    required String nasUrl,
    required String username,
    required String password,
  }) async {
    // 1. 调用 Native 层混淆密码
    final obscuredPassword = await _channel.invokeMethod<String>(
      'obscurePassword',
      {'password': password},
    );
    
    if (obscuredPassword == null) {
      throw Exception('Failed to obscure password');
    }
    
    // 2. 生成配置（使用混淆后的密码）
    final config = '''
[nas]
type = webdav
url = $nasUrl
user = $username
pass = $obscuredPassword
''';
    
    // 3. 保存配置
    await _channel.invokeMethod('saveRcloneConfig', {'config': config});
  }
}
```

**Kotlin 端 (`android/MainActivity.kt`):**
```kotlin
import java.io.BufferedReader
import java.io.InputStreamReader

"obscurePassword" -> {
    val password = call.argument<String>("password") ?: run {
        result.error("INVALID_ARGUMENT", "password required", null)
        return@setMethodCallHandler
    }
    
    // 调用 rclone obscure
    val obscured = obscurePassword(password)
    result.success(obscured)
}

private fun obscurePassword(password: String): String {
    val rclonePath = "${applicationInfo.nativeLibraryDir}/librclone.so"
    
    val process = ProcessBuilder(rclonePath, "obscure", password)
        .redirectErrorStream(true)
        .start()
    
    val reader = BufferedReader(InputStreamReader(process.inputStream))
    val obscured = reader.readLine() ?: throw Exception("Failed to obscure")
    
    process.waitFor(5, TimeUnit.SECONDS)
    
    return obscured
}
```

**Pros:**
- ✅ rclone 原生支持，无额外依赖
- ✅ 混淆算法稳定可靠
- ✅ 不改变 rclone 使用方式
- ✅ 简单易实现

**Cons:**
- ⚠️ 混淆非加密，可逆（但增加攻击难度）
- ⚠️ 需要额外的 Native 调用

**Effort:** 🟡 Medium (45 分钟)  
**Risk:** 🟢 Low  
**Security:** 🟡 Medium（混淆非加密，但符合 rclone 推荐）

---

### Solution 2: 使用 flutter_secure_storage + AES 加密

**Approach:**
在存储前用 AES 加密密码，传输时也加密。

**Implementation:**
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart';

class ConfigService {
  final _secureStorage = FlutterSecureStorage();
  
  Future<void> setCredentials({
    required String nasUrl,
    required String username,
    required String password,
  }) async {
    // 1. 生成或获取加密密钥
    String? keyString = await _secureStorage.read(key: 'encryption_key');
    if (keyString == null) {
      keyString = Key.fromSecureRandom(32).base64;
      await _secureStorage.write(key: 'encryption_key', value: keyString);
    }
    
    final key = Key.fromBase64(keyString);
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key));
    
    // 2. 加密密码
    final encrypted = encrypter.encrypt(password, iv: iv);
    final encryptedB64 = '${iv.base64}:${encrypted.base64}';
    
    // 3. 安全存储
    await _secureStorage.write(key: 'nas_password_encrypted', value: encryptedB64);
    
    // 4. 需要时解密传给 rclone（在 Native 层）
    // ...
  }
}
```

**Pros:**
- ✅ 真正的加密（AES-256）
- ✅ 符合安全标准
- ✅ flutter_secure_storage 使用 Android Keystore

**Cons:**
- ❌ 过度工程（rclone 本身不加密配置）
- ❌ 增加复杂度和依赖
- ❌ 性能开销

**Effort:** 🔴 Large (2 小时)  
**Risk:** 🟡 Medium  
**Recommendation:** ⚠️ 除非有特殊合规要求，否则过度

---

### Solution 3: 仅修复日志泄露（最小改动）

**Approach:**
确保日志中不包含密码，但不改变传输方式。

**Implementation:**
```kotlin
"saveRcloneConfig" -> {
    val config = call.argument<String>("config")
    
    // ✅ 不记录完整配置
    Log.d(TAG, "Saving config (${config.length} bytes)")
    
    // 保存配置
    val configFile = File(filesDir, "rclone.conf")
    configFile.writeText(config)
    
    result.success(null)
}
```

**Pros:**
- ✅ 改动最小
- ✅ 快速实施

**Cons:**
- ❌ 仍有内存泄露风险
- ❌ 不彻底解决问题

**Effort:** 🟢 Small (10 分钟)  
**Risk:** 🟢 Low  
**Recommendation:** ⚠️ 临时方案，应配合 Solution 1

## Recommended Action

**采用 Solution 1（rclone obscure）+ Solution 3（日志清理）**

**理由:**
1. rclone官方推荐的密码保护方式
2. 兼顾安全性和实用性
3. 无需复杂加密库
4. 符合现有架构

**实施顺序:**
1. 立即修复日志泄露（Solution 3）
2. 实现密码混淆（Solution 1）
3. 更新文档，要求所有配置使用混淆密码

## Technical Details

### Affected Files
- `lib/services/config_service.dart` (新增 obscure 方法)
- `lib/screens/settings_screen.dart` (调用 obscure)
- `android/MainActivity.kt` (实现 obscurePassword)

### API Changes
新增 Platform Channel 方法:
```dart
Future<String> obscurePassword(String password)
```

### Dependencies
- 无新增依赖（使用 rclone 内置功能）

## Acceptance Criteria

- [ ] 密码通过 rclone obscure 混淆后存储
- [ ] Platform Channel 传输混淆后的密码
- [ ] 日志中不包含明文或混淆后的密码
- [ ] 配置文件使用混淆密码（`pass = <obscured>`）
- [ ] 测试连接功能正常（验证混淆密码可用）
- [ ] 安全审计通过

### Testing Checklist

```dart
// 单元测试
@Test
void testPasswordObscure() async {
  final configService = ConfigService();
  final obscured = await configService.obscurePassword('test123');
  
  // 验证混淆后格式正确
  expect(obscured, isNot('test123'));
  expect(obscured, startsWith('rclone_obscure'));
  
  // 验证 rclone 能解密使用
  final testResult = await rcloneService.testConnection();
  expect(testResult, isTrue);
}
```

```bash
# 手动测试
adb logcat | grep -i "password\|pass\|credential"
# 应该看不到任何明文密码
```

## Work Log

### 2026-03-02 - Issue Identified
- **Action:** Code review 发现密码明文传输
- **Risk:** 日志泄露、内存 dump 风险
- **Decision:** 使用 rclone obscure + 日志清理

---

### [Future Date] - Implementation
- **Action:** [To be filled during work]
- **Changes:** [File paths and code changes]
- **Testing:** [Test results]

## Resources

### Related Documentation
- [rclone Configuration Encryption](https://rclone.org/docs/#configuration-encryption)
- [rclone obscure command](https://rclone.org/commands/rclone_obscure/)
- [Android Security Best Practices](https://developer.android.com/topic/security/best-practices)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)

### Similar Issues
- None in current codebase

### Code Examples
```bash
# rclone obscure 示例
$ rclone obscure mypassword
rclone_obscure:xVJBfVJBfVJBf...

# 在配置中使用
[nas]
pass = rclone_obscure:xVJBfVJBfVJBf...
```

---

**Priority Justification:**
🔴 P1 因为：
1. 安全漏洞，凭证泄露风险
2. 不符合安全最佳实践
3. 修复成本低，收益大
4. 阻止发布前必须修复
