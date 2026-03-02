# 📦 构建指南 - Build Guide

本文档说明如何构建 Photo Backup App 的 release APK。

---

## 🛠️ 构建环境要求

### 必需工具

1. **Flutter SDK** (>= 3.0.0)
   - 安装指南: https://flutter.dev/docs/get-started/install
   - 验证安装: `flutter doctor`

2. **Android Studio** 或 **Android SDK**
   - Android SDK Platform 34
   - Android SDK Build-Tools 34.0.0
   - Android NDK 25.1.8937393

3. **Git**
   - 用于克隆仓库

4. **Bash** 或兼容 Shell
   - 用于运行构建脚本

---

## 🚀 快速构建（3 分钟）

### 方法 1：使用构建脚本（推荐）

```bash
# 1. 克隆仓库
git clone https://github.com/simonlei/photo-backup.git
cd photo-backup

# 2. 运行构建脚本
bash build-release.sh
```

脚本会自动：
- ✅ 清理旧构建
- ✅ 获取依赖
- ✅ 下载 rclone 二进制
- ✅ 构建分架构 APK
- ✅ 显示文件大小和校验和

---

### 方法 2：手动构建

```bash
# 1. 清理
flutter clean

# 2. 获取依赖
flutter pub get

# 3. 初始化项目（下载 rclone）
bash init-project.sh

# 4. 构建 APK（分架构）
flutter build apk --release --split-per-abi
```

---

## 📦 输出文件

构建完成后，APK 文件位于：

```
build/app/outputs/flutter-apk/
├── app-arm64-v8a-release.apk       # ARM64 设备（推荐）
├── app-armeabi-v7a-release.apk     # ARMv7 设备（旧设备）
└── app-release.apk                 # 通用版本（包含所有架构）
```

### 架构说明

| 文件 | 架构 | 适用设备 | 推荐 |
|------|------|----------|------|
| `app-arm64-v8a-release.apk` | ARM64 | 2017年后大部分 Android 设备 | ✅ 首选 |
| `app-armeabi-v7a-release.apk` | ARMv7 | 旧款 Android 设备 | ⚠️ 兼容 |
| `app-release.apk` | 通用 | 所有设备（体积大） | ⚠️ 备用 |

---

## 🔍 验证构建

### 1. 检查文件大小

```bash
ls -lh build/app/outputs/flutter-apk/*.apk
```

预期大小：
- ARM64: ~15-25 MB
- ARMv7: ~15-25 MB

### 2. 计算 SHA256

```bash
sha256sum build/app/outputs/flutter-apk/app-*-release.apk
```

### 3. 查看 APK 信息

```bash
# 使用 aapt (Android SDK 工具)
aapt dump badging build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep -E "package|sdkVersion|versionCode"
```

---

## 📱 安装测试

### 方法 1：通过 ADB

```bash
# 连接设备并启用 USB 调试
adb devices

# 安装 APK
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### 方法 2：手动安装

1. 将 APK 文件传输到设备
2. 在设备上打开文件管理器
3. 点击 APK 文件并安装
4. （可能需要在设置中允许"未知来源"）

---

## ⚙️ 构建配置

### build.gradle 配置

```gradle
buildTypes {
    release {
        signingConfig signingConfigs.debug  // ⚠️ 仅用于测试
        minifyEnabled true                  // ✅ 启用代码混淆
        shrinkResources true                // ✅ 启用资源压缩
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

### 签名配置（生产环境）

⚠️ **警告：当前使用 debug 签名，仅供开发测试！**

生产环境发布前，需要：

1. 生成 keystore
2. 配置 `android/key.properties`
3. 修改 `build.gradle` 使用 release 签名

详见：https://docs.flutter.dev/deployment/android#signing-the-app

---

## 🐛 常见问题

### 问题 1：`flutter: command not found`

**解决：**
```bash
# 检查 Flutter 是否在 PATH
echo $PATH

# 添加 Flutter 到 PATH（macOS/Linux）
export PATH="$PATH:/path/to/flutter/bin"

# 或永久添加到 ~/.bashrc 或 ~/.zshrc
```

### 问题 2：`Android SDK not found`

**解决：**
```bash
flutter doctor

# 安装 Android Studio 并配置 SDK 路径
flutter config --android-sdk /path/to/android/sdk
```

### 问题 3：`rclone binary not found`

**解决：**
```bash
# 运行 init 脚本
bash init-project.sh

# 或手动下载
# 详见 init-project.sh 中的 URL
```

### 问题 4：构建失败 - `OutOfMemoryError`

**解决：**
```bash
# 增加 Gradle 内存
export GRADLE_OPTS="-Xmx4096m"

# 或修改 android/gradle.properties
org.gradle.jvmargs=-Xmx4096m
```

### 问题 5：APK 安装失败

**原因：**
- 签名不匹配（已安装旧版本）
- 设备架构不兼容

**解决：**
```bash
# 卸载旧版本
adb uninstall com.example.photo_backup_app

# 或使用通用版本 APK
flutter build apk --release
```

---

## 📊 构建优化

### 减小 APK 体积

1. **启用混淆和压缩**（已配置）
   ```gradle
   minifyEnabled true
   shrinkResources true
   ```

2. **分架构打包**（已配置）
   ```gradle
   ndk {
       abiFilters 'arm64-v8a', 'armeabi-v7a'
   }
   ```

3. **移除未使用资源**
   ```bash
   flutter build apk --release --split-per-abi --tree-shake-icons
   ```

### 加速构建

```bash
# 使用缓存
flutter build apk --release --no-shrink

# 跳过测试
flutter build apk --release --no-test
```

---

## 🔐 生产环境签名

**⚠️ 重要：发布前必须使用生产签名！**

### 1. 生成 keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### 2. 创建 key.properties

```properties
storePassword=<密码>
keyPassword=<密码>
keyAlias=upload
storeFile=<keystore 文件路径>
```

### 3. 修改 build.gradle

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

---

## 📝 发布检查清单

- [ ] 代码已提交到 Git
- [ ] 版本号已更新（pubspec.yaml）
- [ ] 使用生产签名
- [ ] 所有测试通过
- [ ] APK 体积合理（< 30 MB）
- [ ] 在真实设备上测试
- [ ] 检查权限声明
- [ ] 更新 CHANGELOG
- [ ] 创建 GitHub Release
- [ ] 上传 APK 到 Release

---

## 📚 相关文档

- [Flutter 官方构建文档](https://docs.flutter.dev/deployment/android)
- [Android App Bundle 指南](https://developer.android.com/guide/app-bundle)
- [ProGuard 配置](https://developer.android.com/studio/build/shrink-code)
- [签名配置](https://docs.flutter.dev/deployment/android#signing-the-app)

---

## 💡 提示

1. **首次构建**可能需要下载依赖（5-10 分钟）
2. **后续构建**约 2-3 分钟
3. **使用 `--split-per-abi`** 可减小 50% 体积
4. **生产环境**务必使用正式签名
5. **建议**在 CI/CD 中自动化构建流程

---

有问题？提交 Issue: https://github.com/simonlei/photo-backup/issues
