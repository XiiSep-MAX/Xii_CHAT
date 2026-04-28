# 🔒 私有发布指南

## 目标受众

- ✅ **特定用户**：朋友、家人、团队成员
- ✅ **内部使用**：公司内部、小组项目
- ❌ **公开分发**：不向陌生人公开

## 📋 发布策略选择

### 方案 A: 私有 GitHub 仓库 (推荐)

#### 设置步骤

1. **创建私有仓库**
   ```bash
   # 在 GitHub 创建私有仓库
   # Settings → Danger Zone → Make private
   ```

2. **邀请特定用户**
   ```
   Repository Settings → Collaborators → Add people
   ```

3. **用户获取代码**
   ```bash
   # 使用 GitHub 提供的私有仓库 HTTPS 克隆地址
   git clone <私有仓库克隆地址>
   cd <私有仓库目录>

   # 配置环境变量
   cp .env.example .env
   # 编辑 .env 填入 API 密钥

   # 运行应用
   flutter pub get
   flutter run
   ```

#### 优势
- ✅ 版本控制完整
- ✅ 协作开发方便
- ✅ 代码安全可控
- ✅ 可以设置分支权限

### 方案 B: 直接分享发布包

#### 步骤

1. **构建发布版本**
   ```bash
   cd c:\AI_MY
   flutter build windows --release
   ```

2. **创建分发包**
   ```bash
   # 复制必要文件
   mkdir distribution
   cp build/windows/x64/runner/Release/* distribution/
   cp README.md distribution/
   cp SECURITY_GUIDE.md distribution/

   # 创建 ZIP 包
   Compress-Archive -Path distribution/* -DestinationPath "Xii_Raw_Graph_Private_v<version>.zip"
   ```

3. **安全分享**
   - 📧 邮件发送
   - 💾 U 盘拷贝
   - ☁️ 私有云盘 (OneDrive, Google Drive 设置分享权限)
   - 💬 微信/QQ 等即时通讯

#### 优势
- ✅ 无需 GitHub 账户
- ✅ 即拿即用
- ✅ 文件大小小
- ✅ 完全控制分发

### 方案 C: 内部服务器分发

#### 如果你有服务器

1. **设置下载页面**
   ```html
   <!-- internal-download.html -->
   <h1>Xii_Raw Graph - 内部下载</h1>
   <p>仅限授权用户下载</p>
   <a href="Xii_Raw_Graph_Private_v&lt;version&gt;.zip" download>下载应用</a>
   ```

2. **访问控制**
   - 设置基本认证
   - 使用 VPN 限制访问
   - IP 白名单

## 🔐 安全措施

### 1. 代码安全
```bash
# 确保 .env 文件不被提交
git status
git grep -i "sk-"  # 检查是否有 API 密钥泄露
```

### 2. 分发安全
- **数字签名**: 为 EXE 文件添加签名
- **校验和**: 提供 SHA256 校验码
- **版本追踪**: 记录分发给谁、何时

### 3. 使用限制
- **许可证协议**: 创建私有使用协议
- **水印标识**: 在应用中添加"内部使用"标识
- **过期机制**: 可选添加时间限制

## 📊 对比表

| 方案 | 复杂度 | 用户便利性 | 安全性 | 维护成本 |
|------|--------|-----------|--------|----------|
| 私有仓库 | 中等 | 高 | 高 | 低 |
| 直接分享 | 简单 | 高 | 中 | 低 |
| 内部服务器 | 高 | 中 | 高 | 高 |

## 🎯 推荐方案

**对于你的情况** (只给特定人使用):

### 🥇 **首选: 直接分享发布包**
```bash
# 1. 构建应用
flutter build windows --release

# 2. 创建分发包
Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath "Xii_Raw_Graph_For_Friends.zip"

# 3. 通过微信/邮件/云盘分享给特定人
```

### 🥈 **备选: 私有 GitHub 仓库**
- 如果需要持续更新和协作
- 如果用户需要自定义配置

## 📝 分发清单

**分享前检查:**
- [ ] 应用能正常运行
- [ ] 包含使用说明
- [ ] 告知如何配置 API 密钥
- [ ] 记录分享对象和时间
- [ ] 设置适当的分享权限

**用户收到后:**
- [ ] 解压文件
- [ ] 运行 ai_chat_app.exe
- [ ] 根据提示配置 API 密钥
- [ ] 开始使用

## 🚨 重要提醒

1. **不要公开仓库**: 确保 GitHub 仓库设为私有
2. **保护 API 密钥**: 不要在代码中硬编码密钥
3. **控制分发范围**: 只分享给信任的人
4. **保留审计记录**: 记录谁获得了应用

---

**这样你可以安全地将应用分享给特定的人，而不会被陌生人获取到。** 🔒
