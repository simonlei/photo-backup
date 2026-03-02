---
status: pending
priority: p1
issue_id: "001"
tags: [code-review, security, data-loss]
dependencies: []
---

# 🔴 P1: rclone 进程 PID 文件无竞态保护

## Problem Statement

**What's broken:**
`RcloneProcessManager.kt` 中的 PID 文件读写操作缺乏同步机制，在并发场景下可能导致数据损坏或 PID 丢失。

**Why it matters:**
- PID 丢失会导致僵尸进程无法清理，浪费系统资源
- 数据竞态可能导致 PID 文件损坏，造成进程泄漏
- 在快速连续上传场景下（用户批量选择照片）风险较高

**Impact:**
- **Severity:** 🔴 CRITICAL (P1)
- **Affected Users:** 所有用户
- **Frequency:** 批量上传时必现
- **Data Loss Risk:** 是（PID 数据可能丢失）

## Findings

### Code Location

**File:** `android/RcloneProcessManager.kt`  
**Lines:** 155-170, 173-189

```kotlin
// ❌ 问题代码：无同步保护的文件操作
private fun savePid(pid: Long) {
    try {
        pidFile.appendText("$pid\n")  // ⚠️ 竞态条件
    } catch (e: Exception) {
        Log.e(TAG, "Failed to save PID: $pid", e)
    }
}

private fun removePid(pid: Long) {
    try {
        if (!pidFile.exists()) return
        
        val pids = pidFile.readLines()  // ⚠️ 读取
            .filter { it != pid.toString() }
        
        if (pids.isEmpty()) {
            pidFile.delete()
        } else {
            pidFile.writeText(pids.joinToString("\n") + "\n")  // ⚠️ 写入
        }
    } catch (e: Exception) {
        Log.e(TAG, "Failed to remove PID: $pid", e)
    }
}
```

### Vulnerability Details

**竞态场景:**
1. 线程 A 读取 PID 文件（包含 PID 100, 200）
2. 线程 B 同时读取 PID 文件（包含 PID 100, 200）
3. 线程 A 移除 PID 100，写入（PID 200）
4. 线程 B 移除 PID 200，写入（PID 100）
5. **结果:** PID 200 丢失，无法清理僵尸进程

**复现步骤:**
```kotlin
// 模拟并发操作
thread { processManager.startUpload("upload1", ...) }
thread { processManager.startUpload("upload2", ...) }
thread { processManager.cancelUpload("upload1") }
```

### Evidence

- ✅ 无 `synchronized` 块保护
- ✅ 无文件锁机制（FileLock）
- ✅ 无原子操作保证
- ⚠️ `appendText()` 和 `writeText()` 非线程安全

## Proposed Solutions

### Solution 1: 添加同步锁（推荐）

**Approach:**
使用 Kotlin 的 `synchronized` 关键字保护 PID 文件操作。

**Implementation:**
```kotlin
class RcloneProcessManager(private val context: Context) {
    private val pidFileLock = Any()  // 锁对象
    
    private fun savePid(pid: Long) {
        synchronized(pidFileLock) {
            try {
                pidFile.appendText("$pid\n")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save PID: $pid", e)
            }
        }
    }
    
    private fun removePid(pid: Long) {
        synchronized(pidFileLock) {
            try {
                if (!pidFile.exists()) return
                
                val pids = pidFile.readLines()
                    .filter { it != pid.toString() }
                
                if (pids.isEmpty()) {
                    pidFile.delete()
                } else {
                    pidFile.writeText(pids.joinToString("\n") + "\n")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to remove PID: $pid", e)
            }
        }
    }
}
```

**Pros:**
- ✅ 简单直接，易于理解
- ✅ 零依赖，不需要新增库
- ✅ 性能开销极小

**Cons:**
- ⚠️ 仅保护单进程内的并发，不保护多进程
- ⚠️ 阻塞式等待

**Effort:** 🟢 Small (15 分钟)  
**Risk:** 🟢 Low  
**Test:** 编写并发测试验证

---

### Solution 2: 使用 FileLock（更安全）

**Approach:**
使用 Java NIO 的 `FileLock` 实现跨进程文件锁。

