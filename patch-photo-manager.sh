#!/bin/bash

# 修补 photo_manager 插件的 build.gradle
# 添加缺失的 androidx.core:core-ktx 依赖

set -e

echo "🔧 修补 photo_manager 插件..."

# 查找 photo_manager 路径
PM_PATH=$(flutter pub global run find_plugin photo_manager 2>/dev/null || find ~/.pub-cache -name "photo_manager-*" -type d 2>/dev/null | head -1 || find /tmp/.pub-cache -name "photo_manager-*" -type d 2>/dev/null | head -1)

if [ -z "$PM_PATH" ]; then
    echo "❌ 找不到 photo_manager 插件"
    exit 1
fi

BUILD_GRADLE="$PM_PATH/android/build.gradle"

if [ ! -f "$BUILD_GRADLE" ]; then
    echo "❌ 找不到 build.gradle: $BUILD_GRADLE"
    exit 1
fi

# 检查是否已经添加
if grep -q "androidx.core:core-ktx" "$BUILD_GRADLE"; then
    echo "✅ core-ktx 依赖已存在"
    exit 0
fi

# 备份
cp "$BUILD_GRADLE" "$BUILD_GRADLE.bak"

# 添加依赖
sed -i "/implementation 'com.github.bumptech.glide:glide:/a\\    implementation 'androidx.core:core-ktx:1.12.0'" "$BUILD_GRADLE"

echo "✅ 已添加 core-ktx 依赖到 photo_manager"
echo "📁 位置: $BUILD_GRADLE"
