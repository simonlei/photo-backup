<div align="center">

# 📸 Photo Backup App

**隐私优先的照片备份应用 - 直连 NAS 和云存储，无需中间服务器**

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-5.0+-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://www.android.com)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)
[![Stars](https://img.shields.io/github/stars/simonlei/photo-backup?style=for-the-badge)](https://github.com/simonlei/photo-backup/stargazers)

[🚀 快速开始](QUICKSTART.md) • [📖 文档](LOCAL_RUN_GUIDE.md) • [🐛 反馈问题](https://github.com/simonlei/photo-backup/issues)

</div>

---

## ✨ 特性

- 📸 **手动照片选择** - 从相册选择照片上传
- 🏠 **NAS 支持** - 兼容 WebDAV 协议（Synology、QNAP 等）
- 🔒 **隐私优先** - 直接上传，无中间服务器
- 📊 **实时进度** - 显示上传速度和预计时间
- ♻️ **自动重试** - 处理网络中断
- 🎨 **Material Design 3** - 现代化的 UI 设计
- 🔋 **后台上传** - 支持应用后台运行时继续上传

---

## 🚀 快速开始

### 前置要求

- **Android:** 10+ (API 29+)
- **NAS:** 支持 WebDAV 协议的设备
- **Flutter:** 3.0+ (仅开发需要)

### 安装步骤

#### 方法 1: 直接安装 APK（推荐）

1. 下载最新的 APK 文件：
   ```bash
   # 根据你的设备选择对应的 APK
   # ARM64 (大多数现代设备)
   photo-backup-app-arm64-v8a-release.apk
   
   # ARMv7 (老旧 32 位设备)
   photo-backup-app-armeabi-v7a-release.apk
   ```

2. 在手机上安装 APK
3. 首次打开时按照设置向导配置

#### 方法 2: 从源码构建

```bash
# 1. 克隆项目
cd photo-backup-app

# 2. 安装依赖
flutter pub get

# 3. 运行初始化脚本（下载 rclone 二进制）
chmod +x init-project.sh
./init-project.sh

# 4. 连接 Android 设备或启动模拟器
flutter devices

# 5. 运行应用
flutter run

# 6. 构建 Release APK
flutter build apk --release --split-per-abi
```

---

## 📖 使用指南

### 1. 首次配置

打开应用后，进入 **设置页面** 配置 NAS 连接：

1. **NAS URL**: `https://你的NAS地址:端口`
   - 示例: `https://nas.example.com:5005`
   - 或局域网: `http://192.168.1.100:5005`

2. **用户名**: 你的 NAS 账号

3. **密码**: 你的 NAS 密码

4. **远程路径**: 上传到的目标文件夹
   - 示例: `/photos/backup`

5. 点击 **测试连接** 验证配置

### 2. 上传照片

1. 在主页点击 **选择照片** 按钮
2. 从相册选择要备份的照片（可多选）
3. 确认后自动开始上传
4. 查看上传进度和速度

### 3. 查看历史记录

- 在主页向下滚动查看上传历史
- 绿色 ✅ = 上传成功
- 红色 ❌ = 上传失败（可点击重试）
- 蓝色 ↻ = 上传中

---

## 🔧 NAS 配置指南

### Synology NAS

1. 登录 DSM 控制面板
2. 进入 **控制面板 > 文件服务 > WebDAV**
3. 启用 WebDAV 服务
4. 记录端口号（默认 HTTP: 5005, HTTPS: 5006）
5. 在应用中使用: `http://你的NAS_IP:5005`

### QNAP NAS

1. 登录 QTS 管理界面
2. 进入 **控制台 > 网络服务 > WebDAV**
3. 启用 WebDAV 服务器
4. 默认端口: HTTP 8080, HTTPS 443
5. 在应用中使用: `http://你的NAS_IP:8080`

### 群晖/TrueNAS/其他

参考设备的 WebDAV 配置文档，通常在：
- 网络服务 / Network Services
- 文件共享 / File Sharing
- WebDAV 协议设置

---

## ❓ 常见问题

### 1. "认证失败" 错误

**原因:**
- 用户名或密码错误
- WebDAV 服务未启用
- 权限不足

**解决方法:**
- 检查 NAS 账号和密码
- 确认 WebDAV 服务已启动
- 在浏览器中测试访问 `http://NAS地址:端口/`
- 确保用户有目标文件夹的写入权限

### 2. "网络错误" 提示

**原因:**
- 手机未连接到 WiFi
- NAS 不在同一局域网
- 防火墙阻止

**解决方法:**
- 确认手机和 NAS 在同一网络
- 尝试 ping NAS IP 地址
- 检查 NAS 防火墙设置
- 尝试使用 HTTP 而非 HTTPS

### 3. 上传超时

**原因:**
- 网络速度慢
- 文件过大
- NAS 性能不足

**解决方法:**
- 减少单次上传的照片数量
- 使用更快的 WiFi 网络
- 在设置中增加超时时间（默认 30 分钟）

### 4. 上传后应用崩溃

**原因:**
- 内存不足
- rclone 进程异常

**解决方法:**
- 重启应用
- 清理手机内存
- 查看日志文件（设置 > 日志）

### 5. 某些照片无法上传

**原因:**
- 文件格式不支持
- 存储权限不足

**解决方法:**
- 检查照片格式（支持 JPG, PNG, HEIC 等）
- 在系统设置中授予存储权限
- 重新选择照片

---

## 🗺️ 路线图

- [x] **MVP** (Week 1-4): 手动上传到 NAS
- [ ] **V0.5** (Week 5-6): WiFi 自动备份
- [ ] **V1.0** (Week 7-10): 云存储支持（阿里云盘、百度网盘）
- [ ] **V1.5** (Week 11-14): 家庭共享
- [ ] **V2.0** (Week 15+): AI 照片标签

---

## 🛠️ 技术栈

- **前端**: Flutter 3.0 + Dart
- **状态管理**: BLoC Pattern
- **本地数据库**: SQLite (sqflite)
- **上传引擎**: rclone (ARM64 原生)
- **平台通信**: Platform Channel (Kotlin ↔ Dart)

### 架构图

```
┌─────────────────────────────────┐
│      Flutter App (Dart)         │
│   ┌─────────────────────────┐   │
│   │  UI Layer (Screens)     │   │
│   └──────────┬──────────────┘   │
│   ┌──────────▼──────────────┐   │
│   │  BLoC (State Management)│   │
│   └──────────┬──────────────┘   │
│   ┌──────────▼──────────────┐   │
│   │  Services (Business)    │   │
│   └──────────┬──────────────┘   │
│   ┌──────────▼──────────────┐   │
│   │  Platform Channel       │   │
│   └──────────┬──────────────┘   │
└──────────────┼───────────────────┘
               │
┌──────────────▼───────────────────┐
│    Android Native (Kotlin)       │
│   ┌─────────────────────────┐   │
│   │  RcloneProcessManager   │   │
│   └──────────┬──────────────┘   │
│   ┌──────────▼──────────────┐   │
│   │  rclone Binary (ARM64)  │   │
│   └──────────┬──────────────┘   │
└──────────────┼───────────────────┘
               │
┌──────────────▼───────────────────┐
│          NAS (WebDAV)            │
└──────────────────────────────────┘
```

---

## 👨‍💻 开发指南

### 环境准备

```bash
# 1. 安装 Flutter
# https://docs.flutter.dev/get-started/install

# 2. 克隆项目
git clone https://github.com/yourusername/photo-backup-app.git
cd photo-backup-app

# 3. 安装依赖
flutter pub get

# 4. 检查环境
flutter doctor
```

### 项目结构

```
photo-backup-app/
├── android/                    # Android 原生代码
│   ├── app/
│   │   ├── src/main/kotlin/
│   │   │   └── com/example/photo_backup_app/
│   │   │       ├── MainActivity.kt
│   │   │       ├── RcloneProcessManager.kt
│   │   │       └── ProcessCleanupJob.kt
│   │   ├── build.gradle
│   │   └── AndroidManifest.xml
│   └── build.gradle
├── lib/                        # Flutter/Dart 代码
│   ├── main.dart              # 应用入口
│   ├── models/                # 数据模型
│   │   └── upload_task.dart
│   ├── services/              # 服务层
│   │   ├── rclone_service.dart
│   │   └── upload_queue_service.dart
│   ├── blocs/                 # 状态管理
│   │   └── upload_bloc.dart
│   └── screens/               # UI 页面
│       ├── home_screen.dart
│       └── settings_screen.dart
├── assets/                     # 资源文件
│   └── rclone/                # rclone 二进制
├── test/                       # 单元测试
├── pubspec.yaml               # 依赖配置
└── README.md                  # 项目文档
```

### 构建 APK

详细构建指南请参考 **[BUILD_GUIDE.md](BUILD_GUIDE.md)**

**快速构建：**

```bash
# 方法 1: 使用脚本（推荐）
bash build-release.sh

# 方法 2: 手动构建
flutter clean
flutter pub get
bash init-project.sh
flutter build apk --release --split-per-abi
```

**输出位置：**
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`

### 运行测试

```bash
# 单元测试
flutter test

# Widget 测试
flutter test test/widget_test.dart

# 集成测试（需要设备）
flutter test integration_test/
```

### 调试技巧

1. **查看日志:**
   ```bash
   flutter logs
   # 或
   adb logcat | grep "PhotoBackup"
   ```

2. **调试 Platform Channel:**
   - Dart 端: 在 `rclone_service.dart` 添加断点
   - Kotlin 端: 在 Android Studio 中调试

3. **查看数据库:**
   ```bash
   adb shell
   cd /data/data/com.example.photo_backup_app/databases/
   sqlite3 upload_queue.db
   ```

---

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

### 提交规范

- `feat:` 新功能
- `fix:` Bug 修复
- `docs:` 文档更新
- `style:` 代码格式
- `refactor:` 重构
- `test:` 测试相关
- `chore:` 构建/工具相关

示例:
```
feat: 添加照片压缩功能
fix: 修复网络切换时上传中断的问题
docs: 更新 NAS 配置指南
```

---

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

## 📧 联系方式

- 🐛 [报告 Bug](https://github.com/yourusername/photo-backup-app/issues)
- 💬 [功能建议](https://github.com/yourusername/photo-backup-app/discussions)
- 📧 Email: support@example.com

---

## 🙏 致谢

- [Flutter](https://flutter.dev) - 跨平台 UI 框架
- [rclone](https://rclone.org) - 强大的云同步工具
- [BLoC Library](https://bloclibrary.dev) - 状态管理库

---

## ⭐ Star History

如果这个项目对你有帮助，请给个 Star ⭐ 支持一下！

---

**Made with ❤️ by the Photo Backup Team**
