---
title: "Android/Flutter CI/CD Build Failures: Java 17, Kotlin AGP Mismatch, and Missing Resources"
problem_type: build-errors
component: CI/CD (GitHub Actions) / Android Gradle Build
symptoms:
  - APK build workflow failing in GitHub Actions
  - "AGP forced Kotlin version to 1.7.10" conflict error
  - Deprecated actions/upload-artifact@v3 causing workflow failures
  - "deprecated Android v1 embedding" warning
  - "Unresolved reference: toUri" in photo_manager plugin
  - UploadStatus enum duplicate definition
  - connectivity_plus API incompatibility
  - "Padding widget has children but expects child" Dart error
  - Missing launcher icons and styles causing resource errors
  - NDK abiFilters conflict error
tags:
  - github-actions
  - java
  - kotlin
  - agp
  - android-gradle-plugin
  - flutter
  - ci-cd
  - apk-build
  - android
  - build-fix
date: 2026-03-03
severity: high
related_files:
  - .github/workflows/build-apk.yml
  - android/build.gradle
  - android/app/build.gradle
  - android/gradle/wrapper/gradle-wrapper.properties
  - android/gradle.properties
  - android/settings.gradle
  - lib/services/rclone_service.dart
  - lib/services/network_service.dart
  - lib/screens/home_screen.dart
---

# Android/Flutter CI/CD Build Failures: Java 17, Kotlin AGP Mismatch, and Missing Resources

## Problem Summary

A Flutter Android app (photo-backup-app) had its entire GitHub Actions CI/CD pipeline failing due to a cascade of interconnected build configuration issues. After 10+ investigation attempts, the root causes were identified and resolved, culminating in a successful APK build producing 3 split-ABI release artifacts.

## Symptoms

- GitHub Actions workflow failing with deprecated action errors
- Kotlin version conflict: AGP 7.4.2 bundling Kotlin 1.7.10 but project specifying 1.9.23
- "deprecated Android v1 embedding" warnings blocking plugin loading
- `photo_manager` plugin failing with `Unresolved reference: toUri`
- Multiple Dart compilation errors preventing any APK generation
- Missing Android resource files (icons, styles)

## Root Cause

Seven distinct root causes, each blocking the next:

1. **GitHub Actions v3 deprecation** — `actions/upload-artifact@v3` and others were deprecated on 2024-04-16
2. **Android Embedding V2 misconfiguration** — Flutter plugin registration failing due to wrong project structure
3. **Kotlin/AGP version mismatch** — AGP 7.4.2 ships with an internal Kotlin 1.7.10; specifying 1.9.23 caused a conflict that AGP won over silently, breaking Kotlin stdlib
4. **Missing Gradle config files** — `android/settings.gradle` and `android/build.gradle` absent; project not recognized as a valid Android build
5. **NDK abiFilters conflict** — Manual `ndk.abiFilters` set alongside Flutter's `--split-per-abi` flag
6. **Missing AndroidX dependency** — `photo_manager` requires `androidx.core:core-ktx` which was not declared
7. **Dart code errors** — Duplicate enum definition, wrong `connectivity_plus` API, malformed `Padding` widget

## Investigation Steps Tried

| # | What Was Tried | Result |
|---|---------------|--------|
| 1 | Created GitHub Actions workflow with v3 actions | Failed: deprecated |
| 2 | Upgraded to v4 actions | Progressed further |
| 3 | Moved Kotlin files to v2 embedding path | Fixed embedding warning |
| 4 | Created `android/gradle.properties` with AndroidX flags | Enabled AndroidX support |
| 5 | Created `android/settings.gradle` and `android/build.gradle` | Project recognized as valid Gradle build |
| 6 | Removed `ndk.abiFilters` from `build.gradle` | Resolved NDK conflict |
| 7 | Added `androidx.core:core-ktx:1.12.0` dependency | Fixed `toUri` unresolved reference |
| 8 | Fixed 3 Dart code errors | All Dart compilation errors resolved |
| 9 | Generated Android resources via `flutter create` | Resolved missing icons/styles |
| 10 | Downgraded Kotlin from 1.9.23 → 1.7.10 | BUILD SUCCESSFUL |
| 11 | Upgraded Java 11 → 17 in GitHub Actions | Improved AGP 7.4.2 compatibility |

## Working Solution

### Step 1: Upgrade GitHub Actions

**File:** `.github/workflows/build-apk.yml`

```yaml
# Before
- uses: actions/checkout@v3
- uses: actions/setup-java@v3
  with:
    distribution: 'zulu'
    java-version: '11'
- uses: actions/upload-artifact@v3

# After
- uses: actions/checkout@v4
- uses: actions/setup-java@v4
  with:
    distribution: 'zulu'
    java-version: '17'
- uses: actions/upload-artifact@v4
```

### Step 2: Fix Kotlin Version to Match AGP

**File:** `android/build.gradle`

```groovy
// Before
buildscript {
    ext.kotlin_version = '1.9.23'
    dependencies {
        classpath 'com.android.tools.build:gradle:7.3.0'
    }
}

// After
buildscript {
    ext.kotlin_version = '1.7.10'  // MUST match AGP 7.4.2 bundled version
    dependencies {
        classpath 'com.android.tools.build:gradle:7.4.2'
    }
}
```

### Step 3: Upgrade Gradle Wrapper

**File:** `android/gradle/wrapper/gradle-wrapper.properties`

```properties
# Before
distributionUrl=https\://services.gradle.org/distributions/gradle-7.5-all.zip

# After
distributionUrl=https\://services.gradle.org/distributions/gradle-7.6-all.zip
```

