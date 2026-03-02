#!/bin/bash

# 容器构建脚本 - Flutter Photo Backup App
# 用于在当前环境中完整构建 APK

set -e

echo "🚀 Photo Backup App - 容器构建"
echo "====================================="
echo ""

# 检查 Flutter 是否已解压
if [ ! -d "/tmp/flutter" ]; then
    echo "❌ Flutter 未找到，请先解压"
    exit 1
fi

# 设置环境变量
export PATH="/tmp/flutter/bin:$PATH"
export PUB_CACHE="/tmp/.pub-cache"

echo "📋 环境信息："
echo "  Flutter: $(flutter --version | head -1)"
echo "  工作目录: $(pwd)"
echo ""

# 切换到项目目录
cd /root/.openclaw/workspace/photo-backup-app

echo "🧹 清理旧构建..."
flutter clean || true
echo ""

echo "📦 获取依赖..."
flutter pub get
echo ""

echo "🔧 下载 rclone 二进制..."
bash download-rclone.sh
echo ""

echo "🔨 构建 APK (分架构)..."
flutter build apk --release --split-per-abi
echo ""

echo "✅ 构建完成！"
echo "====================================="
echo ""

echo "📦 APK 文件："
ls -lh build/app/outputs/flutter-apk/*.apk
echo ""

echo "🔐 SHA256 校验和："
sha256sum build/app/outputs/flutter-apk/*.apk
echo ""

echo "🎉 容器构建成功！"
