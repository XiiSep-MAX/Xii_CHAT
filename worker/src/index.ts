import { renderAdminPage } from "./admin-page";

export interface Env {
  DB: D1Database;
  GENERATION_QUEUE: Queue;
  OPENAI_API_KEY: string;
  LICENSE_SIGNING_SECRET: string;
  ADMIN_ACCESS_TOKEN: string;
  UPSTREAM_BASE_URL: string;
  UPSTREAM_MODEL: string;
}

const SAFETY_BLOCK_MESSAGE =
  "当前描述涉及不适合生成的内容，请调整提示词后再试。";

const BLOCKED_KEYWORDS = [
  "未成年裸体",
  "未成年人裸体",
  "儿童裸体",
  "幼女",
  "幼童",
  "强奸",
  "轮奸",
  "乱伦",
  "兽交",
  "恋童",
  "极端血腥",
  "肢解",
  "斩首",
  "虐杀",
  "分尸",
  "尸体特写",
  "炸弹制作",
  "制毒",
  "恐怖袭击教程",
  "证件伪造",
  "护照伪造",
  "deepfake porn",
  "child porn",
  "rape",
  "incest",
  "bestiality",
  "gore",
  "beheading",
  "dismemberment",
  "how to make a bomb",
  "fake passport",
];

const SUSPICIOUS_IMAGE_EDIT_KEYWORDS = [
  "去衣",
  "脱衣",
  "裸体化",
  "衣服去掉",
  "remove clothes",
  "undress",
  "nude edit",
];

type LicenseCodeRow = {
  id: number;
  code_hash: string;
  status: string;
  tier: string;
  expires_at: string | null;
  max_devices: number;
  note?: string | null;
};

type BindingRow = {
  id: number;
  install_id_hash: string;
  revoked_at: string | null;
};

type OrderRow = {
  id: number;
  order_no: string;
  access_token_hash: string;
  status: string;
  product_name: string;
  tier: string;
  max_devices: number;
  expires_at: string | null;
  buyer_contact: string | null;
  note: string | null;
  payment_provider: string | null;
  amount_cents: number;
  currency: string;
  external_payment_id: string | null;
  issued_license_code_id: number | null;
  issued_code_plaintext: string | null;
  created_at: string;
  paid_at: string | null;
  fulfilled_at: string | null;
  updated_at: string;
};

type GenerationTaskRow = {
  id: number;
  task_id: string;
  idempotency_key: string;
  license_code_id: number;
  install_id_hash: string;
  task_type: string;
  status: string;
  prompt: string;
  request_size: string;
  request_quality: string;
  reference_images_json: string | null;
  source_image_json: string | null;
  mask_image_json: string | null;
  result_json: string | null;
  error_message: string | null;
  upstream_status: number | null;
  created_at: string;
  updated_at: string;
  completed_at: string | null;
};

type GenerationQueueMessage = {
  taskId: string;
};

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    try {
      const url = new URL(request.url);

      if (request.method === "GET" && url.pathname === "/admin") {
        return new Response(renderAdminPage(), {
          headers: {
            "Content-Type": "text/html; charset=utf-8",
          },
        });
      }

      if (url.pathname.startsWith("/v1/admin/")) {
        return await handleAdminRequest(request, env, url);
      }

      if (request.method === "POST" && url.pathname === "/v1/license/activate") {
        return await handleActivate(request, env);
      }

      if (request.method === "POST" && url.pathname === "/v1/orders") {
        return await handleCreateOrder(request, env);
      }

      if (request.method === "GET" && url.pathname.startsWith("/v1/orders/")) {
        return await handleGetOrder(request, env, url);
      }

      if (request.method === "POST" && url.pathname === "/v1/payments/webhook") {
        return await handlePaymentWebhook(request, env);
      }

      if (request.method === "POST" && url.pathname === "/v1/license/validate") {
        return await handleValidate(request, env);
      }

      if (request.method === "POST" && url.pathname === "/v1/chat/generate") {
        return await handleGenerate(request, env, ctx);
      }

      if (request.method === "GET" && url.pathname.startsWith("/v1/chat/tasks/")) {
        return await handleGetGenerationTask(request, env, url);
      }

      if (request.method === "POST" && url.pathname === "/v1/chat/edit-image") {
        return await handleEditImage(request, env);
      }

      return json(
        {
          error: "Not found",
        },
        404,
      );
    } catch (error) {
      return json(
        {
          error: error instanceof Error ? error.message : "Internal error",
        },
        500,
      );
    }
  },
  async queue(batch: MessageBatch<GenerationQueueMessage>, env: Env): Promise<void> {
    for (const message of batch.messages) {
      try {
        const taskId = message.body?.taskId?.trim();
        if (!taskId) {
          message.ack();
          continue;
        }

        const task = await loadGenerationTaskByTaskId(env, taskId);
        if (!task) {
          message.ack();
          continue;
        }

        await runGenerationTask(env, task);
        message.ack();
      } catch (error) {
        console.error("generation queue task failed", error);
        message.retry();
      }
    }
  },
};

async function handleActivate(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    code?: string;
    installId?: string;
    deviceName?: string;
  };

  const code = (body.code ?? "").trim();
  const installId = (body.installId ?? "").trim();
  if (!code || !installId) {
    return json({ error: "缺少激活码或设备标识。" }, 400);
  }

  const codeHash = await sha256Hex(code);
  const installIdHash = await sha256Hex(installId);
  const license = await loadLicenseByHash(env, codeHash);
  if (!license) {
    return json({ error: "激活码不存在或已失效。" }, 404);
  }

  validateLicenseAvailability(license);

  const bindings = await loadActiveBindings(env, license.id);
  const existing = bindings.find((item) => item.install_id_hash === installIdHash);
  if (!existing && bindings.length >= license.max_devices) {
    return json({ error: "该激活码已达到绑定设备上限。" }, 409);
  }

  const now = new Date().toISOString();
  if (existing) {
    await env.DB.prepare(
      `UPDATE license_bindings
       SET last_seen_at = ?
       WHERE id = ?`,
    )
      .bind(now, existing.id)
      .run();
  } else {
    await env.DB.prepare(
      `INSERT INTO license_bindings (
        license_code_id,
        install_id_hash,
        device_name,
        bound_at,
        last_seen_at
      ) VALUES (?, ?, ?, ?, ?)`,
    )
      .bind(license.id, installIdHash, body.deviceName ?? null, now, now)
      .run();
  }

  const token = await signLicenseToken(env, {
    licenseId: license.id,
    installIdHash,
    tier: license.tier,
    expiresAt: license.expires_at,
  });

  await appendEvent(env, license.id, "activate", {
    installIdHash,
    deviceName: body.deviceName ?? null,
  });

  return json({
    message: "激活成功，已解锁高级功能。",
    token,
    tier: license.tier,
    expiresAt: license.expires_at,
  });
}

