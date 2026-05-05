# Windows 发布指南

当前正式发布链路：

- 打包成 `Windows 便携 ZIP`
- ZIP 放到仓库 `downloads/`
- 页面与更新元数据通过 `xiimax.top`
- `version.json` 提供 `downloadUrl + mirrorUrls + sha256`
- 客户端下载后先校验 `SHA-256`，校验通过才允许自动安装

---

## 1. 生成发布包

在项目根目录运行：

```bat
build_release.bat
```

脚本会自动完成：

1. `flutter build windows --release`
2. 编译 `xii_updater.exe`
3. 打包 ZIP
4. 复制 ZIP 到 `downloads/`
5. 计算 ZIP 的 `SHA-256`
6. 回写 `version.json` 里的 `sha256`
7. 生成一个公开校验文件 `*.sha256.txt`

主要输出位置：

- ZIP 包：`release/READY_TO_SEND/Xii_Raw_Graph_Trial_v<version>.zip`
- 打包目录：`release/READY_TO_SEND/Portable_ZIP/`
- 仓库下载包：`downloads/Xii_Raw_Graph_Trial_v<version>.zip`
- 校验文件：`downloads/Xii_Raw_Graph_Trial_v<version>.sha256.txt`
- 构建阶段哈希记录：`release/READY_TO_SEND/package_sha256.txt`

---

## 2. 发布时需要提交的文件

至少提交并推送这些内容：

- `downloads/Xii_Raw_Graph_Trial_v<version>.zip`
- `downloads/Xii_Raw_Graph_Trial_v<version>.sha256.txt`
- `version.json`
- `index.html`
- 相关代码或文档改动

---

## 3. 当前更新元数据格式

现在 `version.json` 至少应包含：

```json
{
  "version": "1.2.5",
  "downloadUrl": "https://xiimax.top/downloads/Xii_Raw_Graph_Trial_v1.2.5.zip",
  "sha256": "zip 文件的 sha256 小写十六进制",
  "releaseNotes": "更新说明",
  "isForced": false
}
```

说明：

- `downloadUrl`：主下载源，给客户端下载更新包
- `mirrorUrls`：备用下载源，主源过慢或失败时自动回退
- `sha256`：客户端下载完成后校验完整性
- 如果 `sha256` 缺失，当前客户端会默认拒绝自动安装

这是故意的“安全失败”策略。

---

## 4. 自定义域名与缓存

当前推荐更新源：

- `https://xiimax.top/version.json`
- `https://xiimax.top/downloads/...`

如果你使用 Cloudflare：

- `version.json` 建议短缓存或绕过缓存
- ZIP 包和 `*.sha256.txt` 可以正常缓存

---

## 5. Pages / 静态页

仓库已经有自动部署 Pages 的工作流：

- `.github/workflows/deploy-pages.yml`

当前静态站点会发布：

- `index.html`
- `downloads/`
- `version.json`
- `CONTACT_AUTHOR_WX.txt`

如果你希望把 `*.sha256.txt` 也公开下载，当前工作流已经会把 `downloads/*` 整体带上，不需要额外处理。

---

## 6. 用户侧更新行为

用户在应用内点击“下载更新”后，当前流程会变成：

1. 拉取 `version.json`
2. 下载 ZIP 包
3. 校验 ZIP 的 `SHA-256`
4. 只有校验通过，才进入自动安装
5. 校验失败时，拒绝自动安装并提示错误

---

## 7. 兜底说明

建议继续保留下载异常兜底联系方式，例如：

```text
下载异常请联系作者微信：123456
```

推荐保留位置：

- 下载页
- `CONTACT_AUTHOR_WX.txt`
- 发布说明

---

## 8. 当前发布策略

当前默认正式发布路径就是：

- `ZIP 便携版`
- `xiimax.top` 下载入口
- `version.json + sha256` 自动更新校验

这已经比“只放 ZIP 直链”更接近可商用分发标准。
