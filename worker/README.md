# Xii License Worker

这是给桌面端商业版准备的最小授权服务，负责三件事：

1. 激活码校验与设备绑定
2. 授权 token 校验与续期
3. 代理 AI 生成请求，避免把上游 API Key 放到客户端

## 目录说明

- `schema.sql`：D1 表结构
- `wrangler.toml`：Worker 配置
- `src/index.ts`：激活 / 校验 / 代理接口

## 先决条件

1. 创建一个 Cloudflare D1 数据库
2. 把 `wrangler.toml` 里的 `database_id` 改成你自己的
3. 配置 Worker secrets

## 建库

```bash
wrangler d1 execute xii-license-db --file=./schema.sql
```

## 配置 Secrets

```bash
wrangler secret put OPENAI_API_KEY
wrangler secret put LICENSE_SIGNING_SECRET
wrangler secret put ADMIN_ACCESS_TOKEN
```

建议：
- `OPENAI_API_KEY`：你真正的上游密钥
- `LICENSE_SIGNING_SECRET`：一串高强度随机字符串，用来签授权 token
- `ADMIN_ACCESS_TOKEN`：后台管理页调用管理接口时使用的固定管理员令牌

## 本地变量

`wrangler.toml` 里当前带了两个变量：

- `UPSTREAM_BASE_URL`
- `UPSTREAM_MODEL`

默认已经指向你当前项目使用的上游接口，你也可以改成自己的兼容网关。

## 激活码管理脚本

现在已经内置了一个本地管理脚本，不用再手算 hash 或手写 SQL。

### 创建新激活码

自动生成一条码并写入远程 D1：

```bash
npm run license -- create --note "首批测试用户" --expires "2027-12-31T23:59:59.000Z" --maxDevices 1
```

如果你想自己指定激活码：

```bash
npm run license -- create --code "XII-2026-ABCD-EFGH" --note "手动指定码"
```

### 查看激活码列表

```bash
npm run license -- list
```

按备注过滤：

```bash
npm run license -- list --note "首批测试用户"
```

### 查看绑定记录

```bash
npm run license -- bindings --note "首批测试用户"
```

### 清空某个码的绑定

```bash
npm run license -- unbind --code "XII-2026-ABCD-EFGH"
```

### 延期授权

```bash
npm run license -- extend --code "XII-2026-ABCD-EFGH" --expires "2028-12-31T23:59:59.000Z"
```

### 修改设备数 / 套餐 / 状态 / 备注

```bash
npm run license -- update --id 3 --maxDevices 2
npm run license -- update --id 3 --tier "premium-plus"
npm run license -- update --id 3 --status "disabled"
npm run license -- update --id 3 --note "已续费到 2028"
```

### 禁用 / 启用某个码

```bash
npm run license -- disable --id 3
npm run license -- enable --id 3
```

### 删除某个码

```bash
npm run license -- delete --id 3
```

脚本默认会调用：

```bash
wrangler d1 execute xii-license-db --remote
```

也就是说，所有操作都是直接落到线上远程 D1。

## Flutter 侧配置

在桌面应用 `.env` 里配置：

```env
LICENSE_API_BASE_URL=https://你的-worker-域名
```

配置后：
- 激活码输入框会进入真实校验模式
- 图片生成请求会改走 Worker
- 客户端不再需要直接使用上游 API Key

## 当前接口

- `POST /v1/license/activate`
- `POST /v1/license/validate`
- `POST /v1/chat/generate`
- `POST /v1/orders`
- `GET /v1/orders/:orderNo`
- `POST /v1/payments/webhook`
- `GET /admin`
- `GET /v1/admin/licenses`
- `POST /v1/admin/licenses`
- `GET /v1/admin/orders`
- `POST /v1/admin/orders`
- `POST /v1/admin/orders/:id/mark-paid`
- `POST /v1/admin/licenses/:id/update`
- `POST /v1/admin/licenses/:id/unbind`
- `GET /v1/admin/bindings?licenseId=:id`

## 最简后台页

现在 Worker 已经内置了一个最简后台页，访问：

```text
https://你的域名/admin
```

例如你当前可以用：

```text
https://api.xiimax.top/admin
```

第一次打开时：

1. 先输入 `ADMIN_ACCESS_TOKEN`
2. 点“保存”
3. 就可以直接：
   - 创建激活码
   - 创建订单
   - 查看列表
   - 延期
   - 改设备数
   - 禁用 / 启用
   - 清绑定
   - 删除激活码
   - 删除订单
   - 手动标记订单已支付并自动发码

说明：
- 页面本身可以访问
- 真正的管理操作需要请求头里的 `x-admin-token`
- 页面会把你输入的 token 暂存在当前浏览器的 `localStorage`

## 下一步建议

这版是“最小可卖”骨架，建议你下一步补：

1. 微信 / 支付宝真实回调验签
2. 请求限流
3. 更完整的订单状态页和用户查询页
4. 支付后自动发码消息推送
5. 更细的后台权限控制
