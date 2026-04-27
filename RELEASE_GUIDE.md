# Flutter AI 聊天应用 - Windows 发布指南

## 📋 项目信息

- **应用名称**: AI Chat App (Xii_Raw Graph)
- **当前版本**: 1.0.0
- **支持平台**: Windows 桌面应用
- **开发框架**: Flutter
- **编程语言**: Dart

---

## 🚀 发布流程

### 步骤 1: 启用 Windows 开发者模式

```powershell
start ms-settings:developers
```

在打开的设置中启用 "Developer Mode"。

### 步骤 2: 构建发布版本

```powershell
cd c:\AI_MY
flutter build windows --release
```

**输出位置**: `build\windows\x64\Release\`

### 步骤 3: 创建可发布的包

#### 方式 A: 简单便携版（推荐初期使用）
```powershell
# 生成的 EXE 文件位置
build\windows\x64\Release\ai_chat_app.exe
```

#### 方式 B: MSIX 安装包（生产环境推荐）
```powershell
flutter pub add msix
flutter pub run msix:create --certificate-path cert.pfx
```

---

## 📦 发布选项对比

| 方式 | 文件大小 | 发布难度 | 用户体验 | 自动更新 |
|------|--------|--------|--------|---------|
| **EXE 便携版** | ~50-100MB | 简单 | 双击运行 | ❌ 手动 |
| **MSIX 安装** | ~30-50MB | 中等 | 类似软件商店 | ✅ 应用内拉起安装 |
| **Microsoft Store** | 压缩分发 | 复杂 | 官方体验 | ✅ 自动 |
| **GitHub Releases** | 全部包含 | 简单 | 下载解压 | ⚠️ 手动 |

---

## 🌐 版本检查与自动更新

### 配置说明

应用已内置版本检查功能。配置步骤：

1. **准备版本信息文件** (`version.json`)：

```json
{
  "version": "1.0.1",
  "downloadUrl": "https://your-server.com/Xii_Raw_Graph-1.0.1.appinstaller",
  "releaseNotes": "- 修复 bug\n- 性能优化",
  "isForced": false
}
```

2. **部署到服务器**：
   - GitHub 仓库 (Raw 内容)
   - 自建服务器
   - CDN

3. **更新应用中的 URL**：

编辑 `lib/update_service.dart`:
```dart
static const String _versionCheckUrl =
    'https://raw.githubusercontent.com/your-repo/version.json';
```

### 更新机制

- 应用启动时自动检查版本
- 发现新版本时弹出更新提示
- 用户可选择直接启动 Windows App Installer 完成升级
- `isForced: true` 时强制更新

---

## 💾 分发渠道

### 推荐方案（阶段性）

#### 第 1 阶段：测试阶段
```
✅ 直接分享 EXE 文件给测试用户
✅ 通过 GitHub Releases 发布
❌ 暂不启用自动更新
```

#### 第 2 阶段：稳定版本
```
✅ 启用版本检查和更新提示
✅ 托管 version.json 到 GitHub
✅ 应用内启动 MSIX / App Installer 更新
```

#### 第 3 阶段：规模扩展
```
✅ 上架 Microsoft Store（自动更新）
✅ 或搭建专业的更新服务器
✅ 考虑代码签名和证书
```

---

## 📝 版本管理规范

### 版本号格式

```
主.次.补+构建号
例: 1.0.0+1
```

- **主版本 (1)**: 重大功能改变
- **次版本 (0)**: 新增功能
- **补丁版本 (0)**: Bug 修复
- **构建号 (+1)**: 每次构建递增

### 更新 pubspec.yaml

```yaml
version: 1.0.0+1  # 发布版本时递增
```

---

## 🔑 代码签名（生产环境）

### 创建自签名证书

```powershell
# 生成 PFX 证书（有效期 10 年）
New-SelfSignedCertificate -CertStoreLocation "Cert:\CurrentUser\My" `
  -Subject "CN=YourName" -KeyUsage DigitalSignature `
  -Type CodeSigningCert -KeyExportPolicy Exportable -KeyLength 2048

# 导出为 .pfx 文件
$cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object {$_.Subject -eq "CN=YourName"} | Select-Object -First 1
Export-PfxCertificate -Cert $cert -FilePath "cert.pfx" -Password (ConvertTo-SecureString -String "password" -AsPlainText -Force)
```

### 使用证书构建

```powershell
flutter pub run msix:create --certificate-path cert.pfx
```

---

## 📊 发布检查清单

- [ ] 代码已完成测试
- [ ] 版本号已更新（pubspec.yaml）
- [ ] UI 和功能已验证
- [ ] 应用程序已构建成功
- [ ] 发布说明已准备
- [ ] 下载 URL 已配置
- [ ] version.json 已上传到服务器
- [ ] 测试用户已通知

---

## 🛠️ 常见问题

### Q: 如何使应用不显示更新提示？
A: 在 `update_service.dart` 中将版本检查功能注释掉或直接删除 `_checkForUpdates()` 调用。

### Q: 能否强制用户更新？
A: 可以，在 version.json 中设置 `"isForced": true`。

### Q: 如何收集应用崩溃信息？
A: 可以集成 Firebase Crashlytics 或其他错误追踪服务。

### Q: Windows 用户能否安装应用？
A: 需要 Windows 10 或更高版本，以及 .NET Runtime（如果使用 MSIX）。

---

## 📞 技术支持

- **Flutter 官方文档**: https://flutter.dev/docs
- **Flutter Windows 桌面**: https://flutter.dev/desktop
- **Dart 文档**: https://dart.dev/guides

---

**最后更新**: 2026-04-26  
**版本**: 1.0.0
