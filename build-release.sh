#!/bin/bash

# Photo Backup App - Release Build Script
# 用途：构建生产环境 APK

set -e  # 遇到错误立即退出

echo "🚀 Photo Backup App - Release Build"
echo "===================================="
echo ""

# 1. 检查 Flutter 环境
echo "📋 检查 Flutter 环境..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装或不在 PATH 中"
    echo "请安装 Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

flutter --version
echo ""

# 2. 清理旧构建
echo "🧹 清理旧构建..."
flutter clean
echo ""

# 3. 获取依赖
echo "📦 获取依赖..."
flutter pub get
echo ""

# 4. 运行 init 脚本（下载 rclone）
echo "🔧 初始化项目（下载 rclone）..."
if [ -f "init-project.sh" ]; then
    bash init-project.sh
else
    echo "⚠️  init-project.sh 不存在，跳过 rclone 下载"
fi
echo ""

# 5. 构建 Release APK（分架构）
echo "🔨 构建 Release APK..."
echo "   - 启用代码混淆"
echo "   - 启用资源压缩"
echo "   - 分架构打包 (ARM64 + ARMv7)"
echo ""

flutter build apk --release --split-per-abi

# 6. 输出构建结果
echo ""
echo "✅ 构建完成！"
echo "===================================="
echo ""
echo "📦 APK 文件位置："
ls -lh build/app/outputs/flutter-apk/*.apk
echo ""

# 7. 显示 APK 信息
echo "📊 APK 信息："
for apk in build/app/outputs/flutter-apk/app-*-release.apk; do
    if [ -f "$apk" ]; then
        filename=$(basename "$apk")
        size=$(du -h "$apk" | cut -f1)
        echo "   - $filename ($size)"
    fi
done
echo ""

# 8. 计算校验和
echo "🔐 SHA256 校验和："
for apk in build/app/outputs/flutter-apk/app-*-release.apk; do
    if [ -f "$apk" ]; then
        sha256sum "$apk" | awk '{print "   " $1 " " $2}'
    fi
done
echo ""

echo "🎉 构建成功！"
echo ""
echo "下一步："
echo "  1. 测试 APK: adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
echo "  2. 或手动安装到设备"
echo "  3. 创建 GitHub Release"
