# Xii_Raw Graph - AI 聊天应用

一个基于 Flutter 的现代化 AI 聊天应用，支持文本对话和图片生成功能。

## ✨ 功能特性

- 🤖 AI 智能对话 (GPT-4)
- 🖼️ 图片生成和显示
- 💾 图片下载功能
- 🔄 自动版本更新检查
- 🎨 现代化 Material Design 3 UI
- 🪟 Windows 桌面应用支持

## 🚀 快速开始

### 环境要求

- Flutter 3.0+
- Dart 3.0+
- Windows 10+ (桌面应用)

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/XiiSep-MAX/Xii_CHAT.git
   cd xii_-raw_-graph
   ```

2. **配置 API 密钥**
   ```bash
   # 复制环境变量模板
   cp .env.example .env

   # 编辑 .env 文件，填入你的 OpenAI API Key
   # OPENAI_API_KEY=sk-your-actual-api-key-here
   ```

3. **安装依赖**
   ```bash
   flutter pub get
   ```

4. **运行应用**
   ```bash
   # 开发模式
   flutter run

   # 或构建发布版本
   flutter build windows --release
   ```

## 🔒 安全配置

### ⚠️ 重要提醒

**请勿将以下内容提交到 Git 仓库：**
- `.env` 文件 (包含真实 API 密钥)
- 任何包含密钥的配置文件
- 证书文件 (`*.pfx`, `*.key`)
- 构建产物 (`build/`, `*.exe`)

### 环境变量设置

创建 `.env` 文件：
```env
OPENAI_API_KEY=sk-your-openai-api-key-here
```

或设置系统环境变量：
```powershell
# Windows
setx OPENAI_API_KEY "sk-your-openai-api-key-here"
```

## 🏗️ 构建和发布

### Windows 桌面应用

```bash
# 构建并打包 ZIP 便携版
build_release.bat
```

### Web 版本

```bash
# 构建 Web 版本
flutter build web --release
```

## 🧪 测试

运行单元测试：
```bash
flutter test
```

## 📁 项目结构

```
lib/
├── main.dart              # 应用入口
├── chat_service.dart      # AI 聊天服务
├── update_service.dart    # 版本更新服务
├── download_helper.dart   # 文件下载工具
├── env_config.dart        # 环境配置管理
└── models.dart           # 数据模型

test/
└── widget_test.dart      # 单元测试

其他文件:
├── .env.example          # 环境变量模板
├── SECURITY_GUIDE.md     # 安全指南
├── RELEASE_GUIDE.md      # 发布指南
└── pubspec.yaml          # 项目配置
```

## 🔧 开发指南

### 代码规范

- 使用 `flutter analyze` 检查代码质量
- 运行 `flutter format` 格式化代码
- 遵循 Dart 官方代码规范

### 添加新功能

1. 在相应文件中实现功能
2. 添加单元测试
3. 更新文档
4. 提交代码前运行所有测试

## 📄 许可证

本项目仅供学习和个人使用，请遵守 OpenAI API 使用条款。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 联系方式

如有问题，请通过 Gitee Issues 联系。

---

**Made with ❤️ by Xii_Raw**