async function handleAdminRequest(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response> {
  const adminToken = request.headers.get("x-admin-token")?.trim() ?? "";
  if (!env.ADMIN_ACCESS_TOKEN || adminToken !== env.ADMIN_ACCESS_TOKEN) {
    return json({ error: "管理员令牌无效。" }, 401);
  }

  if (request.method === "GET" && url.pathname === "/v1/admin/licenses") {
    return await handleAdminListLicenses(env, url);
  }

  if (request.method === "GET" && url.pathname === "/v1/admin/orders") {
    return await handleAdminListOrders(env, url);
  }

  if (request.method === "GET" && url.pathname === "/v1/admin/safety-events") {
    return await handleAdminListSafetyEvents(env, url);
  }

  if (request.method === "POST" && url.pathname === "/v1/admin/licenses") {
    return await handleAdminCreateLicense(request, env);
  }

  if (request.method === "POST" && url.pathname === "/v1/admin/orders") {
    return await handleAdminCreateOrder(request, env);
  }

  const licenseUpdateMatch = url.pathname.match(/^\/v1\/admin\/licenses\/(\d+)\/update$/);
  if (request.method === "POST" && licenseUpdateMatch) {
    return await handleAdminUpdateLicense(request, env, Number(licenseUpdateMatch[1]));
  }

  const licenseUnbindMatch = url.pathname.match(/^\/v1\/admin\/licenses\/(\d+)\/unbind$/);
  if (request.method === "POST" && licenseUnbindMatch) {
    return await handleAdminUnbindLicense(env, Number(licenseUnbindMatch[1]));
  }

  const licenseDeleteMatch = url.pathname.match(/^\/v1\/admin\/licenses\/(\d+)$/);
  if (request.method === "DELETE" && licenseDeleteMatch) {
    return await handleAdminDeleteLicense(env, Number(licenseDeleteMatch[1]));
  }

  const orderMarkPaidMatch = url.pathname.match(/^\/v1\/admin\/orders\/(\d+)\/mark-paid$/);
  if (request.method === "POST" && orderMarkPaidMatch) {
    return await handleAdminMarkOrderPaid(request, env, Number(orderMarkPaidMatch[1]));
  }

  const orderDeleteMatch = url.pathname.match(/^\/v1\/admin\/orders\/(\d+)$/);
  if (request.method === "DELETE" && orderDeleteMatch) {
    return await handleAdminDeleteOrder(env, Number(orderDeleteMatch[1]));
  }

  if (request.method === "GET" && url.pathname === "/v1/admin/bindings") {
    return await handleAdminBindings(env, url);
  }

  return json({ error: "Not found" }, 404);
}

async function handleAdminListLicenses(env: Env, url: URL): Promise<Response> {
  const query = url.searchParams.get("q")?.trim() ?? "";
  let statement = env.DB.prepare(`
    SELECT
      lc.id,
      lc.status,
      lc.tier,
      lc.expires_at,
      lc.max_devices,
      lc.note,
      lc.created_at,
      lc.updated_at,
      COUNT(lb.id) AS binding_count
    FROM license_codes lc
    LEFT JOIN license_bindings lb
      ON lb.license_code_id = lc.id AND lb.revoked_at IS NULL
  `);

  if (query) {
    statement = env.DB.prepare(`
      SELECT
        lc.id,
        lc.status,
        lc.tier,
        lc.expires_at,
        lc.max_devices,
        lc.note,
        lc.created_at,
        lc.updated_at,
        COUNT(lb.id) AS binding_count
      FROM license_codes lc
      LEFT JOIN license_bindings lb
        ON lb.license_code_id = lc.id AND lb.revoked_at IS NULL
      WHERE lc.note LIKE ? OR lc.status LIKE ? OR lc.tier LIKE ?
      GROUP BY lc.id
      ORDER BY lc.id DESC
    `).bind(`%${query}%`, `%${query}%`, `%${query}%`);
  } else {
    statement = env.DB.prepare(`
      SELECT
        lc.id,
        lc.status,
        lc.tier,
        lc.expires_at,
        lc.max_devices,
        lc.note,
        lc.created_at,
        lc.updated_at,
        COUNT(lb.id) AS binding_count
      FROM license_codes lc
      LEFT JOIN license_bindings lb
        ON lb.license_code_id = lc.id AND lb.revoked_at IS NULL
      GROUP BY lc.id
      ORDER BY lc.id DESC
    `);
  }

  const result = await statement.all<Record<string, unknown>>();
  return json({
    items: result.results ?? [],
  });
}

async function handleAdminListOrders(env: Env, url: URL): Promise<Response> {
  const query = url.searchParams.get("q")?.trim() ?? "";
  let statement = env.DB.prepare(`
    SELECT
      id,
      order_no,
      status,
      product_name,
      tier,
      max_devices,
      expires_at,
      buyer_contact,
      note,
      payment_provider,
      amount_cents,
      currency,
      external_payment_id,
      issued_license_code_id,
      issued_code_plaintext,
      created_at,
      paid_at,
      fulfilled_at,
      updated_at
    FROM orders
    ORDER BY id DESC
  `);

  if (query) {
    statement = env.DB.prepare(`
      SELECT
        id,
        order_no,
        status,
        product_name,
        tier,
        max_devices,
        expires_at,
        buyer_contact,
        note,
        payment_provider,
        amount_cents,
        currency,
        external_payment_id,
        issued_license_code_id,
        issued_code_plaintext,
        created_at,
        paid_at,
        fulfilled_at,
        updated_at
      FROM orders
      WHERE order_no LIKE ? OR buyer_contact LIKE ? OR note LIKE ? OR status LIKE ?
      ORDER BY id DESC
    `).bind(`%${query}%`, `%${query}%`, `%${query}%`, `%${query}%`);
  }

  const result = await statement.all<Record<string, unknown>>();
  return json({
    items: result.results ?? [],
  });
}

async function handleAdminListSafetyEvents(
  env: Env,
  url: URL,
): Promise<Response> {
  const query = url.searchParams.get("q")?.trim() ?? "";
  let statement = env.DB.prepare(`
    SELECT
      id,
      category,
      safety_code,
      prompt_excerpt,
      has_reference_image,
      license_code_id,
      install_id_hash,
      payload_json,
      created_at
    FROM safety_events
    ORDER BY id DESC
    LIMIT 200
  `);

  if (query) {
    statement = env.DB.prepare(`
      SELECT
        id,
        category,
        safety_code,
        prompt_excerpt,
        has_reference_image,
        license_code_id,
        install_id_hash,
        payload_json,
        created_at
      FROM safety_events
      WHERE category LIKE ? OR safety_code LIKE ? OR prompt_excerpt LIKE ?
      ORDER BY id DESC
      LIMIT 200
    `).bind(`%${query}%`, `%${query}%`, `%${query}%`);
  }

  const result = await statement.all<Record<string, unknown>>();
  return json({
    items: result.results ?? [],
  });
}

async function handleAdminCreateLicense(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    code?: string;
    note?: string;
    tier?: string;
    expiresAt?: string | null;
    maxDevices?: number;
  };

  const code = (body.code?.trim() || generateLicenseCode()).toUpperCase();
  const codeHash = await sha256Hex(code);
  const tier = body.tier?.trim() || "premium";
  const expiresAt = body.expiresAt?.trim() || "2027-12-31T23:59:59.000Z";
  const maxDevices =
    typeof body.maxDevices === "number" && body.maxDevices > 0 ? body.maxDevices : 1;
  const note = body.note?.trim() || "";

  await env.DB.prepare(
    `INSERT INTO license_codes (
      code_hash,
      status,
      tier,
      expires_at,
      max_devices,
      note,
      created_at,
      updated_at
    ) VALUES (?, 'active', ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      codeHash,
      tier,
      expiresAt,
      maxDevices,
      note,
      new Date().toISOString(),
      new Date().toISOString(),
    )
    .run();

  return json({
    message: "激活码创建成功。",
    code,
    tier,
    expiresAt,
    maxDevices,
    note,
  });
}

async function handleAdminCreateOrder(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    productName?: string;
    buyerContact?: string;
    note?: string;
    tier?: string;
    expiresAt?: string | null;
    maxDevices?: number;
    amountCents?: number;
    currency?: string;
    paymentProvider?: string;
  };

  const order = await createOrder(env, {
    productName: body.productName?.trim() || "Xii_Raw Graph 高级授权",
    buyerContact: body.buyerContact?.trim() || null,
    note: body.note?.trim() || null,
    tier: body.tier?.trim() || "premium",
    expiresAt: body.expiresAt?.trim() || null,
    maxDevices:
      typeof body.maxDevices === "number" && body.maxDevices > 0 ? body.maxDevices : 1,
    amountCents: typeof body.amountCents === "number" ? body.amountCents : 0,
    currency: body.currency?.trim() || "CNY",
    paymentProvider: body.paymentProvider?.trim() || "manual",
  });

  return json({
    message: "订单已创建，可等待支付回调或后台手动标记为已支付。",
    ...order,
  });
}

async function handleAdminUpdateLicense(
  request: Request,
  env: Env,
  licenseId: number,
): Promise<Response> {
  const body = (await request.json()) as {
    tier?: string;
    expiresAt?: string | null;
    maxDevices?: number;
    note?: string;
    status?: string;
  };

  const updates: string[] = [];
  const values: unknown[] = [];

  if (body.tier) {
    updates.push("tier = ?");
    values.push(body.tier.trim());
  }
  if (body.expiresAt) {
    updates.push("expires_at = ?");
    values.push(body.expiresAt.trim());
  }
  if (typeof body.maxDevices === "number" && body.maxDevices > 0) {
    updates.push("max_devices = ?");
    values.push(body.maxDevices);
  }
  if (body.note !== undefined) {
    updates.push("note = ?");
    values.push(body.note.trim());
  }
  if (body.status) {
    updates.push("status = ?");
    values.push(body.status.trim());
  }

  if (updates.length === 0) {
    return json({ error: "没有可更新的字段。" }, 400);
  }

  updates.push("updated_at = ?");
  values.push(new Date().toISOString());
  values.push(licenseId);

  await env.DB.prepare(
    `UPDATE license_codes
     SET ${updates.join(", ")}
     WHERE id = ?`,
  )
    .bind(...values)
    .run();

  return json({
    message: "激活码信息已更新。",
  });
}

async function handleAdminUnbindLicense(env: Env, licenseId: number): Promise<Response> {
  await env.DB.prepare(
    `DELETE FROM license_bindings
     WHERE license_code_id = ?`,
  )
    .bind(licenseId)
    .run();

  await appendEvent(env, licenseId, "admin_unbind_all", {});

  return json({
    message: "绑定记录已清空。",
  });
}

async function handleAdminDeleteLicense(
  env: Env,
  licenseId: number,
): Promise<Response> {
  await env.DB.batch([
    env.DB.prepare(
      `UPDATE orders
       SET issued_license_code_id = NULL,
           issued_code_plaintext = NULL,
           updated_at = ?
       WHERE issued_license_code_id = ?`,
    ).bind(new Date().toISOString(), licenseId),
    env.DB.prepare(
      `DELETE FROM license_bindings
       WHERE license_code_id = ?`,
    ).bind(licenseId),
    env.DB.prepare(
      `DELETE FROM license_events
       WHERE license_code_id = ?`,
    ).bind(licenseId),
    env.DB.prepare(
      `DELETE FROM license_codes
       WHERE id = ?`,
    ).bind(licenseId),
  ]);

  return json({
    message: "激活码已删除。",
  });
}

async function handleAdminMarkOrderPaid(
  request: Request,
  env: Env,
  orderId: number,
): Promise<Response> {
  const body = (await request.json()) as {
    externalPaymentId?: string;
  };

  const result = await fulfillOrder(env, {
    orderId,
    externalPaymentId: body.externalPaymentId?.trim() || `manual-${Date.now()}`,
    paymentProvider: "manual",
  });

  return json({
    message: "订单已标记为已支付并完成发码。",
    ...result,
  });
}

async function handleAdminDeleteOrder(env: Env, orderId: number): Promise<Response> {
  await env.DB.batch([
    env.DB.prepare(
      `DELETE FROM order_events
       WHERE order_id = ?`,
    ).bind(orderId),
    env.DB.prepare(
      `DELETE FROM orders
       WHERE id = ?`,
    ).bind(orderId),
  ]);

  return json({
    message: "订单已删除。已发出的激活码不会自动删除。",
  });
}

async function handleAdminBindings(env: Env, url: URL): Promise<Response> {
  const licenseId = Number(url.searchParams.get("licenseId") || "0");
  if (!Number.isFinite(licenseId) || licenseId <= 0) {
    return json({ error: "缺少合法的 licenseId。" }, 400);
  }

  const result = await env.DB.prepare(
    `SELECT
       id,
       license_code_id,
       install_id_hash,
       device_name,
       bound_at,
       last_seen_at,
       revoked_at
     FROM license_bindings
     WHERE license_code_id = ?
     ORDER BY id DESC`,
  )
    .bind(licenseId)
    .all<Record<string, unknown>>();

  return json({
    bindings: result.results ?? [],
  });
}

async function handleCreateOrder(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    productName?: string;
    buyerContact?: string;
    note?: string;
    tier?: string;
    expiresAt?: string | null;
    maxDevices?: number;
    amountCents?: number;
    currency?: string;
    paymentProvider?: string;
  };

  const order = await createOrder(env, {
    productName: body.productName?.trim() || "Xii_Raw Graph 高级授权",
    buyerContact: body.buyerContact?.trim() || null,
    note: body.note?.trim() || null,
    tier: body.tier?.trim() || "premium",
    expiresAt: body.expiresAt?.trim() || null,
    maxDevices:
      typeof body.maxDevices === "number" && body.maxDevices > 0 ? body.maxDevices : 1,
    amountCents: typeof body.amountCents === "number" ? body.amountCents : 0,
    currency: body.currency?.trim() || "CNY",
    paymentProvider: body.paymentProvider?.trim() || "manual",
  });

  return json({
    orderNo: order.orderNo,
    accessToken: order.accessToken,
    status: order.status,
    amountCents: order.amountCents,
    currency: order.currency,
    paymentProvider: order.paymentProvider,
  });
}

async function handleGetOrder(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response> {
  const parts = url.pathname.split("/");
  const orderNo = parts[parts.length - 1]?.trim() ?? "";
  const accessToken = request.headers.get("x-order-token")?.trim() ?? "";
  if (!orderNo || !accessToken) {
    return json({ error: "缺少订单号或订单访问令牌。" }, 400);
  }

  const order = await loadOrderByOrderNo(env, orderNo);
  if (!order) {
    return json({ error: "订单不存在。" }, 404);
  }

  const accessTokenHash = await sha256Hex(accessToken);
  if (accessTokenHash !== order.access_token_hash) {
    return json({ error: "订单访问令牌无效。" }, 403);
  }

  return json({
    orderNo: order.order_no,
    status: order.status,
    productName: order.product_name,
    buyerContact: order.buyer_contact,
    amountCents: order.amount_cents,
    currency: order.currency,
    licenseCode:
      order.status === "fulfilled" ? order.issued_code_plaintext : undefined,
    tier: order.tier,
    expiresAt: order.expires_at,
    createdAt: order.created_at,
    paidAt: order.paid_at,
    fulfilledAt: order.fulfilled_at,
  });
}

async function handlePaymentWebhook(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    orderNo?: string;
    externalPaymentId?: string;
    paymentProvider?: string;
    paid?: boolean;
  };

  const orderNo = body.orderNo?.trim() ?? "";
  if (!orderNo) {
    return json({ error: "缺少 orderNo。" }, 400);
  }

  if (body.paid !== true) {
    return json({ ok: true, skipped: true });
  }

  const order = await loadOrderByOrderNo(env, orderNo);
  if (!order) {
    return json({ error: "订单不存在。" }, 404);
  }

  const result = await fulfillOrder(env, {
    orderId: order.id,
    externalPaymentId:
      body.externalPaymentId?.trim() || `${body.paymentProvider || "webhook"}-${Date.now()}`,
    paymentProvider: body.paymentProvider?.trim() || "webhook",
  });

  return json({
    ok: true,
    ...result,
  });
}

async function handleValidate(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    token?: string;
    installId?: string;
  };

  const token = (body.token ?? "").trim();
  const installId = (body.installId ?? "").trim();
  if (!token || !installId) {
    return json({ error: "缺少 token 或设备标识。" }, 400);
  }

  const installIdHash = await sha256Hex(installId);
  const payload = await verifyLicenseToken(env, token);
  if (payload.installIdHash !== installIdHash) {
    return json({ error: "授权 token 与当前设备不匹配。" }, 403);
  }

  const license = await loadLicenseById(env, payload.licenseId);
  if (!license) {
    return json({ error: "授权记录不存在。" }, 404);
  }

  validateLicenseAvailability(license);

  const binding = await env.DB.prepare(
    `SELECT id, install_id_hash, revoked_at
     FROM license_bindings
     WHERE license_code_id = ? AND install_id_hash = ?
     LIMIT 1`,
  )
    .bind(license.id, installIdHash)
    .first<BindingRow>();

  if (!binding || binding.revoked_at) {
    return json({ error: "当前设备绑定已失效。" }, 403);
  }

  await env.DB.prepare(
    `UPDATE license_bindings
     SET last_seen_at = ?
     WHERE id = ?`,
  )
    .bind(new Date().toISOString(), binding.id)
    .run();

  return json({
    ok: true,
    tier: license.tier,
    expiresAt: license.expires_at,
  });
}

async function handleGenerate(
  request: Request,
  env: Env,
  _ctx: ExecutionContext,
): Promise<Response> {
  const body = (await request.json()) as {
    token?: string | null;
    installId?: string;
    prompt?: string;
    composedPrompt?: string;
    aspectRatio?: string;
    size?: string;
    quality?: string;
    referenceImage?: {
      mimeType?: string;
      bytesBase64?: string;
    } | null;
    referenceImages?: Array<{
      mimeType?: string;
      bytesBase64?: string;
    }> | null;
  };

  const referenceImages =
    body.referenceImages?.filter((item) => item?.bytesBase64?.trim()) ??
    (body.referenceImage?.bytesBase64?.trim() ? [body.referenceImage] : []);

  const installId = (body.installId ?? "").trim();
  const prompt = (body.composedPrompt ?? body.prompt ?? "").trim();
  const requestSize =
    body.size?.trim().toLowerCase() ||
    mapAspectRatioToSize(body.aspectRatio);
  const requestQuality = normalizeQuality(body.quality);
  if (!installId || !prompt) {
    return json({ error: "缺少必要请求参数。" }, 400);
  }

  const installIdHash = await sha256Hex(installId);
  const safetyResult = evaluateSafety({
    prompt,
    hasReferenceImage: referenceImages.length > 0,
  });
  if (!safetyResult.allowed) {
    await appendSafetyEvent(env, {
      category: "generation_blocked",
      safetyCode: safetyResult.code,
      prompt: prompt,
      hasReferenceImage: referenceImages.length > 0,
      installIdHash,
      payload: {
        size: requestSize,
        quality: requestQuality,
        referenceImageCount: referenceImages.length,
      },
    });
    return json(
      {
        error: SAFETY_BLOCK_MESSAGE,
        safetyCode: safetyResult.code,
      },
      400,
    );
  }

  const token = (body.token ?? "").trim();
  if (!token) {
    return json({ error: "请先激活高级功能后再调用生成接口。" }, 403);
  }

  const payload = await verifyLicenseToken(env, token);
  if (payload.installIdHash !== installIdHash) {
    return json({ error: "当前授权与设备不匹配。" }, 403);
  }

  const license = await loadLicenseById(env, payload.licenseId);
  if (!license) {
    return json({ error: "授权记录不存在。" }, 404);
  }
  validateLicenseAvailability(license);

  // Always create a fresh generation task for each user request.
  // Recovery after app restart relies on the persisted taskId locally,
  // not on reusing an old task for the same prompt/options payload.
  const idempotencyKey = await sha256Hex(
    JSON.stringify({
      licenseId: license.id,
      installIdHash,
      prompt,
      size: requestSize,
      quality: requestQuality,
      referenceImages,
      requestNonce: crypto.randomUUID(),
      requestedAt: Date.now(),
    }),
  );

  if (referenceImages.length > 0) {
    const upstreamResponse = await sendImageEditRequest(env, {
      prompt,
      size: requestSize,
      quality: requestQuality,
      referenceImages,
    });

    const upstreamText = await upstreamResponse.text();
    const payloadJson = safeParseJson(upstreamText);
    if (!upstreamResponse.ok) {
      const upstreamError = describeUpstreamError(
        upstreamResponse.status,
        payloadJson,
        upstreamText,
      );
      return json(
        {
          error: upstreamError.message,
          upstreamStatus: upstreamResponse.status,
          upstreamDetail: upstreamError.detail,
        },
        upstreamResponse.status,
      );
    }

    await appendEvent(env, license.id, "generate", {
      mode: "direct_reference",
      size: requestSize,
      quality: requestQuality,
      referenceImageCount: referenceImages.length,
    });

    return json(
      {
        taskId: null,
        status: "completed",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        completedAt: new Date().toISOString(),
        error: null,
        content:
          payloadJson?.choices?.[0]?.message?.content ??
          payloadJson?.data ??
          payloadJson,
      },
      200,
    );
  }

  const task = await createGenerationTask(env, {
    taskType: "generate",
    idempotencyKey,
    licenseCodeId: license.id,
    installIdHash,
    prompt,
    requestSize,
    requestQuality,
    referenceImagesJson: null,
  });

  await env.GENERATION_QUEUE.send({
    taskId: task.task_id,
  });
  return json(buildGenerationTaskResponse(task), 202);
}

function evaluateSafety(input: {
  prompt: string;
  hasReferenceImage: boolean;
}) {
  const normalizedPrompt = input.prompt.toLowerCase();

  for (const keyword of BLOCKED_KEYWORDS) {
    if (normalizedPrompt.includes(keyword.toLowerCase())) {
      return {
        allowed: false,
        code: "blocked_keyword",
      };
    }
  }

  if (input.hasReferenceImage) {
    for (const keyword of SUSPICIOUS_IMAGE_EDIT_KEYWORDS) {
      if (normalizedPrompt.includes(keyword.toLowerCase())) {
        return {
          allowed: false,
          code: "unsafe_reference_edit",
        };
      }
    }
  }

  return {
    allowed: true,
    code: "ok",
  };
}

function resolveImageGenerationsApiUrl(baseUrl: string) {
  const trimmed = baseUrl.replace(/\/+$/, "");
  if (trimmed.endsWith("/chat/completions")) {
    const apiRoot = trimmed.slice(0, -"/chat/completions".length);
    return `${apiRoot}/images/generations`;
  }
  if (trimmed.endsWith("/v1")) {
    return `${trimmed}/images/generations`;
  }
  return `${trimmed}/v1/images/generations`;
}

async function handleEditImage(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    token?: string | null;
    installId?: string;
    prompt?: string;
    composedPrompt?: string;
    size?: string;
    quality?: string;
    sourceImage?: {
      mimeType?: string;
      bytesBase64?: string;
      name?: string;
    } | null;
    maskImage?: {
      mimeType?: string;
      bytesBase64?: string;
      name?: string;
    } | null;
  };

  const installId = (body.installId ?? "").trim();
  const prompt = (body.composedPrompt ?? body.prompt ?? "").trim();
  const requestSize = body.size?.trim().toLowerCase() || "auto";
  const requestQuality = normalizeQuality(body.quality);
  const sourceImage = body.sourceImage;
  const maskImage = body.maskImage;

  if (!installId || !prompt || !sourceImage?.bytesBase64?.trim()) {
    return json({ error: "缺少必要请求参数。" }, 400);
  }

  const installIdHash = await sha256Hex(installId);
  const safetyResult = evaluateSafety({
    prompt,
    hasReferenceImage: true,
  });
  if (!safetyResult.allowed) {
    await appendSafetyEvent(env, {
      category: "image_edit_blocked",
      safetyCode: safetyResult.code,
      prompt: prompt,
      hasReferenceImage: true,
      installIdHash,
      payload: {
        size: requestSize,
        quality: requestQuality,
        hasMask: !!maskImage?.bytesBase64?.trim(),
      },
    });
    return json(
      {
        error: SAFETY_BLOCK_MESSAGE,
        safetyCode: safetyResult.code,
      },
      400,
    );
  }

  const token = (body.token ?? "").trim();
  if (!token) {
    return json({ error: "请先激活高级功能后再调用生成接口。" }, 403);
  }

  const payload = await verifyLicenseToken(env, token);
  if (payload.installIdHash !== installIdHash) {
    return json({ error: "当前授权与设备不匹配。" }, 403);
  }

  const license = await loadLicenseById(env, payload.licenseId);
  if (!license) {
    return json({ error: "授权记录不存在。" }, 404);
  }
  validateLicenseAvailability(license);

  const upstreamResponse = await sendImageEditRequest(env, {
    prompt,
    size: requestSize,
    quality: requestQuality,
    referenceImages: [sourceImage],
    maskImage: maskImage?.bytesBase64?.trim() ? maskImage : null,
  });

  const upstreamText = await upstreamResponse.text();
  const payloadJson = safeParseJson(upstreamText);
  if (!upstreamResponse.ok) {
    const upstreamError = describeUpstreamError(
      upstreamResponse.status,
      payloadJson,
      upstreamText,
    );
    return json(
      {
        error: upstreamError.message,
        upstreamStatus: upstreamResponse.status,
        upstreamDetail: upstreamError.detail,
      },
      upstreamResponse.status,
    );
  }

  await appendEvent(env, license.id, "edit_image", {
    size: requestSize,
    quality: requestQuality,
    hasMask: !!maskImage?.bytesBase64?.trim(),
  });

  return json({
    content: payloadJson?.data ?? payloadJson?.choices?.[0]?.message?.content ?? payloadJson,
  });
}

async function handleGetGenerationTask(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response> {
  const taskId = url.pathname.split("/").pop()?.trim() ?? "";
  const token = url.searchParams.get("token")?.trim() ?? "";
  const installId = url.searchParams.get("installId")?.trim() ?? "";
  if (!taskId || !token || !installId) {
    return json({ error: "缺少任务查询参数。" }, 400);
  }

  const installIdHash = await sha256Hex(installId);
  const payload = await verifyLicenseToken(env, token);
  if (payload.installIdHash !== installIdHash) {
    return json({ error: "当前授权与设备不匹配。" }, 403);
  }

  const task = await loadGenerationTaskByTaskId(env, taskId);
  if (!task) {
    return json({ error: "任务不存在。" }, 404);
  }
  if (task.license_code_id !== payload.licenseId || task.install_id_hash !== installIdHash) {
    return json({ error: "无权访问该任务。" }, 403);
  }

  return json(buildGenerationTaskResponse(task));
}

function resolveImageEditsApiUrl(baseUrl: string) {
  const trimmed = baseUrl.replace(/\/+$/, "");
  if (trimmed.endsWith("/chat/completions")) {
    const apiRoot = trimmed.slice(0, -"/chat/completions".length);
    return `${apiRoot}/images/edits`;
  }
  if (trimmed.endsWith("/v1")) {
    return `${trimmed}/images/edits`;
  }
  return `${trimmed}/v1/images/edits`;
}

async function sendImageEditRequest(
  env: Env,
  input: {
    prompt: string;
    size: string;
    quality: string;
    referenceImages: Array<{
      mimeType?: string;
      bytesBase64?: string;
      name?: string;
    }>;
    maskImage?: {
      mimeType?: string;
      bytesBase64?: string;
      name?: string;
    } | null;
  },
) {
  const form = new FormData();
  form.set("model", env.UPSTREAM_MODEL || "gpt-image-2");
  form.set("prompt", input.prompt);
  form.set("n", "1");
  form.set("size", input.size);
  form.set("quality", input.quality);
  form.set("output_format", "png");
  form.set("response_format", "url");
  form.set("input_fidelity", "high");

  input.referenceImages.forEach((image, index) => {
    const mimeType = image.mimeType ?? "image/png";
    const bytesBase64 = image.bytesBase64 ?? "";
    const bytes = Uint8Array.from(atob(bytesBase64), (char) =>
      char.charCodeAt(0),
    );
    const blob = new Blob([bytes], { type: mimeType });
    const extension = mimeType.split("/")[1] || "png";
    const fallbackName = `reference-${index + 1}.${extension}`;
    form.append("image", blob, image.name?.trim() || fallbackName);
  });

  if (input.maskImage?.bytesBase64?.trim()) {
    const mimeType = input.maskImage.mimeType ?? "image/png";
    const bytes = Uint8Array.from(atob(input.maskImage.bytesBase64), (char) =>
      char.charCodeAt(0),
    );
    const blob = new Blob([bytes], { type: mimeType });
    const extension = mimeType.split("/")[1] || "png";
    form.append(
      "mask",
      blob,
      input.maskImage.name?.trim() || `mask.${extension}`,
    );
  }

  return fetch(resolveImageEditsApiUrl(env.UPSTREAM_BASE_URL), {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: form,
  });
}

function mapAspectRatioToSize(aspectRatio?: string | null) {
  switch (aspectRatio?.trim()) {
    case "1:1":
      return "1024x1024";
    case "3:2":
    case "16:9":
      return "1536x1024";
    case "2:3":
    case "9:16":
      return "1024x1536";
    default:
      return "auto";
  }
}

function normalizeQuality(quality?: string | null) {
  const trimmed = quality?.trim().toLowerCase();
  if (!trimmed) {
    return "auto";
  }

  return ["low", "medium", "high", "auto"].includes(trimmed)
    ? trimmed
    : "auto";
}

async function loadLicenseByHash(env: Env, codeHash: string) {
  return env.DB.prepare(
    `SELECT id, code_hash, status, tier, expires_at, max_devices, note
     FROM license_codes
     WHERE code_hash = ?
     LIMIT 1`,
  )
    .bind(codeHash)
    .first<LicenseCodeRow>();
}

async function loadLicenseById(env: Env, id: number) {
  return env.DB.prepare(
    `SELECT id, code_hash, status, tier, expires_at, max_devices, note
     FROM license_codes
     WHERE id = ?
     LIMIT 1`,
  )
    .bind(id)
    .first<LicenseCodeRow>();
}

async function loadGenerationTaskByIdempotencyKey(
  env: Env,
  idempotencyKey: string,
): Promise<GenerationTaskRow | null> {
  const row = await env.DB.prepare(
    `SELECT * FROM generation_tasks WHERE idempotency_key = ? LIMIT 1`,
  )
    .bind(idempotencyKey)
    .first<GenerationTaskRow>();
  return row ?? null;
}

async function loadGenerationTaskByTaskId(
  env: Env,
  taskId: string,
): Promise<GenerationTaskRow | null> {
  const row = await env.DB.prepare(
    `SELECT * FROM generation_tasks WHERE task_id = ? LIMIT 1`,
  )
    .bind(taskId)
    .first<GenerationTaskRow>();
  return row ?? null;
}

async function createGenerationTask(
  env: Env,
  input: {
    taskType: string;
    idempotencyKey: string;
    licenseCodeId: number;
    installIdHash: string;
    prompt: string;
    requestSize: string;
    requestQuality: string;
    referenceImagesJson: string | null;
  },
): Promise<GenerationTaskRow> {
  const now = new Date().toISOString();
  const taskId = generateTaskId();
  await env.DB.prepare(
    `INSERT INTO generation_tasks (
      task_id,
      idempotency_key,
      license_code_id,
      install_id_hash,
      task_type,
      status,
      prompt,
      request_size,
      request_quality,
      reference_images_json,
      created_at,
      updated_at
    ) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      taskId,
      input.idempotencyKey,
      input.licenseCodeId,
      input.installIdHash,
      input.taskType,
      input.prompt,
      input.requestSize,
      input.requestQuality,
      input.referenceImagesJson,
      now,
      now,
    )
    .run();

  const task = await loadGenerationTaskByTaskId(env, taskId);
  if (!task) {
    throw new Error("Failed to create generation task.");
  }
  return task;
}

