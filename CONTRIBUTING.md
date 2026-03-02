# 贡献指南

感谢你对 Photo Backup App 的关注！🎉

## 🤝 如何贡献

### 报告 Bug

如果你发现了问题：

1. 检查 [Issues](https://github.com/simonlei/photo-backup/issues) 是否已存在
2. 如果没有，创建新 Issue，包含：
   - 问题描述
   - 复现步骤
   - 预期行为 vs 实际行为
   - 设备信息（Android 版本、机型）
   - 日志（如果有）

### 提交代码

1. **Fork 仓库**
   ```bash
   # 点击右上角 Fork 按钮
   git clone https://github.com/你的用户名/photo-backup.git
   ```

2. **创建分支**
   ```bash
   git checkout -b feature/amazing-feature
   # 或
   git checkout -b fix/bug-description
   ```

3. **开发和测试**
   ```bash
   # 运行应用
   flutter run
   
   # 运行测试（待添加）
   flutter test
   ```

4. **提交更改**
   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   ```
   
   遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范：
   - `feat:` - 新功能
   - `fix:` - Bug 修复
   - `docs:` - 文档更新
   - `style:` - 代码格式
   - `refactor:` - 重构
   - `test:` - 测试相关
   - `chore:` - 构建/工具

5. **推送并创建 PR**
   ```bash
   git push origin feature/amazing-feature
   ```
   
   然后在 GitHub 创建 Pull Request。

## 🏗️ 开发环境

### 前置要求

- Flutter 3.0+
- Android Studio / VS Code
- Android SDK (API 21+)
- Git

### 安装依赖

```bash
cd photo-backup-app
flutter pub get
./init-project.sh  # 下载 rclone 二进制
```

### 运行应用

```bash
# 连接 Android 设备或启动模拟器
flutter devices

# 运行应用
flutter run
```

## 📋 开发规范

### 代码风格

- 遵循 [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- 遵循 [Kotlin Style Guide](https://kotlinlang.org/docs/coding-conventions.html)
- 使用 `flutter format` 格式化代码
- 添加有意义的注释

### 提交信息

使用清晰的提交信息：

```
feat: add network detection before upload

- Check WiFi/mobile data status
- Show warning when using mobile data
- Pause upload when network lost

Closes #5
```

### 测试

- 添加单元测试（参考 `todos/006-pending-p3-missing-unit-tests.md`）
- 手动测试核心功能
- 确保不破坏现有功能

## 🎯 优先级任务

查看 `todos/` 目录：

- **P1（Critical）** - 阻止发布的问题
- **P2（Important）** - 应该尽快修复
- **P3（Nice-to-have）** - 代码质量改进

当前 P1 问题：
1. `001` - PID 文件竞态条件
2. `002` - 密码明文传输

## 🌟 行为准则

- 尊重他人
- 友善交流
- 欢迎新手
- 建设性反馈

## 💬 联系方式

- 提问：[GitHub Discussions](https://github.com/simonlei/photo-backup/discussions)
- Bug 报告：[GitHub Issues](https://github.com/simonlei/photo-backup/issues)

---

再次感谢你的贡献！❤️
