# 更新元数据签名说明

现在项目已经支持：

1. `version.json` 中的 `sha256`
2. `version.json` 的数字签名 `signature`
3. 客户端先验签，再信任这份更新元数据

这意味着：

- 如果站点被篡改，攻击者即使同时改了 ZIP 和 `sha256`
- 只要拿不到你的私钥，就无法伪造合法的 `version.json` 签名

---

## 一、先生成签名密钥

在项目根目录运行：

```powershell
dart run tool\generate_update_signing_key.dart
```

它会输出两段内容：

1. `Private key (keep secret)`
2. `Public key (embed in app)`

---

## 二、把公钥写进客户端

打开：

- `lib/update_service.dart`

找到：

```dart
static const String _versionMetadataPublicKeyBase64 =
    'REPLACE_WITH_PUBLIC_KEY_BASE64';
```

把它替换成你刚生成的公钥 Base64。

---

## 三、把私钥放进本地环境变量

在 PowerShell 当前会话里先设置：

```powershell
$env:UPDATE_METADATA_SIGNING_PRIVATE_KEY="这里换成你的私钥Base64"
```

如果你想长期使用，也可以改成系统环境变量或你自己的本地安全注入方式，但不要提交进仓库。

---

## 四、发布时自动签名

现在 `build_release.bat` 已经会在这些步骤之后自动完成签名：

1. 生成 ZIP
2. 调 `tool/prepare_version_metadata.dart`
3. 计算 ZIP 的 `sha256`
4. 写回 `version.json`
5. 清空旧签名
6. 调 `tool/sign_version_metadata.dart`
7. 生成新的 `signature`

也就是说，你只需要正常运行：

```powershell
build_release.bat
```

前提是当前 shell 里已经有：

```powershell
UPDATE_METADATA_SIGNING_PRIVATE_KEY
```

---

## 五、当前安全模型

客户端现在会：

1. 下载 `version.json`
2. 检查 `signature`
3. 用内置公钥验签
4. 验签通过后，才接受其中的 `downloadUrl / sha256 / releaseNotes`
5. 然后下载 ZIP，并继续校验 ZIP 的 `sha256`

这是“两层校验”：

- 第一层：元数据签名
- 第二层：更新包哈希

---

## 六、如果你忘了配置

### 忘了填客户端公钥

客户端会把更新元数据直接视为不可信，不会执行更新。

### 忘了设私钥环境变量

`build_release.bat` 在签名 `version.json` 时会失败。

---

## 七、建议

1. 私钥永远只保存在你自己手里
2. 公钥可以写进客户端仓库
3. 每次正式发版前，都用同一把私钥签名
4. 如果私钥泄露，立即生成新密钥对并发一个新版本替换客户端公钥
