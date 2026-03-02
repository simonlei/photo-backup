---
status: pending
priority: p2
issue_id: "005"
tags: [code-review, error-handling, user-experience]
dependencies: []
---

# 🟡 P2: 缺少网络状态检测和用户提示

## Problem Statement

**What's broken:**
应用在无网络或 WiFi 切换时没有检测和提示，直接上传会失败，用户体验差。

**Why it matters:**
- 移动设备常切换网络（WiFi ↔ 4G）
- 无网络时上传浪费电量和用户时间
- 缺少友好的错误提示

**Impact:**
- **Severity:** 🟡 IMPORTANT (P2)
- **User Experience:** 差
- **Battery Impact:** 高

## Proposed Solutions

### Solution 1: 集成 connectivity_plus

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class UploadService {
  final _connectivity = Connectivity();
  
  Future<bool> checkNetworkBeforeUpload() async {
    final result = await _connectivity.checkConnectivity();
    
    if (result == ConnectivityResult.none) {
      throw NetworkException('No internet connection');
    }
    
    if (result == ConnectivityResult.mobile) {
      // 警告用户：正在使用移动数据
      return await showMobileDataWarning();
    }
    
    return true;
  }
  
  Stream<ConnectivityResult> watchNetworkStatus() {
    return _connectivity.onConnectivityChanged;
  }
}
```

**Effort:** 🟡 Medium (1 小时)  
**Risk:** 🟢 Low

## Recommended Action

添加网络检测，上传前检查，WiFi 断开时暂停。

## Acceptance Criteria

- [ ] 上传前检查网络状态
- [ ] 移动数据时弹窗确认
- [ ] WiFi 断开时暂停上传
- [ ] 网络恢复时自动继续

---

**Priority Justification:** 🟡 P2 - 显著改善用户体验，应优先实现
