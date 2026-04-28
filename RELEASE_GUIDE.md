# Windows 发布指南

当前最终落地方案：

- 打包成 `免安装 EXE 压缩包（ZIP）`
- 把 ZIP 放到仓库 `downloads/` 目录并推送到 GitHub
- 开启 `GitHub Pages`
- 用极简静态下载页承接下载链接和使用说明
- 同步提供 `CONTACT_AUTHOR_WX.txt` 作为下载异常兜底

---

## 1. 生成发布包

在项目根目录运行：

```bat
build_release.bat
```

输出位置：

- ZIP 包：`release/READY_TO_SEND/Xii_Raw_Graph_Portable_v<version>.zip`
- 打包目录：`release/READY_TO_SEND/Portable_ZIP/`

ZIP 包内默认包含：

- `ai_chat_app.exe`
- `data/`
- `flutter_windows.dll` 等运行库
- `USER_SETUP_GUIDE.md`
- `PORTABLE_PACKAGE_README.md`
- `CONTACT_AUTHOR_WX.txt`

---

## 2. 上传到 GitHub

推荐同时同步到以下两个位置：

1. `downloads/`
   这是用户主下载入口。

2. `仓库根目录`
   用于承载 `index.html` 和 `version.json`。

建议至少上传：

- 最新 ZIP 发布包
- `CONTACT_AUTHOR_WX.txt`

---

## 3. 配置 GitHub Pages

仓库已经提供了自动部署 Pages 的工作流：

- `.github/workflows/deploy-pages.yml`

Pages 站点默认会发布这些文件：

- `index.html`
- `downloads/`
- `version.json`
- `CONTACT_AUTHOR_WX.txt`

发布新版本前需要手动同步：

1. 下载按钮对应版本的 ZIP 文件名
2. 页面里的版本号文案
3. GitHub 仓库入口链接

首次启用时，请在 GitHub 仓库里完成这一步：

1. 打开 `Settings` -> `Pages`
2. 在 `Build and deployment` 下把 `Source` 设为 `GitHub Actions`

默认访问地址：

- `https://xiisep-max.github.io/Xii_CHAT/`

页面内容已经包含：

- 下载按钮
- 使用说明
- 微信兜底联系信息 `Xiiii-555`

---

## 4. 同步更新 version.json

如果应用内版本检查继续使用，请把 `version.json` 的 `downloadUrl` 指向 GitHub 仓库 `downloads/` 目录里的 ZIP 直链。

示例：

```json
{
  "version": "1.1.0",
  "downloadUrl": "https://raw.githubusercontent.com/XiiSep-MAX/Xii_CHAT/main/downloads/Xii_Raw_Graph_Portable_v1.1.0.zip",
  "releaseNotes": "便携版更新说明",
  "isForced": false
}
```

---

## 5. 用户侧默认使用方式

1. 下载 ZIP 包
2. 完整解压
3. 直接双击 `ai_chat_app.exe`
4. 按 `USER_SETUP_GUIDE.md` 配置 API Key

---

## 6. 兜底方案

如果 GitHub 页面或下载链接异常，请保留这句说明：

```text
下载异常请联系作者微信：Xiiii-555
```

推荐同步放置的位置：

- GitHub Pages 页面
- GitHub Releases 发布说明
- `CONTACT_AUTHOR_WX.txt`
- 用户压缩包内说明文档

---

## 7. 当前策略说明

当前默认主线已经切换为：

- `ZIP 便携版`
- `GitHub 仓库下载`
- `GitHub Pages`

当前只保留 `ZIP / EXE 便携版` 发布路径。
