# MSIX 安装包发布方案

## 目标
为 `Xii_Raw Graph` 生成可发布的 MSIX 安装包，支持 Windows 用户以标准方式安装与卸载。

---

## 1. 前提准备

### 1.1 系统要求
- Windows 10 及以上
- 已启用开发者模式（如果使用自签名证书）
- 安装了 Flutter 开发环境
- 如果需要 MSIX 签名：可使用自签名 PFX 或正式代码签名证书

### 1.2 项目依赖
项目已经包含以下依赖：
- `msix: ^3.16.13`

### 1.3 证书准备
当前项目根目录已有证书文件：`cert.pfx`

如果你要生成可供用户直接安装的 MSIX，请确保证书密码正确并且已配置在 `pubspec.yaml`：
```yaml
msix:
  certificate_path: cert.pfx
  certificate_password: 1234
```

> 注意：生产环境建议使用正式代码签名证书，不建议长期使用自签名证书。

---

## 2. MSIX 发布流程

### 2.1 生成 Release 构建

```powershell
cd c:\AI_MY
flutter build windows --release
```

输出目录：
- `build\windows\x64\Release\`

### 2.2 创建 MSIX 包

使用 MSIX 插件生成安装包：

```powershell
dart run msix:create --certificate-path cert.pfx --certificate-password 1234
```

如果你希望使用 Flutter 的旧调用方式，也可：

```powershell
flutter pub run msix:create --certificate-path cert.pfx --certificate-password 1234
```

### 2.3 结果文件
生成后 MSIX 安装包通常会输出到：
- `build\windows\x64\Release\` 或项目根目录

如果你没有看到 `.msix` 文件，请检查命令输出和日志。

---

## 3. 发布包内容要求

最终发布给用户的包应包含：
- `Xii_Raw_Graph_*.msix`
- `Xii_Raw_Graph_*.appinstaller`（推荐，用于应用内更新）
- `USER_SETUP_GUIDE.md`
- `.env.example`
- `version.json`（可选，用于后续自动更新）

如果你不打算使用 MSIX 安装包，也可以直接发布标准 ZIP 包，但那种方式不能像 MSIX 一样支持标准安装/卸载体验。

---

## 4. 用户安装说明

1. 双击 `Xii_Raw_Graph_v1.1.0.msix`
2. 如果系统提示证书不受信任，请在 Windows 开发者模式下继续安装
3. 推荐通过环境变量配置 API Key，或在以下目录创建 `.env`
   ```text
   %LOCALAPPDATA%\Xii_Raw Graph\.env
   ```
   ```text
   OPENAI_API_KEY=sk-your-actual-key-here
   ```
4. 运行应用

> 当前应用仍然需要用户自行配置 OpenAI API Key，因为密钥不会内嵌到安装包内。

---

## 5. 版本与自动更新建议

### 5.1 更新版本号
发布前请同步更新 `pubspec.yaml` 中版本号：
```yaml
version: 1.1.0+1
```

### 5.2 自动更新配置
应用当前支持远程版本检查。请部署 `version.json` 到可访问的 URL，并修改 `lib/update_service.dart` 中的 `_versionCheckUrl`：

```dart
static const String _versionCheckUrl =
    'https://raw.githubusercontent.com/your-repo/version.json';
```

`version.json` 内容示例：
```json
{
  "version": "1.1.0",
  "downloadUrl": "https://example.com/Xii_Raw_Graph_v1.1.0.appinstaller",
  "releaseNotes": "- 修复问题\n- 优化体验",
  "isForced": false
}
```

推荐优先发布 `.appinstaller` 文件，并让它引用对应版本的 `.msix` 包。这样应用内点击“安装更新”时可以直接拉起 Windows App Installer 完成覆盖升级。

### 5.3 发布渠道

- GitHub Releases
- 公司内部文件服务器
- CDN / 网盘链接

---

## 6. 备选方案

如果 MSIX 生成遇到问题，可先使用 `ZIP` 包分发：
- 直接打包 `release\` 目录内容
- 同时包含 `USER_SETUP_GUIDE.md`
- 让用户手动解压运行

如果你希望，我也可以继续帮你把这个 MSIX 发布方案变成“GitHub Releases 具体发布文案”。