async function runGenerationTask(env: Env, task: GenerationTaskRow): Promise<void> {
  await env.DB.prepare(
    `UPDATE generation_tasks SET status = 'running', updated_at = ? WHERE id = ?`,
  )
    .bind(new Date().toISOString(), task.id)
    .run();

  const referenceImages = safeParseJson(task.reference_images_json || "[]");
  const upstreamBody = {
    model: env.UPSTREAM_MODEL || "gpt-image-2",
    prompt: task.prompt,
    n: 1,
    size: task.request_size,
    quality: task.request_quality,
  };

  const upstreamResponse =
    Array.isArray(referenceImages) && referenceImages.length > 0
      ? await sendImageEditRequest(env, {
          prompt: task.prompt,
          size: task.request_size,
          quality: task.request_quality,
          referenceImages,
        })
      : await fetch(resolveImageGenerationsApiUrl(env.UPSTREAM_BASE_URL), {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${env.OPENAI_API_KEY}`,
          },
          body: JSON.stringify({
            ...upstreamBody,
            output_format: "png",
            response_format: "url",
          }),
        });

  const upstreamText = await upstreamResponse.text();
  const payloadJson = safeParseJson(upstreamText);
  const now = new Date().toISOString();

  if (!upstreamResponse.ok) {
    const upstreamError = describeUpstreamError(
      upstreamResponse.status,
      payloadJson,
      upstreamText,
    );
    await env.DB.prepare(
      `UPDATE generation_tasks
       SET status = 'failed',
           error_message = ?,
           upstream_status = ?,
           updated_at = ?,
           completed_at = ?
       WHERE id = ?`,
    )
      .bind(
        upstreamError.message,
        upstreamResponse.status,
        now,
        now,
        task.id,
      )
      .run();
    return;
  }

  await env.DB.prepare(
    `UPDATE generation_tasks
     SET status = 'completed',
         result_json = ?,
         upstream_status = ?,
         updated_at = ?,
         completed_at = ?
     WHERE id = ?`,
  )
    .bind(
      JSON.stringify(
        payloadJson?.choices?.[0]?.message?.content ?? payloadJson?.data ?? payloadJson,
      ),
      upstreamResponse.status,
      now,
      now,
      task.id,
    )
    .run();

  await appendEvent(env, task.license_code_id, "generate", {
    taskId: task.task_id,
    size: task.request_size,
    quality: task.request_quality,
    referenceImageCount:
      Array.isArray(referenceImages) ? referenceImages.length : 0,
  });
}

function buildGenerationTaskResponse(task: GenerationTaskRow) {
  return {
    taskId: task.task_id,
    status: task.status,
    createdAt: task.created_at,
    updatedAt: task.updated_at,
    completedAt: task.completed_at,
    error: task.error_message,
    content: task.result_json ? safeParseJson(task.result_json) : null,
  };
}

async function loadActiveBindings(env: Env, licenseCodeId: number) {
  const result = await env.DB.prepare(
    `SELECT id, install_id_hash, revoked_at
     FROM license_bindings
     WHERE license_code_id = ? AND revoked_at IS NULL`,
  )
    .bind(licenseCodeId)
    .all<BindingRow>();

  return result.results ?? [];
}

function validateLicenseAvailability(license: LicenseCodeRow) {
  if (license.status !== "active") {
    throw new Error("激活码当前不可用。");
  }

  if (license.expires_at && new Date(license.expires_at).getTime() < Date.now()) {
    throw new Error("激活码已过期。");
  }
}

async function appendEvent(
  env: Env,
  licenseCodeId: number,
  eventType: string,
  payload: unknown,
) {
  await env.DB.prepare(
    `INSERT INTO license_events (
      license_code_id,
      event_type,
      payload_json,
      created_at
    ) VALUES (?, ?, ?, ?)`,
  )
    .bind(licenseCodeId, eventType, JSON.stringify(payload), new Date().toISOString())
    .run();
}

async function appendSafetyEvent(
  env: Env,
  input: {
    category: string;
    safetyCode: string;
    prompt: string;
    hasReferenceImage: boolean;
    installIdHash: string | null;
    licenseCodeId?: number | null;
    payload: unknown;
  },
) {
  const promptExcerpt = input.prompt.trim().slice(0, 160);
  await env.DB.prepare(
    `INSERT INTO safety_events (
      category,
      safety_code,
      prompt_excerpt,
      has_reference_image,
      license_code_id,
      install_id_hash,
      payload_json,
      created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      input.category,
      input.safetyCode,
      promptExcerpt,
      input.hasReferenceImage ? 1 : 0,
      input.licenseCodeId ?? null,
      input.installIdHash,
      JSON.stringify(input.payload),
      new Date().toISOString(),
    )
    .run();
}

async function appendOrderEvent(
  env: Env,
  orderId: number,
  eventType: string,
  payload: unknown,
) {
  await env.DB.prepare(
    `INSERT INTO order_events (
      order_id,
      event_type,
      payload_json,
      created_at
    ) VALUES (?, ?, ?, ?)`,
  )
    .bind(orderId, eventType, JSON.stringify(payload), new Date().toISOString())
    .run();
}

async function createOrder(
  env: Env,
  input: {
    productName: string;
    buyerContact: string | null;
    note: string | null;
    tier: string;
    expiresAt: string | null;
    maxDevices: number;
    amountCents: number;
    currency: string;
    paymentProvider: string;
  },
) {
  const orderNo = buildOrderNo();
  const accessToken = buildOrderAccessToken();
  const accessTokenHash = await sha256Hex(accessToken);
  const now = new Date().toISOString();

  const result = await env.DB.prepare(
    `INSERT INTO orders (
      order_no,
      access_token_hash,
      status,
      product_name,
      tier,
      max_devices,
      expires_at,
      buyer_contact,
      note,
      payment_provider,
      amount_cents,
      currency,
      created_at,
      updated_at
    ) VALUES (?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      orderNo,
      accessTokenHash,
      input.productName,
      input.tier,
      input.maxDevices,
      input.expiresAt,
      input.buyerContact,
      input.note,
      input.paymentProvider,
      input.amountCents,
      input.currency,
      now,
      now,
    )
    .run();

  const orderId = Number(result.meta.last_row_id);
  await appendOrderEvent(env, orderId, "created", {
    productName: input.productName,
    buyerContact: input.buyerContact,
    amountCents: input.amountCents,
    currency: input.currency,
  });

  return {
    id: orderId,
    orderNo,
    accessToken,
    status: "pending",
    amountCents: input.amountCents,
    currency: input.currency,
    paymentProvider: input.paymentProvider,
  };
}

async function fulfillOrder(
  env: Env,
  input: {
    orderId: number;
    externalPaymentId: string;
    paymentProvider: string;
  },
) {
  const order = await loadOrderById(env, input.orderId);
  if (!order) {
    throw new Error("订单不存在。");
  }

  if (order.status === "fulfilled" && order.issued_code_plaintext) {
    return {
      orderNo: order.order_no,
      status: order.status,
      licenseCode: order.issued_code_plaintext,
      licenseCodeId: order.issued_license_code_id,
    };
  }

  const licenseCodePlaintext = generateLicenseCode();
  const licenseCodeHash = await sha256Hex(licenseCodePlaintext);
  const now = new Date().toISOString();

  const licenseInsert = await env.DB.prepare(
    `INSERT INTO license_codes (
      code_hash,
      status,
      tier,
      expires_at,
      max_devices,
      note,
      created_at,
      updated_at
    ) VALUES (?, 'active', ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      licenseCodeHash,
      order.tier,
      order.expires_at,
      order.max_devices,
      order.note || `order:${order.order_no}`,
      now,
      now,
    )
    .run();

  const licenseCodeId = Number(licenseInsert.meta.last_row_id);

  await env.DB.prepare(
    `UPDATE orders
     SET status = 'fulfilled',
         external_payment_id = ?,
         payment_provider = ?,
         issued_license_code_id = ?,
         issued_code_plaintext = ?,
         paid_at = COALESCE(paid_at, ?),
         fulfilled_at = ?,
         updated_at = ?
     WHERE id = ?`,
  )
    .bind(
      input.externalPaymentId,
      input.paymentProvider,
      licenseCodeId,
      licenseCodePlaintext,
      now,
      now,
      now,
      order.id,
    )
    .run();

  await appendOrderEvent(env, order.id, "fulfilled", {
    externalPaymentId: input.externalPaymentId,
    paymentProvider: input.paymentProvider,
    licenseCodeId,
  });

  await appendEvent(env, licenseCodeId, "issued_for_order", {
    orderNo: order.order_no,
    buyerContact: order.buyer_contact,
  });

  return {
    orderNo: order.order_no,
    status: "fulfilled",
    licenseCode: licenseCodePlaintext,
    licenseCodeId,
  };
}

async function loadOrderById(env: Env, id: number) {
  return env.DB.prepare(
    `SELECT
      id,
      order_no,
      access_token_hash,
      status,
      product_name,
      tier,
      max_devices,
      expires_at,
      buyer_contact,
      note,
      payment_provider,
      amount_cents,
      currency,
      external_payment_id,
      issued_license_code_id,
      issued_code_plaintext,
      created_at,
      paid_at,
      fulfilled_at,
      updated_at
     FROM orders
     WHERE id = ?
     LIMIT 1`,
  )
    .bind(id)
    .first<OrderRow>();
}

async function loadOrderByOrderNo(env: Env, orderNo: string) {
  return env.DB.prepare(
    `SELECT
      id,
      order_no,
      access_token_hash,
      status,
      product_name,
      tier,
      max_devices,
      expires_at,
      buyer_contact,
      note,
      payment_provider,
      amount_cents,
      currency,
      external_payment_id,
      issued_license_code_id,
      issued_code_plaintext,
      created_at,
      paid_at,
      fulfilled_at,
      updated_at
     FROM orders
     WHERE order_no = ?
     LIMIT 1`,
  )
    .bind(orderNo)
    .first<OrderRow>();
}

async function signLicenseToken(
  env: Env,
  payload: {
    licenseId: number;
    installIdHash: string;
    tier: string;
    expiresAt: string | null;
  },
) {
  const encodedPayload = toBase64Url(
    JSON.stringify({
      licenseId: payload.licenseId,
      installIdHash: payload.installIdHash,
      tier: payload.tier,
      expiresAt: payload.expiresAt,
      issuedAt: new Date().toISOString(),
    }),
  );
  const signature = await hmacSha256Base64Url(env.LICENSE_SIGNING_SECRET, encodedPayload);
  return `${encodedPayload}.${signature}`;
}

async function verifyLicenseToken(env: Env, token: string) {
  const [encodedPayload, signature] = token.split(".");
  if (!encodedPayload || !signature) {
    throw new Error("授权 token 格式无效。");
  }

  const expectedSignature = await hmacSha256Base64Url(
    env.LICENSE_SIGNING_SECRET,
    encodedPayload,
  );
  if (expectedSignature !== signature) {
    throw new Error("授权 token 签名无效。");
  }

  const payload = JSON.parse(fromBase64Url(encodedPayload)) as {
    licenseId: number;
    installIdHash: string;
    tier: string;
    expiresAt: string | null;
  };

  if (payload.expiresAt && new Date(payload.expiresAt).getTime() < Date.now()) {
    throw new Error("授权 token 已过期。");
  }

  return payload;
}

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((item) => item.toString(16).padStart(2, "0"))
    .join("");
}

async function hmacSha256Base64Url(secret: string, value: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    {
      name: "HMAC",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(value),
  );
  return toBase64Url(signature);
}

function toBase64Url(value: string | ArrayBuffer) {
  const bytes =
    typeof value === "string"
      ? new TextEncoder().encode(value)
      : new Uint8Array(value);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function fromBase64Url(value: string) {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

function safeParseJson(value: string) {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function describeUpstreamError(
  status: number,
  payloadJson: any,
  rawText: string,
) {
  const primaryCandidates = [
    payloadJson?.error?.message,
    typeof payloadJson?.error === "string" ? payloadJson.error : null,
    payloadJson?.message,
    payloadJson?.detail,
  ].filter((value) => typeof value === "string" && value.trim().length > 0) as string[];

  const detailCandidates = [
    payloadJson?.error?.type,
    payloadJson?.error?.code,
    payloadJson?.request_id,
    payloadJson?.requestId,
  ].filter((value) => typeof value === "string" && value.trim().length > 0) as string[];

  let message = primaryCandidates[0] ?? `上游请求失败：HTTP ${status}`;
  const normalizedMessage = message.trim().toLowerCase();
  const detailParts = [...detailCandidates];

  if (
    normalizedMessage === "openai_error" ||
    normalizedMessage === "packy_api_error" ||
    normalizedMessage === "error"
  ) {
    message = `上游请求失败：HTTP ${status}`;
  }

  const rawSnippet = rawText.trim().replace(/\s+/g, " ").slice(0, 240);
  if (
    rawSnippet &&
    rawSnippet.toLowerCase() !== normalizedMessage &&
    !detailParts.includes(rawSnippet)
  ) {
    detailParts.push(rawSnippet);
  }

  const detail = detailParts.join(" | ");
  if (detail.length > 0) {
    message = `${message} (${detail})`;
  }

  return { message, detail };
}

function generateLicenseCode() {
  const segments = [
    "XII",
    new Date().getFullYear().toString(),
    randomSegment(4),
    randomSegment(4),
  ];
  return segments.join("-");
}

function buildOrderNo() {
  const timestamp = new Date()
    .toISOString()
    .replace(/[-:TZ.]/g, "")
    .slice(0, 14);
  return `XIIORD-${timestamp}-${randomSegment(6)}`;
}

function buildOrderAccessToken() {
  return `${randomSegment(8)}${randomSegment(8)}${randomSegment(8)}`;
}

function generateTaskId() {
  return `img_${randomSegment(6)}${randomSegment(6)}${randomSegment(6)}`;
}

function randomSegment(length: number) {
  return crypto
    .getRandomValues(new Uint8Array(length * 2))
    .reduce((acc, item) => acc + item.toString(16).padStart(2, "0"), "")
    .replace(/[^a-z0-9]/gi, "")
    .toUpperCase()
    .slice(0, length)
    .padEnd(length, "X");
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}
