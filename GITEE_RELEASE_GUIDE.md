# Gitee 发布指南

这是当前默认发布方案：

- 打包成 `免安装 EXE 压缩包（ZIP）`
- 把 ZIP 放到仓库 `downloads/` 目录并推送到 Gitee
- 开启 `Gitee Pages`
- 用极简静态下载页承接下载链接和使用说明
- 额外上传 `CONTACT_AUTHOR_WX.txt` 作为兜底联系说明

## 1. 生成 ZIP 发布包

在项目根目录运行：

```bat
build_release.bat
```

输出结果：

- ZIP 包：`release/READY_TO_SEND/Xii_Raw_Graph_Portable_v<version>.zip`
- 解压目录：`release/READY_TO_SEND/Portable_ZIP/`

ZIP 包内已包含：

- `Xii_Raw_Graph_Portable/`
- `USER_SETUP_GUIDE.md`
- `PORTABLE_PACKAGE_README.md`
- `CONTACT_AUTHOR_WX.txt`

## 2. 上传到 Gitee

建议至少同步这两个文件：

- 最新 ZIP 发布包
- `CONTACT_AUTHOR_WX.txt`

推荐放置位置：

- `downloads/`：用于正式下载
- `仓库根目录`：保留下载页和版本元数据

## 3. 启用 Gitee Pages

当前仓库根目录提供了一个极简静态页：

- `index.html`

发布新版本前需要同步两件事：

1. 更新 `index.html` 里的 ZIP 下载链接和页面版本文案
2. 确认链接仍指向当前仓库 `downloads/` 目录下对应版本的 ZIP 文件

## 4. 同步更新 version.json

如果应用内版本检查仍然启用，请把 `version.json` 的 `downloadUrl` 改成仓库 `downloads/` 目录里最新 ZIP 的直链。

当前推荐格式示例：

```json
{
  "version": "1.1.0",
  "downloadUrl": "https://gitee.com/Xii_ALL/xii_-raw_-graph/raw/main/downloads/Xii_Raw_Graph_Portable_v1.1.0.zip",
  "releaseNotes": "便携版更新说明",
  "isForced": false
}
```

## 5. 页面兜底文案

如果 Gitee 偶尔抽风，请在下载页保留这条信息：

```text
下载异常请联系作者微信：Xiiii-555
```

## 6. 默认建议

- 对外发布：`ZIP + Gitee Releases + Gitee Pages`
- 联系兜底：`CONTACT_AUTHOR_WX.txt`
- 当前仅维护 `ZIP / EXE 便携版` 发布线
