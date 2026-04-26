# 🔒 安全指南 - 敏感信息处理

## 🚨 重要安全提醒

**切勿将以下内容上传到 GitHub 或任何公共仓库：**

### ❌ 绝对不能上传的文件

1. **API 密钥和令牌**
   - OpenAI API Key
   - 数据库密码
   - 第三方服务密钥
   - 私有证书文件

2. **配置文件**
   - `.env` (包含真实密钥)
   - `secrets.json`
   - `config/production.dart`

3. **证书和签名文件**
   - `*.pfx` (代码签名证书)
   - `*.key` (私钥文件)
   - `*.pem` (PEM 证书)

4. **构建产物**
   - `build/` 目录
   - `*.exe` 可执行文件
   - `*.msix` 安装包
   - `release/` 发布目录

### ✅ 安全的处理方式

#### 1. 环境变量配置

**创建 `.env` 文件** (不会被提交到 Git):
```bash
# 复制模板文件
cp .env.example .env

# 编辑 .env 文件
OPENAI_API_KEY=sk-your-actual-api-key-here
```

**系统环境变量** (推荐生产环境):
```powershell
# Windows
setx OPENAI_API_KEY "sk-your-actual-api-key-here"

# 或在系统环境变量中设置
```

#### 2. Git 忽略规则

确保 `.gitignore` 包含：
```
# 敏感文件
.env
*.key
*.pfx
cert.pfx

# 构建产物
build/
*.exe
*.msix
release/
```

#### 3. 代码中的安全实践

```dart
// ✅ 正确方式：使用环境配置
final apiKey = EnvConfig.getRequired('OPENAI_API_KEY');

// ❌ 错误方式：硬编码密钥
const apiKey = 'sk-4HFUX4oIUD2oVsMhfvIMR0wLeGaD2bJ932tB1lt8YCdSVM0w';
```

### 🔍 检查清单

**提交代码前务必检查：**

- [ ] 没有硬编码的 API 密钥
- [ ] `.env` 文件未被添加到 Git
- [ ] 证书文件未被提交
- [ ] 构建产物不在仓库中

**检查命令：**
```bash
# 查看将要提交的文件
git status

# 检查是否有敏感内容
git grep -i "sk-"  # 查找 API 密钥
git grep -i "password"  # 查找密码
git grep -i "secret"  # 查找密钥
```

### 🛡️ 安全最佳实践

1. **使用环境变量** 而非硬编码
2. **定期轮换 API 密钥**
3. **限制 API 密钥权限**
4. **监控 API 使用情况**
5. **不要在代码中存储敏感信息**

### 🚨 如果不小心提交了敏感信息

**立即行动：**

1. **撤销提交**:
   ```bash
   git reset --hard HEAD~1
   ```

2. **更改 API 密钥** (在相应服务商处)

3. **清理 Git 历史** (如果已推送):
   ```bash
   # 使用 git filter-branch 或 BFG Repo-Cleaner
   # 然后强制推送
   git push --force
   ```

### 📞 技术支持

如果发现安全问题，请立即：
1. 停止使用受影响的密钥
2. 生成新的密钥
3. 更新所有配置文件
4. 通知相关团队成员

---

**安全第一，隐私至上！ 🔐**