# 🚀 快速开始 - 5 分钟运行 Photo Backup App

## 📥 第 1 步：获取项目

```bash
# 下载并解压
tar -xzf photo-backup-app.tar.gz
cd photo-backup-app
```

---

## ⚙️ 第 2 步：安装依赖

```bash
# 确保已安装 Flutter (https://flutter.dev)
flutter --version

# 安装项目依赖
flutter pub get
```

---

## 📲 第 3 步：准备 rclone

```bash
# 运行自动下载脚本
chmod +x init-project.sh
./init-project.sh

# 或手动下载
wget https://downloads.rclone.org/v1.65.0/rclone-v1.65.0-linux-arm64.zip
unzip rclone-*.zip
mkdir -p android/app/src/main/jniLibs/arm64-v8a/
cp rclone-*/rclone android/app/src/main/jniLibs/arm64-v8a/librclone.so
chmod +x android/app/src/main/jniLibs/arm64-v8a/librclone.so
```

---

## 📱 第 4 步：连接设备

### 使用真机（推荐）

```bash
# 1. 在手机上启用 USB 调试
# 设置 > 关于手机 > 点击"版本号" 7 次
# 设置 > 开发者选项 > USB 调试

# 2. 连接手机到电脑

# 3. 验证连接
flutter devices
```

### 使用模拟器

```bash
# 启动模拟器
flutter emulators --launch <emulator_id>

# 验证
flutter devices
```

---

## ▶️ 第 5 步：运行应用

### 开发模式

```bash
flutter run
```

### 发布模式（生成 APK）

```bash
# 构建 APK
flutter build apk --release --split-per-abi

# 安装到设备
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 🎯 第 6 步：配置 NAS

1. 打开应用
2. 进入 **设置** 页面
3. 输入你的 NAS 信息：
   - **URL:** `http://你的NAS地址:端口`
   - **用户名:** 你的账号
   - **密码:** 你的密码
4. 点击 **测试连接**
5. 成功后返回主页

---

## 📸 第 7 步：上传照片

1. 点击 **选择照片** 按钮
2. 从相册选择照片
3. 查看上传进度
4. 完成！✅

---

## ❓ 遇到问题？

### "Flutter command not found"
```bash
# 安装 Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
```

### "No devices found"
- 检查 USB 线缆连接
- 确认已启用 USB 调试
- 运行 `adb devices` 检查

### "rclone binary not found"
```bash
# 重新运行初始化脚本
./init-project.sh
```

### 更多帮助
- 📖 查看 [README.md](README.md)
- 📚 阅读 [LOCAL_RUN_GUIDE.md](LOCAL_RUN_GUIDE.md)
- 📋 检查 [CODE_VERIFICATION_REPORT.md](CODE_VERIFICATION_REPORT.md)

---

## 📚 完整文档

| 文档 | 内容 |
|------|------|
| [README.md](README.md) | 功能介绍、NAS 配置指南 |
| [LOCAL_RUN_GUIDE.md](LOCAL_RUN_GUIDE.md) | 详细运行和调试指南 |
| [DELIVERY_CHECKLIST.md](DELIVERY_CHECKLIST.md) | 项目交付清单 |
| [CODE_VERIFICATION_REPORT.md](CODE_VERIFICATION_REPORT.md) | 代码质量报告 |

---

**就这么简单！享受你的照片备份之旅！** 🎉

如有问题，欢迎提交 Issue 或联系支持。
