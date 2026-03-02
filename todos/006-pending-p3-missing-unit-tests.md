---
status: pending
priority: p3
issue_id: "006"
tags: [code-review, testing, quality]
dependencies: []
---

# 🔵 P3: 缺少单元测试覆盖

## Problem Statement

**What's missing:**
项目完全没有单元测试，代码覆盖率 0%，未来重构风险高。

**Why it matters:**
- 无法验证逻辑正确性
- 重构时容易引入 Bug
- 不符合工程最佳实践

**Impact:**
- **Severity:** 🔵 NICE-TO-HAVE (P3)
- **Technical Debt:** 中等
- **Maintainability:** 差

## Proposed Solutions

### Solution 1: 添加核心逻辑测试

**优先级测试文件:**
1. `test/services/rclone_service_test.dart` - Platform Channel mock
2. `test/services/upload_queue_service_test.dart` - SQLite 操作
3. `test/blocs/upload_bloc_test.dart` - BLoC 状态转换
4. `test/models/upload_task_test.dart` - 序列化测试

**示例:**
```dart
// test/services/rclone_service_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('RcloneService', () {
    test('should throw NetworkException on NETWORK_ERROR', () async {
      // Mock Platform Channel
      const channel = MethodChannel('com.example.photobackup/rclone');
      channel.setMockMethodCallHandler((call) async {
        throw PlatformException(code: 'NETWORK_ERROR');
      });
      
      final service = RcloneService();
      
      expect(
        () => service.uploadFile(...),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
```

**Effort:** 🔴 Large (4-6 小时)  
**Risk:** 🟢 Low  
**Target Coverage:** 70%+

## Recommended Action

V1.0 发布前补充核心测试，目标覆盖率 70%+。

## Acceptance Criteria

- [ ] 添加 RcloneService 测试
- [ ] 添加 UploadQueueService 测试
- [ ] 添加 UploadBloc 测试
- [ ] 代码覆盖率 >70%
- [ ] CI/CD 集成测试

---

**Priority Justification:** 🔵 P3 - 重要但不紧急，V1.0 前完成
