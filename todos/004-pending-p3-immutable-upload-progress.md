---
status: pending
priority: p3
issue_id: "004"
tags: [code-review, code-quality, best-practices]
dependencies: []
---

# 🔵 P3: UploadProgress 类缺少不可变性保证

## Problem Statement

**What's nice to have:**
`lib/services/rclone_service.dart` 中的 `UploadProgress` 类所有字段都是 `final`，但缺少 `@immutable` 注解和 `copyWith` 方法，不符合 Flutter 最佳实践。

**Why it matters:**
- BLoC 模式推荐不可变状态
- 缺少 copyWith 导致状态更新繁琐
- 未来重构困难

**Impact:**
- **Severity:** 🔵 NICE-TO-HAVE (P3)
- **Code Quality:** 可维护性
- **Technical Debt:** 低

## Proposed Solutions

### Solution 1: 添加 @immutable 注解和 copyWith

```dart
import 'package:flutter/foundation.dart';

@immutable
class UploadProgress {
  final String uploadId;
  final double percent;
  final int bytesTransferred;
  final int totalBytes;
  final double speedMBps;
  final int etaSeconds;
  final UploadStatus status;
  
  const UploadProgress({  // ✅ const 构造函数
    required this.uploadId,
    required this.percent,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.speedMBps,
    required this.etaSeconds,
    required this.status,
  });
  
  // ✅ copyWith 方法
  UploadProgress copyWith({
    String? uploadId,
    double? percent,
    int? bytesTransferred,
    int? totalBytes,
    double? speedMBps,
    int? etaSeconds,
    UploadStatus? status,
  }) {
    return UploadProgress(
      uploadId: uploadId ?? this.uploadId,
      percent: percent ?? this.percent,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      speedMBps: speedMBps ?? this.speedMBps,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      status: status ?? this.status,
    );
  }
  
  // ... 其他方法
}
```

**Effort:** 🟢 Small (15 分钟)  
**Risk:** 🟢 Low

## Recommended Action

添加 `@immutable` 和 `copyWith` 方法，提升代码质量。

## Acceptance Criteria

- [ ] UploadProgress 标记为 @immutable
- [ ] 添加 copyWith 方法
- [ ] 构造函数改为 const
- [ ] 测试通过

---

**Priority Justification:** 🔵 P3 - 代码质量改进，不影响功能
