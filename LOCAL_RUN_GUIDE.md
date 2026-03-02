# 本地运行指南 🚀

本文档指导你如何在本地机器上运行 Photo Backup App。

---

## 📋 准备工作

### 1. 安装必需软件

#### Flutter SDK (必需)

```bash
# macOS/Linux
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# 验证安装
flutter doctor
```

或访问官方网站下载：https://docs.flutter.dev/get-started/install

#### Android Studio (推荐)

下载地址：https://developer.android.com/studio

**配置步骤:**
1. 安装 Android Studio
2. 打开 SDK Manager，安装:
   - Android SDK Platform 34
   - Android SDK Build-Tools 34.0.0
   - Android SDK Command-line Tools
3. 安装 Flutter 插件:
   - File > Settings > Plugins
   - 搜索 "Flutter" 并安装

#### 或者使用命令行工具

```bash
# 仅安装 Android SDK (无 IDE)
# macOS
brew install --cask android-commandlinetools

# Linux
wget https://dl.google.com/android/repository/commandlinetools-linux-latest.zip
unzip commandlinetools-linux-latest.zip
./cmdline-tools/bin/sdkmanager --install "platform-tools" "platforms;android-34"
```

---

## 🔧 项目配置

### 1. 解压项目

如果你下载了 `photo-backup-app.tar.gz`：

```bash
tar -xzf photo-backup-app.tar.gz
cd photo-backup-app
```

### 2. 安装 Flutter 依赖

```bash
flutter pub get
```

预期输出：
```
Running "flutter pub get" in photo-backup-app...
Resolving dependencies...
+ bloc 8.1.3
+ flutter_bloc 8.1.3
+ sqflite 2.3.0
...
Got dependencies!
```

### 3. 下载 rclone 二进制

#### 自动下载（推荐）

```bash
chmod +x init-project.sh
./init-project.sh
```

#### 手动下载

```bash
# 1. 下载 rclone
wget https://downloads.rclone.org/v1.65.0/rclone-v1.65.0-linux-arm64.zip

# 2. 解压
unzip rclone-v1.65.0-linux-arm64.zip

# 3. 移动到项目
mkdir -p android/app/src/main/jniLibs/arm64-v8a/
cp rclone-v1.65.0-linux-arm64/rclone android/app/src/main/jniLibs/arm64-v8a/librclone.so

# 4. 给予执行权限
chmod +x android/app/src/main/jniLibs/arm64-v8a/librclone.so
```

### 4. 连接 Android 设备

#### 使用真机（推荐）

1. 在手机上启用开发者选项:
   - 设置 > 关于手机 > 连续点击 "版本号" 7 次
   
2. 启用 USB 调试:
   - 设置 > 开发者选项 > USB 调试

3. 连接手机到电脑

4. 验证连接:
   ```bash
   flutter devices
   ```
   
   应该看到：
   ```
   1 connected device:
   
   SM G991B (mobile) • 1234567890ABCDEF • android-arm64 • Android 13 (API 33)
   ```

#### 使用模拟器

```bash
# 1. 创建模拟器
flutter emulators --create

# 2. 启动模拟器
flutter emulators --launch <emulator_id>

# 3. 验证
flutter devices
```

---

## ▶️ 运行应用

### 开发模式（Debug）

```bash
# 运行到连接的设备
flutter run

# 或指定设备
flutter run -d <device_id>
```

**热重载快捷键:**
- `r` - 热重载（保留状态）
- `R` - 热重启（清除状态）
- `q` - 退出

### 发布模式（Release）

```bash
# 构建 APK（分架构）
flutter build apk --release --split-per-abi

# 输出位置
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
```

安装到设备：
```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 🧪 测试

### 单元测试

```bash
# 运行所有测试
flutter test

# 运行特定测试
flutter test test/services/rclone_service_test.dart

# 查看覆盖率
flutter test --coverage
```

### Widget 测试

```bash
flutter test test/widget_test.dart
```

### 集成测试

```bash
# 需要连接设备
flutter test integration_test/
```

---

## 🐛 常见问题

### 1. "Gradle build failed"

**原因:** Gradle 下载依赖失败

**解决方法:**
```bash
# 清理缓存
cd android
./gradlew clean

