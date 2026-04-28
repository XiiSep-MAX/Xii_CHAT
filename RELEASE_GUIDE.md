# Windows 发布指南

当前最终落地方案：

- 打包成 `免安装 EXE 压缩包（ZIP）`
- 把 ZIP 放到仓库 `downloads/` 目录并推送到 Gitee
- 开启 `Gitee Pages`
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

- `Xii_Raw_Graph_Portable/`
- `USER_SETUP_GUIDE.md`
- `PORTABLE_PACKAGE_README.md`
- `CONTACT_AUTHOR_WX.txt`

---

## 2. 上传到 Gitee

推荐同时同步到以下两个位置：

1. `downloads/`
   这是用户主下载入口。

2. `仓库根目录`
   用于承载 `index.html` 和 `version.json`。

建议至少上传：

- 最新 ZIP 发布包
- `CONTACT_AUTHOR_WX.txt`

---

## 3. 配置 Gitee Pages

仓库根目录已经提供了极简静态页：

- `index.html`

发布新版本前需要手动同步：

1. 下载按钮对应版本的 ZIP 直链
2. 页面里的版本号文案

页面内容已经包含：

- 下载按钮
- 使用说明
- 微信兜底联系信息 `Xiiii-555`

---

## 4. 同步更新 version.json

如果应用内版本检查继续使用，请把 `version.json` 的 `downloadUrl` 指向仓库 `downloads/` 目录里的 ZIP 直链。

示例：

```json
{
  "version": "1.1.0",
  "downloadUrl": "https://gitee.com/Xii_ALL/xii_-raw_-graph/raw/main/downloads/Xii_Raw_Graph_Portable_v1.1.0.zip",
  "releaseNotes": "便携版更新说明",
  "isForced": false
}
```

---

## 5. 用户侧默认使用方式

1. 下载 ZIP 包
2. 完整解压
3. 进入 `Xii_Raw_Graph_Portable`
4. 双击 `ai_chat_app.exe`
5. 按 `USER_SETUP_GUIDE.md` 配置 API Key

---

## 6. 兜底方案

如果 Gitee 页面或下载链接异常，请保留这句说明：

```text
下载异常请联系作者微信：Xiiii-555
```

推荐同步放置的位置：

- Gitee Pages 页面
- Gitee Releases 发布说明
- `CONTACT_AUTHOR_WX.txt`
- 用户压缩包内说明文档

---

## 7. 当前策略说明

当前默认主线已经切换为：

- `ZIP 便携版`
- `Gitee Releases`
- `Gitee Pages`

当前只保留 `ZIP / EXE 便携版` 发布路径。
