# GitHub Release Draft

## Release Title
Xii_Raw Graph v1.1.0

## Release Description
本次发布为 Xii_Raw Graph 的正式版本 1.1.0，适用于 Windows 桌面。

### 新功能与改进
- ✨ 完成 AI 聊天应用的 Windows 发布版
- 🖼️ 支持 AI 图片生成与显示
- 💾 支持图片下载功能
- 🔄 内置版本检查与更新下载提示
- 🎨 优化用户界面与动画效果
- 🔒 安全配置：使用 `.env` 管理 OpenAI API 密钥

### 修复
- ✅ 修复图片下载路径问题
- ✅ 修复版本比较与更新逻辑
- ✅ 提升应用稳定性与异常处理

### 运行说明
1. 解压 `Xii_Raw_Graph_v1.1.0.zip`
2. 在文件夹内创建 `.env`
3. 添加 OpenAI API Key：
   ```text
   OPENAI_API_KEY=sk-your-actual-key-here
   ```
4. 双击 `ai_chat_app.exe` 启动应用

### 重要提示
- 本应用不包含 OpenAI API Key，用户需自行配置
- 若提示密钥无效，请检查 Key 是否正确并确认账户可用
- 如果需要测试自动更新，请部署 `version.json` 到可访问的 URL，并修改 `lib/update_service.dart` 中的 `_versionCheckUrl`

### 发布资产
- `Xii_Raw_Graph_v1.1.0.zip`
- `USER_SETUP_GUIDE.md`（安装与配置说明）
- `.env.example`

### 资源链接
- 仓库说明: `README.md`
- 发布说明: `RELEASE_GUIDE.md`
- 用户配置指南: `USER_SETUP_GUIDE.md`

---

## 线上更新配置建议
如果希望启用自动更新检查，请将 `version.json` 上传至你的服务器或 GitHub Raw URL，然后在 `lib/update_service.dart` 中替换：

```dart
static const String _versionCheckUrl =
    'https://raw.githubusercontent.com/your-repo/version.json';
```

并将 `downloadUrl` 指向下载包地址。