### Step 4: Create `android/gradle.properties`

```properties
org.gradle.jvmargs=-Xmx4096M -Dfile.encoding=UTF-8
android.useAndroidX=true
android.enableJetifier=true
kotlin.code.style=official
```

### Step 5: Fix App Dependencies

**File:** `android/app/build.gradle`

```groovy
// Before
dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.9.10"
}

// After
dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.7.10"
    implementation 'androidx.core:core-ktx:1.12.0'  // Required by photo_manager
}
```

### Step 6: Remove NDK ABI Filters

**File:** `android/app/build.gradle`

```groovy
// Remove this block — Flutter handles ABI splitting via --split-per-abi
android {
    defaultConfig {
        // DELETE: ndk { abiFilters 'arm64-v8a', 'armeabi-v7a' }
    }
}
```

### Step 7: Fix Dart Code Errors

**a) Remove duplicate enum** (`lib/services/rclone_service.dart`):
```dart
// Remove the duplicate UploadStatus enum — import from upload_task.dart instead
import 'package:photo_backup_app/models/upload_task.dart';
```

**b) Fix connectivity_plus API** (`lib/services/network_service.dart`):
```dart
// Before
Stream<List<ConnectivityResult>> get onConnectivityChanged =>
    _connectivity.onConnectivityChanged;

Future<ConnectivityResult> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return results.isEmpty ? ConnectivityResult.none : results.first;
}

// After
Stream<ConnectivityResult> get onConnectivityChanged =>
    _connectivity.onConnectivityChanged;

Future<ConnectivityResult> checkConnectivity() async {
    return await _connectivity.checkConnectivity();
}
```

**c) Fix Padding widget** (`lib/screens/home_screen.dart`):
```dart
// Before — Padding does not have a children property
Padding(
  padding: const EdgeInsets.all(16),
  children: [ Row(...) ],
)

// After
Padding(
  padding: const EdgeInsets.all(16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [ ... ],
  ),
)
```

### Step 8: Add Android Resources

```bash
# Generate required icons, styles, and manifest entries
flutter create --platforms=android .
```

### Step 9: Test the Build

```bash
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
```

## Final Working Configuration

| Tool | Version |
|------|---------|
| Flutter | 3.16.0 |
| Gradle | 7.6 |
| Android Gradle Plugin | 7.4.2 |
| Kotlin | 1.7.10 (must match AGP bundled version) |
| Java | 17 (Zulu distribution) |
| compileSdk | 34 |
| minSdk | 24 |
| targetSdk | 34 |

## Build Output

Three APK files produced:

- `app-arm64-v8a-release.apk` (~69 MB) — Modern 64-bit Android devices
- `app-armeabi-v7a-release.apk` (~66 MB) — Legacy 32-bit Android devices
- `app-x86_64-release.apk` (~18 MB) — Android emulators

## Prevention Strategies

### 1. Know the AGP/Kotlin Version Lock

> **Critical:** AGP 7.x bundles a specific Kotlin version and will silently override any higher version you specify. You must use the bundled version or upgrade AGP.

| AGP Version | Bundled Kotlin | Minimum JDK | Gradle |
|-------------|---------------|-------------|--------|
| 7.3.x | 1.7.10 | JDK 8 | 7.5 |
| 7.4.x | 1.7.10 | JDK 8 | 7.6 |
| 8.0–8.1 | 1.8.x | JDK 11 | 8.0+ |
| 8.2+ | 1.9.x+ | JDK 17 | 8.4+ |

### 2. Always Pin Action Versions in CI

```yaml
# Pin to specific major versions
- uses: actions/checkout@v4
- uses: actions/setup-java@v4
- uses: subosito/flutter-action@v2
- uses: actions/upload-artifact@v4
```

Subscribe to [GitHub Changelog](https://github.blog/changelog/) for deprecation notices.

### 3. New Flutter Android Project Checklist

```
[ ] android/gradle.properties: android.useAndroidX=true, android.enableJetifier=true
[ ] android/settings.gradle: Flutter plugin loader configured
[ ] android/build.gradle: AGP version and matching Kotlin version
[ ] android/gradle/wrapper: Gradle version matches AGP requirements
[ ] AndroidManifest.xml: flutterEmbedding meta-data value="2"
[ ] MainActivity.kt: extends FlutterActivity (no v1 artifacts)
[ ] No ndk.abiFilters when using --split-per-abi
[ ] All plugin dependencies (e.g., androidx.core:core-ktx) explicitly declared
[ ] GitHub Actions: all actions pinned to @v4, Java 17, ubuntu-24.04
```

### 4. Validate Embedding V2 in CI

```yaml
- name: Verify Android Embedding v2
  run: |
    grep -q 'flutterEmbedding android:value="2"' android/app/src/main/AndroidManifest.xml
    grep -q 'FlutterActivity' android/app/src/main/kotlin/*/*/MainActivity.kt
    ! find android/app/src -name "GeneratedPluginRegistrant.java" | grep -q .
```

## Related Documentation

- `BUILD_SUCCESS_v1.0.0.md` — Comprehensive summary of all 15 build issues resolved
- `BUILD_GUIDE.md` — Build configuration and troubleshooting guide
- `.github/workflows/build-apk.yml` — Final working CI/CD workflow
- `RELEASE_NOTES_v1.0.0.md` — First successful release details
- [AGP Compatibility Matrix](https://developer.android.com/studio/releases/gradle-plugin)
- [Flutter Android Deployment Guide](https://docs.flutter.dev/deployment/android)
- [Kotlin Gradle Plugin Compatibility](https://kotlinlang.org/docs/gradle-configure-project.html)
