# Photo Backup App - 项目结构

## 📁 目录结构

```
photo-backup-app/
├── init-project.sh              # 项目初始化脚本
├── pubspec.yaml                 # Flutter 依赖配置
├── android/
│   ├── app/
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/.../
│   │       │   ├── MainActivity.kt         # Platform Channel 入口
│   │       │   ├── RcloneProcessManager.kt # 进程管理（待生成）
│   │       │   └── ProcessCleanupJob.kt    # 定期清理任务（待生成）
│   │       └── jniLibs/
│   │           └── arm64-v8a/
│   │               └── librclone.so        # rclone 二进制（需手动下载）
│   └── build.gradle
├── lib/
│   ├── main.dart                # App 入口
│   ├── blocs/                   # BLoC 状态管理
│   │   └── upload_bloc.dart     # 上传状态（待生成）
│   ├── models/                  # 数据模型
│   │   └── upload_task.dart     # 上传任务模型（待生成）
│   ├── services/                # 业务服务
│   │   ├── rclone_service.dart  # rclone 调用封装（待生成）
│   │   ├── upload_queue_service.dart  # SQLite 队列（待生成）
│   │   └── config_service.dart  # 配置管理（待生成）
│   ├── screens/                 # 页面
│   │   ├── home_screen.dart
│   │   ├── settings_screen.dart
│   │   └── onboarding_screen.dart
│   └── widgets/                 # 组件
│       └── progress_indicator.dart
├── test/                        # 单元测试
├── integration_test/            # 集成测试
└── assets/                      # 资源文件
    ├── images/
    ├── animations/
    └── rclone/
```

---

## ✅ 已完成的文件

1. ✅ `init-project.sh` - 项目初始化脚本
2. ✅ `pubspec.yaml` - 完整依赖配置
3. ✅ `android/MainActivity.kt` - Platform Channel 框架

---

## 🔨 待生成的核心文件

### Android 层（Kotlin）

1. **RcloneProcessManager.kt** - 进程管理类
   - 启动 rclone 进程
   - PID 追踪
   - 僵尸进程清理
   - 优雅关闭

2. **ProcessCleanupJob.kt** - JobScheduler 定期清理

### Flutter 层（Dart）

3. **lib/services/rclone_service.dart** - rclone 服务封装
   - Platform Channel 调用
   - 进度流管理
   - 错误处理

4. **lib/services/upload_queue_service.dart** - 上传队列
   - SQLite 数据库
   - 并发锁保护
   - 任务持久化

5. **lib/models/upload_task.dart** - 上传任务模型

6. **lib/blocs/upload_bloc.dart** - 上传状态管理

7. **lib/screens/home_screen.dart** - 主页面

8. **lib/screens/settings_screen.dart** - 设置页面

---

## 🚀 快速开始

### 1. 运行初始化脚本

```bash
cd /root/.openclaw/workspace/photo-backup-app
chmod +x init-project.sh
./init-project.sh
```

### 2. 下载 rclone 二进制

```bash
# 访问 https://rclone.org/downloads/
# 下载 linux-arm64 版本

# 放置到项目中
mkdir -p android/app/src/main/jniLibs/arm64-v8a/
cp ~/Downloads/rclone android/app/src/main/jniLibs/arm64-v8a/librclone.so
```

### 3. 生成剩余代码文件

让 Claude Code 生成：
- RcloneProcessManager.kt
- ProcessCleanupJob.kt
- rclone_service.dart
- upload_queue_service.dart
- 等等...

---

## 📋 Phase 1 任务清单

- [x] 创建项目初始化脚本
- [x] 配置 pubspec.yaml
- [x] 创建 MainActivity.kt 框架
- [ ] 下载 rclone 二进制
- [ ] 生成 RcloneProcessManager
- [ ] 生成 ProcessCleanupJob
- [ ] 生成 Flutter 服务层代码
- [ ] 测试 Platform Channel 通信
- [ ] 测试单文件上传

---

## 🔗 相关文档

- 实现计划: `docs/plans/2026-03-02-feat-android-photo-backup-mvp-plan.md`
- P0 修复方案: `docs/fixes/p0-critical-fixes.md`
- 技术评审: 已完成
- Flutter vs 原生: `docs/decisions/flutter-vs-native-android.md`
