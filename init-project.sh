#!/bin/bash
# Flutter Photo Backup App - 项目初始化脚本
# 创建时间：2026-03-02

set -e

echo "🚀 开始创建 Flutter 项目..."

# 1. 创建 Flutter 项目
flutter create photo_backup_app
cd photo_backup_app

echo "✅ Flutter 项目创建完成"

# 2. 添加依赖
echo "📦 添加依赖包..."

flutter pub add flutter_bloc
flutter pub add equatable
flutter pub add sqflite
flutter pub add shared_preferences
flutter pub add flutter_secure_storage
flutter pub add image_picker
flutter pub add photo_manager
flutter pub add permission_handler
flutter pub add path_provider
flutter pub add synchronized
flutter pub add http
flutter pub add dio
flutter pub add intl
flutter pub add logging
flutter pub add uuid

# 开发依赖
flutter pub add --dev flutter_lints
flutter pub add --dev mockito
flutter pub add --dev bloc_test

echo "✅ 依赖添加完成"

# 3. 创建目录结构
echo "📁 创建项目目录结构..."

mkdir -p lib/blocs
mkdir -p lib/models
mkdir -p lib/services
mkdir -p lib/screens
mkdir -p lib/widgets
mkdir -p lib/utils
mkdir -p assets/images
mkdir -p assets/rclone
mkdir -p test/services
mkdir -p test/blocs
mkdir -p integration_test

echo "✅ 目录结构创建完成"

# 4. 下载 rclone 二进制（需要手动）
echo ""
echo "⚠️  重要：手动下载 rclone 二进制"
echo ""
echo "请访问: https://rclone.org/downloads/"
echo "下载 linux-arm64 版本，然后执行："
echo ""
echo "  mkdir -p android/app/src/main/jniLibs/arm64-v8a/"
echo "  cp ~/Downloads/rclone android/app/src/main/jniLibs/arm64-v8a/librclone.so"
echo ""

# 5. 更新 AndroidManifest.xml 权限
echo "📝 更新 Android 权限配置..."

cat > android/app/src/main/AndroidManifest.xml << 'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 网络权限 -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <!-- 照片访问权限 (Android 13+) -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    
    <!-- 照片访问权限 (Android 12-) -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" 
                     android:maxSdkVersion="32" />
    
    <application
        android:label="Photo Backup"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <!-- JobScheduler 定期清理任务 -->
        <service
            android:name=".ProcessCleanupJob"
            android:permission="android.permission.BIND_JOB_SERVICE"
            android:exported="false" />
            
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
EOF

echo "✅ Android 权限配置完成"

# 6. 提示下一步
echo ""
echo "✅ 项目初始化完成！"
echo ""
echo "📋 下一步："
echo "  1. cd photo_backup_app"
echo "  2. 下载并放置 rclone 二进制文件"
echo "  3. 创建 Platform Channel 代码（MainActivity.kt）"
echo "  4. 运行: flutter run"
echo ""