# 重新构建
cd ..
flutter clean
flutter pub get
flutter run
```

### 2. "SDK location not found"

**原因:** Android SDK 路径未配置

**解决方法:**
创建 `android/local.properties`:
```properties
sdk.dir=/path/to/Android/Sdk
flutter.sdk=/path/to/flutter
```

### 3. "rclone binary not found"

**原因:** rclone 文件缺失或路径错误

**解决方法:**
```bash
# 检查文件
ls -l android/app/src/main/jniLibs/arm64-v8a/librclone.so

# 重新下载
./init-project.sh
```

### 4. "Permission denied" 执行 rclone

**原因:** 文件权限不足

**解决方法:**
```bash
chmod +x android/app/src/main/jniLibs/arm64-v8a/librclone.so
```

### 5. 模拟器运行卡顿

**原因:** 硬件加速未启用

**解决方法:**
- 确保 BIOS 中启用了虚拟化（VT-x/AMD-V）
- 使用真机测试（性能更好）

---

## 📊 性能优化

### 构建优化 APK

```bash
# 1. 启用混淆和资源压缩
flutter build apk --release --obfuscate --split-debug-info=build/symbols

# 2. 减小体积（按架构分包）
flutter build apk --release --split-per-abi

# 3. 构建 App Bundle（推荐 Play Store）
flutter build appbundle --release
```

### 分析包大小

```bash
# 查看 APK 内容
flutter build apk --analyze-size

# 输出
# ┌───────────────────────────────────────┬──────────────┐
# │ Library                               │ Size (bytes) │
# ├───────────────────────────────────────┼──────────────┤
# │ librclone.so                          │   14,234,567 │
# │ libflutter.so                         │    3,456,789 │
# │ ...                                   │          ... │
# └───────────────────────────────────────┴──────────────┘
```

---

## 🔍 调试技巧

### 1. 查看日志

```bash
# Flutter 日志
flutter logs

# Android Logcat
adb logcat | grep "PhotoBackup"

# 过滤错误
adb logcat *:E
```

### 2. 调试 Native 代码

在 Android Studio 中：
1. 打开 `android/` 文件夹
2. 在 Kotlin 文件中设置断点
3. Run > Debug 'app'

### 3. 查看数据库

```bash
# 1. 进入设备 shell
adb shell

# 2. 切换到应用数据目录
cd /data/data/com.example.photo_backup_app/databases/

# 3. 查看数据库
sqlite3 upload_queue.db
sqlite> .tables
sqlite> SELECT * FROM upload_tasks;
```

### 4. 性能分析

```bash
# 启用性能追踪
flutter run --profile

# 在 DevTools 中查看
flutter pub global activate devtools
flutter pub global run devtools
```

---

## 📱 设备兼容性测试

### 推荐测试矩阵

| 设备类型 | Android 版本 | 架构 | 优先级 |
|---------|-------------|------|--------|
| 真机 (Samsung/Xiaomi) | 11-14 | ARM64 | P0 |
| Google Pixel | 13+ | ARM64 | P1 |
| 模拟器 | 11 | x86_64 | P2 |
| 老旧设备 | 10 | ARMv7 | P2 |

### 测试检查清单

- [ ] 照片选择功能
- [ ] 权限请求
- [ ] 网络连接测试
- [ ] 上传进度显示
- [ ] 取消上传
- [ ] 应用后台运行
- [ ] 设备旋转
- [ ] 低内存场景
- [ ] 网络切换（WiFi ↔ 4G）

---

## 🚀 持续集成（可选）

### GitHub Actions 示例

创建 `.github/workflows/flutter.yml`:

```yaml
name: Flutter CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test
      
      - name: Build APK
        run: flutter build apk --release --split-per-abi
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: apk-release
          path: build/app/outputs/flutter-apk/*.apk
```

---

## 📚 更多资源

- **Flutter 文档:** https://docs.flutter.dev
- **Dart 语言:** https://dart.dev
- **BLoC Pattern:** https://bloclibrary.dev
- **rclone 文档:** https://rclone.org/docs
- **Android 开发:** https://developer.android.com

---

## 💡 下一步

1. ✅ 运行应用并测试基本功能
2. ✅ 配置你的 NAS 连接
3. ✅ 尝试上传照片
4. 🔨 根据需求自定义功能
5. 🐛 报告 Bug 或提交改进建议

---

**祝你使用愉快！** 🎉

如有问题，请查看 [FAQ](README.md#-常见问题) 或提交 Issue。
