#!/bin/bash

# Download rclone binary for Android
# Used in CI/CD and local builds

set -e

echo "📦 下载 rclone 二进制文件..."

RCLONE_VERSION="1.65.0"
TARGET_DIR="android/app/src/main/jniLibs"

# 创建目录
mkdir -p "$TARGET_DIR/arm64-v8a"
mkdir -p "$TARGET_DIR/armeabi-v7a"

# 下载 ARM64 版本
echo "⬇️  下载 ARM64 版本..."
curl -L "https://github.com/rclone/rclone/releases/download/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-linux-arm64.zip" -o /tmp/rclone-arm64.zip
unzip -q /tmp/rclone-arm64.zip -d /tmp/
cp "/tmp/rclone-v${RCLONE_VERSION}-linux-arm64/rclone" "$TARGET_DIR/arm64-v8a/librclone.so"
chmod +x "$TARGET_DIR/arm64-v8a/librclone.so"
echo "✅ ARM64 版本已安装"

# 下载 ARMv7 版本
echo "⬇️  下载 ARMv7 版本..."
curl -L "https://github.com/rclone/rclone/releases/download/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-linux-arm-v7.zip" -o /tmp/rclone-armv7.zip
unzip -q /tmp/rclone-armv7.zip -d /tmp/
cp "/tmp/rclone-v${RCLONE_VERSION}-linux-arm-v7/rclone" "$TARGET_DIR/armeabi-v7a/librclone.so"
chmod +x "$TARGET_DIR/armeabi-v7a/librclone.so"
echo "✅ ARMv7 版本已安装"

# 清理临时文件
rm -rf /tmp/rclone-*.zip
rm -rf /tmp/rclone-v*

echo ""
echo "✅ rclone 二进制文件下载完成"
echo ""
echo "📁 文件位置:"
ls -lh "$TARGET_DIR/arm64-v8a/librclone.so"
ls -lh "$TARGET_DIR/armeabi-v7a/librclone.so"