**Implementation:**
```kotlin
import java.nio.channels.FileChannel
import java.nio.channels.FileLock
import java.nio.file.StandardOpenOption

class RcloneProcessManager(private val context: Context) {
    
    private fun <T> withFileLock(block: () -> T): T {
        val channel = FileChannel.open(
            pidFile.toPath(),
            StandardOpenOption.CREATE,
            StandardOpenOption.WRITE,
            StandardOpenOption.READ
        )
        
        return channel.use { ch ->
            val lock = ch.lock()  // 阻塞直到获取锁
            try {
                block()
            } finally {
                lock.release()
            }
        }
    }
    
    private fun savePid(pid: Long) {
        withFileLock {
            try {
                pidFile.appendText("$pid\n")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save PID: $pid", e)
            }
        }
    }
    
    private fun removePid(pid: Long) {
        withFileLock {
            try {
                if (!pidFile.exists()) return@withFileLock
                
                val pids = pidFile.readLines()
                    .filter { it != pid.toString() }
                
                if (pids.isEmpty()) {
                    pidFile.delete()
                } else {
                    pidFile.writeText(pids.joinToString("\n") + "\n")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to remove PID: $pid", e)
            }
        }
    }
}
```

**Pros:**
- ✅ 跨进程安全（即使多个 App 实例）
- ✅ 标准 Java NIO API
- ✅ 适用于多进程应用

**Cons:**
- ⚠️ 代码稍复杂
- ⚠️ 需要处理 IOException

**Effort:** 🟡 Medium (30 分钟)  
**Risk:** 🟡 Medium  
**Test:** 编写并发 + 多进程测试

---

### Solution 3: 使用 SQLite 替代文件（过度工程）

**Approach:**
将 PID 存储在 SQLite 数据库，利用数据库事务保证原子性。

**Pros:**
- ✅ 数据库天然支持并发
- ✅ ACID 保证
- ✅ 可扩展存储更多信息

**Cons:**
- ❌ 过度工程，杀鸡用牛刀
- ❌ 增加依赖和复杂度
- ❌ 性能开销大

**Effort:** 🔴 Large (2 小时)  
**Risk:** 🔴 High  
**Recommendation:** ❌ 不推荐

## Recommended Action

**选择 Solution 1（同步锁）**，原因：
1. 最简单有效的解决方案
2. 符合当前单进程架构
3. 性能影响可忽略
4. 易于测试和维护

**如果未来需要多进程支持，升级到 Solution 2（FileLock）**

## Technical Details

### Affected Files
- `android/RcloneProcessManager.kt` (Lines 155-189)

### Database/Storage Changes
- 无数据库变更
- 修改本地文件操作逻辑

### API Changes
- 无公共 API 变更
- 内部实现优化

### Dependencies
- 无新增依赖

## Acceptance Criteria

- [ ] PID 文件操作加锁保护
- [ ] 编写并发测试（10+ 线程同时操作）
- [ ] 验证无 PID 丢失（运行 1000 次测试）
- [ ] 验证僵尸进程清理功能正常
- [ ] Code Review 通过
- [ ] 无性能回归（<5% 延迟增加）

### Testing Checklist

```kotlin
// 单元测试
@Test
fun testConcurrentPidOperations() {
    val latch = CountDownLatch(100)
    val manager = RcloneProcessManager(context)
    
    repeat(100) { i ->
        thread {
            manager.startUpload("upload_$i", ...)
            manager.cancelUpload("upload_$i")
            latch.countDown()
        }
    }
    
    latch.await(30, TimeUnit.SECONDS)
    
    // 验证 PID 文件一致性
    val savedPids = pidFile.readLines()
    assertEquals(0, savedPids.size)
}
```

## Work Log

### 2026-03-02 - Issue Identified
- **Action:** Code review 发现竞态条件
- **Evidence:** 并发操作时 PID 文件可能损坏
- **Next:** 选择解决方案并实施

---

### [Future Date] - Implementation
- **Action:** [To be filled during work]
- **Changes:** [File paths and code changes]
- **Testing:** [Test results]

## Resources

### Related Documentation
- [Kotlin Synchronization](https://kotlinlang.org/docs/synchronized.html)
- [Java FileLock](https://docs.oracle.com/javase/8/docs/api/java/nio/channels/FileLock.html)
- [Android Thread Safety](https://developer.android.com/guide/components/processes-and-threads)

### Similar Issues
- None in current codebase

### Related PRs/Issues
- N/A (new codebase)

---

**Priority Justification:**
🔴 P1 因为：
1. 数据损坏风险
2. 僵尸进程泄漏影响系统资源
3. 批量上传场景下必现
4. 修复简单，收益巨大
