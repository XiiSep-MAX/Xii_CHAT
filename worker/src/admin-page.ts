export function renderAdminPage() {
  return `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Xii License Admin</title>
    <style>
      :root {
        color-scheme: light;
        --bg: #f4f6fb;
        --card: #ffffff;
        --border: #dbe1ef;
        --text: #162033;
        --muted: #5b667c;
        --accent: #2458ff;
        --accent-soft: #e8efff;
        --danger: #c73b3b;
        --success: #1b8f5d;
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
        background:
          radial-gradient(circle at top left, rgba(36, 88, 255, 0.12), transparent 35%),
          linear-gradient(180deg, #f8faff 0%, var(--bg) 100%);
        color: var(--text);
      }

      .wrap {
        max-width: 1240px;
        margin: 0 auto;
        padding: 24px;
      }

      .hero {
        display: grid;
        gap: 18px;
        margin-bottom: 20px;
      }

      .hero-card,
      .panel {
        background: rgba(255, 255, 255, 0.92);
        border: 1px solid var(--border);
        border-radius: 20px;
        box-shadow: 0 12px 32px rgba(27, 44, 94, 0.08);
      }

      .hero-card {
        padding: 22px;
      }

      .hero-card h1 {
        margin: 0 0 8px;
        font-size: 30px;
      }

      .hero-card p {
        margin: 0;
        color: var(--muted);
        line-height: 1.6;
      }

      .grid {
        display: grid;
        grid-template-columns: 360px minmax(0, 1fr);
        gap: 18px;
      }

      .panel {
        padding: 18px;
      }

      .panel h2 {
        margin: 0 0 16px;
        font-size: 18px;
      }

      .field {
        display: grid;
        gap: 8px;
        margin-bottom: 12px;
      }

      .field label {
        font-size: 13px;
        color: var(--muted);
        font-weight: 600;
      }

      input,
      button,
      textarea {
        font: inherit;
      }

      input,
      textarea {
        width: 100%;
        padding: 11px 12px;
        border-radius: 12px;
        border: 1px solid var(--border);
        background: #fff;
        color: var(--text);
      }

      textarea {
        min-height: 120px;
        resize: vertical;
      }

      .row {
        display: grid;
        gap: 12px;
        grid-template-columns: 1fr 1fr;
      }

      .actions {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
      }

      button {
        border: 0;
        border-radius: 12px;
        padding: 11px 14px;
        cursor: pointer;
        background: var(--accent);
        color: white;
        font-weight: 600;
      }

      button.secondary {
        background: var(--accent-soft);
        color: var(--accent);
      }

      button.ghost {
        background: #eef2f9;
        color: var(--text);
      }

      button.danger {
        background: #ffe7e7;
        color: var(--danger);
      }

      .status-bar {
        margin-top: 12px;
        padding: 12px 14px;
        border-radius: 14px;
        background: #f3f6fd;
        color: var(--muted);
        min-height: 48px;
        line-height: 1.5;
      }

      .status-bar.success {
        background: #e9f9f1;
        color: var(--success);
      }

      .status-bar.error {
        background: #fff0f0;
        color: var(--danger);
      }

      .token-line {
        display: grid;
        grid-template-columns: minmax(0, 1fr) auto;
        gap: 10px;
      }

      .toolbar {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        margin-bottom: 14px;
      }

      table {
        width: 100%;
        border-collapse: collapse;
      }

      th,
      td {
        padding: 12px 10px;
        border-bottom: 1px solid #edf1f8;
        vertical-align: top;
        text-align: left;
        font-size: 13px;
      }

      th {
        color: var(--muted);
        font-weight: 700;
      }

      .pill {
        display: inline-flex;
        align-items: center;
        border-radius: 999px;
        padding: 4px 10px;
        background: #edf3ff;
        color: var(--accent);
        font-size: 12px;
        font-weight: 700;
      }

      .pill.disabled {
        background: #fff0f0;
        color: var(--danger);
      }

      .mono {
        font-family: "Consolas", "SFMono-Regular", monospace;
        font-size: 12px;
      }

      .table-actions {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
      }

      .table-actions button {
        padding: 7px 10px;
        border-radius: 10px;
        font-size: 12px;
      }

      .code-box {
        margin-top: 14px;
        padding: 14px;
        border-radius: 16px;
        background: #0f1728;
        color: #e8eefc;
      }

      .code-box strong {
        display: block;
        margin-bottom: 8px;
        color: white;
      }

      .muted {
        color: var(--muted);
      }

      .section-split {
        margin-top: 22px;
        padding-top: 22px;
        border-top: 1px solid #edf1f8;
      }

      @media (max-width: 980px) {
        .grid {
          grid-template-columns: 1fr;
        }
      }
    </style>
  </head>
  <body>
    <div class="wrap">
      <section class="hero">
        <div class="hero-card">
          <h1>Xii License Admin</h1>
          <p>这个页面是最小商用后台，用来发码、延长授权、禁用激活码和清空绑定。页面本身可以公开访问，但所有管理接口都需要你的管理员 Token。</p>
        </div>
      </section>

      <section class="grid">
        <div class="panel">
          <h2>管理员 Token</h2>
          <div class="field">
            <label for="adminToken">ADMIN_ACCESS_TOKEN</label>
            <div class="token-line">
              <input id="adminToken" type="password" placeholder="输入你的后台管理 Token" />
              <button id="saveTokenBtn" class="secondary" type="button">保存</button>
            </div>
          </div>

          <div class="field">
            <label for="customCode">自定义激活码（可选）</label>
            <input id="customCode" type="text" placeholder="例如 XII-2026-ABCD-EFGH" />
          </div>

          <div class="field">
            <label for="note">备注</label>
            <input id="note" type="text" placeholder="例如 首批付费用户 / 4月续费" />
          </div>

          <div class="row">
            <div class="field">
              <label for="tier">套餐级别</label>
              <input id="tier" type="text" value="premium" />
            </div>
            <div class="field">
              <label for="maxDevices">设备数</label>
              <input id="maxDevices" type="number" value="1" min="1" />
            </div>
          </div>

          <div class="field">
            <label for="expiresAt">有效期（ISO 或 datetime-local）</label>
            <input id="expiresAt" type="text" value="2027-12-31T23:59:59.000Z" />
          </div>

          <div class="actions">
            <button id="createBtn" type="button">创建激活码</button>
            <button id="reloadBtn" class="secondary" type="button">刷新列表</button>
          </div>

          <div id="statusBar" class="status-bar">先保存管理员 Token，再创建或管理激活码。</div>
          <div id="createdCodeBox" class="code-box" style="display:none;"></div>

          <div class="section-split">
            <h2>订单与自动发码</h2>
            <div class="field">
              <label for="orderProductName">商品名称</label>
              <input id="orderProductName" type="text" value="Xii_Raw Graph 高级授权" />
            </div>
            <div class="field">
              <label for="orderBuyerContact">买家联系方式</label>
              <input id="orderBuyerContact" type="text" placeholder="例如 微信 / QQ / 邮箱 / 订单备注" />
            </div>
            <div class="row">
              <div class="field">
                <label for="orderAmountCents">金额（分）</label>
                <input id="orderAmountCents" type="number" value="1990" min="0" />
              </div>
              <div class="field">
                <label for="orderCurrency">币种</label>
                <input id="orderCurrency" type="text" value="CNY" />
              </div>
            </div>
            <div class="field">
              <label for="orderPaymentProvider">支付渠道标记</label>
              <input id="orderPaymentProvider" type="text" value="manual" />
            </div>
            <div class="actions">
              <button id="createOrderBtn" type="button">创建订单</button>
              <button id="reloadOrdersBtn" class="secondary" type="button">刷新订单</button>
            </div>
            <div id="createdOrderBox" class="code-box" style="display:none;"></div>
          </div>
        </div>

        <div class="panel">
          <h2>激活码列表</h2>
          <div class="toolbar">
            <input id="searchInput" type="text" placeholder="按备注 / 状态 / 套餐搜索" />
            <button id="searchBtn" class="secondary" type="button">搜索</button>
          </div>

          <div style="overflow:auto;">
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>状态</th>
                  <th>套餐</th>
                  <th>到期时间</th>
                  <th>设备数</th>
                  <th>绑定</th>
                  <th>备注</th>
                  <th>操作</th>
                </tr>
              </thead>
              <tbody id="licenseTableBody">
                <tr>
                  <td colspan="8" class="muted">正在等待加载...</td>
                </tr>
              </tbody>
            </table>
          </div>

          <h2 style="margin-top:22px;">绑定记录</h2>
          <textarea id="bindingsBox" readonly placeholder="点击某条记录的“绑定”按钮后，这里会显示该激活码绑定过的设备。"></textarea>

          <h2 style="margin-top:22px;">订单列表</h2>
          <div style="overflow:auto;">
            <table>
              <thead>
                <tr>
                  <th>订单号</th>
                  <th>状态</th>
                  <th>金额</th>
                  <th>买家</th>
                  <th>发码结果</th>
                  <th>操作</th>
                </tr>
              </thead>
              <tbody id="orderTableBody">
                <tr>
                  <td colspan="6" class="muted">正在等待加载...</td>
                </tr>
              </tbody>
            </table>
          </div>

          <h2 style="margin-top:22px;">安全拦截日志</h2>
          <div style="overflow:auto;">
            <table>
              <thead>
                <tr>
                  <th>时间</th>
                  <th>类型</th>
                  <th>规则</th>
                  <th>参考图</th>
                  <th>提示词片段</th>
                </tr>
              </thead>
              <tbody id="safetyEventTableBody">
                <tr>
                  <td colspan="5" class="muted">正在等待加载...</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>
    </div>

    <script>
      const tokenKey = "xii_admin_access_token";
      const tokenInput = document.getElementById("adminToken");
      const saveTokenBtn = document.getElementById("saveTokenBtn");
      const createBtn = document.getElementById("createBtn");
      const reloadBtn = document.getElementById("reloadBtn");
      const searchBtn = document.getElementById("searchBtn");
      const searchInput = document.getElementById("searchInput");
      const statusBar = document.getElementById("statusBar");
      const createdCodeBox = document.getElementById("createdCodeBox");
      const createdOrderBox = document.getElementById("createdOrderBox");
      const licenseTableBody = document.getElementById("licenseTableBody");
      const orderTableBody = document.getElementById("orderTableBody");
      const safetyEventTableBody = document.getElementById("safetyEventTableBody");
      const bindingsBox = document.getElementById("bindingsBox");

      const codeInput = document.getElementById("customCode");
      const noteInput = document.getElementById("note");
      const tierInput = document.getElementById("tier");
      const maxDevicesInput = document.getElementById("maxDevices");
      const expiresAtInput = document.getElementById("expiresAt");
      const createOrderBtn = document.getElementById("createOrderBtn");
      const reloadOrdersBtn = document.getElementById("reloadOrdersBtn");
      const orderProductNameInput = document.getElementById("orderProductName");
      const orderBuyerContactInput = document.getElementById("orderBuyerContact");
      const orderAmountCentsInput = document.getElementById("orderAmountCents");
      const orderCurrencyInput = document.getElementById("orderCurrency");
      const orderPaymentProviderInput = document.getElementById("orderPaymentProvider");

      tokenInput.value = localStorage.getItem(tokenKey) || "";

      saveTokenBtn.addEventListener("click", () => {
        localStorage.setItem(tokenKey, tokenInput.value.trim());
        showStatus("管理员 Token 已保存到当前浏览器。", "success");
      });

      createBtn.addEventListener("click", async () => {
        try {
          const payload = {
            code: codeInput.value.trim() || undefined,
            note: noteInput.value.trim() || undefined,
            tier: tierInput.value.trim() || undefined,
            expiresAt: normalizeExpiry(expiresAtInput.value.trim()),
            maxDevices: Number(maxDevicesInput.value || "1"),
          };
          const result = await api("/v1/admin/licenses", {
            method: "POST",
            body: payload,
          });
          createdCodeBox.style.display = "block";
          createdCodeBox.innerHTML =
            "<strong>新激活码已创建</strong>" +
            "<div class='mono'>" + escapeHtml(result.code || "-") + "</div>" +
            "<div style='margin-top:8px;' class='muted'>请把这串明文码发给用户，数据库里只会保留 hash。</div>";
          showStatus(result.message || "创建成功。", "success");
          await loadLicenses();
          await loadSafetyEvents();
        } catch (error) {
          showStatus(error.message || String(error), "error");
        }
      });

      reloadBtn.addEventListener("click", () => {
        loadLicenses();
      });

      createOrderBtn.addEventListener("click", async () => {
        try {
          const payload = {
            productName: orderProductNameInput.value.trim() || undefined,
            buyerContact: orderBuyerContactInput.value.trim() || undefined,
            note: noteInput.value.trim() || undefined,
            tier: tierInput.value.trim() || undefined,
            expiresAt: normalizeExpiry(expiresAtInput.value.trim()),
            maxDevices: Number(maxDevicesInput.value || "1"),
            amountCents: Number(orderAmountCentsInput.value || "0"),
            currency: orderCurrencyInput.value.trim() || "CNY",
            paymentProvider: orderPaymentProviderInput.value.trim() || "manual",
          };
          const result = await api("/v1/admin/orders", {
            method: "POST",
            body: payload,
          });
          createdOrderBox.style.display = "block";
          createdOrderBox.innerHTML =
            "<strong>新订单已创建</strong>" +
            "<div class='mono'>订单号: " + escapeHtml(result.orderNo || "-") + "</div>" +
            "<div class='mono'>访问令牌: " + escapeHtml(result.accessToken || "-") + "</div>" +
            "<div style='margin-top:8px;' class='muted'>支付完成后，可以通过后台手动标记已支付，系统会自动生成并绑定一条激活码到这个订单。</div>";
          showStatus(result.message || "订单创建成功。", "success");
          await loadOrders();
          await loadSafetyEvents();
        } catch (error) {
          showStatus(error.message || String(error), "error");
        }
      });

      reloadOrdersBtn.addEventListener("click", () => {
        loadOrders();
      });

      searchBtn.addEventListener("click", () => {
        loadLicenses(searchInput.value.trim());
      });

      licenseTableBody.addEventListener("click", async (event) => {
        const target = event.target;
        if (!(target instanceof HTMLButtonElement)) {
          return;
        }

        const action = target.dataset.action;
        const id = target.dataset.id;
        if (!action || !id) {
          return;
        }

        try {
          if (action === "toggle") {
            const nextStatus = target.dataset.nextStatus;
            await api("/v1/admin/licenses/" + id + "/update", {
              method: "POST",
              body: { status: nextStatus },
            });
            showStatus("状态已更新。", "success");
            await loadLicenses(searchInput.value.trim());
            return;
          }

          if (action === "extend") {
            const nextExpiry = window.prompt(
              "输入新的到期时间（ISO 格式）",
              target.dataset.expiresAt || "2028-12-31T23:59:59.000Z",
            );
            if (!nextExpiry) {
              return;
            }
            await api("/v1/admin/licenses/" + id + "/update", {
              method: "POST",
              body: { expiresAt: normalizeExpiry(nextExpiry) },
            });
            showStatus("有效期已更新。", "success");
            await loadLicenses(searchInput.value.trim());
            return;
          }

          if (action === "devices") {
            const nextDevices = window.prompt(
              "输入新的设备上限",
              target.dataset.maxDevices || "1",
            );
            if (!nextDevices) {
              return;
            }
            await api("/v1/admin/licenses/" + id + "/update", {
              method: "POST",
              body: { maxDevices: Number(nextDevices) },
            });
            showStatus("设备上限已更新。", "success");
            await loadLicenses(searchInput.value.trim());
            return;
          }

          if (action === "bindings") {
            const result = await api("/v1/admin/bindings?licenseId=" + encodeURIComponent(id));
            const bindings = Array.isArray(result.bindings) ? result.bindings : [];
            if (bindings.length === 0) {
              bindingsBox.value = "当前没有绑定记录。";
            } else {
              bindingsBox.value = JSON.stringify(bindings, null, 2);
            }
            showStatus("绑定记录已加载。", "success");
            return;
          }

          if (action === "unbind") {
            const confirmed = window.confirm("确定要清空这条激活码的所有绑定吗？");
            if (!confirmed) {
              return;
            }
            await api("/v1/admin/licenses/" + id + "/unbind", {
              method: "POST",
            });
            bindingsBox.value = "";
            showStatus("绑定已清空。", "success");
            await loadLicenses(searchInput.value.trim());
            await loadSafetyEvents();
            return;
          }

          if (action === "delete-license") {
            const confirmed = window.confirm(
              "确定要删除这条激活码吗？这会清空绑定，并断开与已关联订单的发码引用。",
            );
            if (!confirmed) {
              return;
            }
            await api("/v1/admin/licenses/" + id, {
              method: "DELETE",
            });
            bindingsBox.value = "";
            showStatus("激活码已删除。", "success");
            await loadLicenses(searchInput.value.trim());
            await loadSafetyEvents();
          }
        } catch (error) {
          showStatus(error.message || String(error), "error");
        }
      });

      orderTableBody.addEventListener("click", async (event) => {
        const target = event.target;
        if (!(target instanceof HTMLButtonElement)) {
          return;
        }

        const action = target.dataset.action;
        const id = target.dataset.id;
        if (!action || !id) {
          return;
        }

        try {
          if (action === "mark-paid") {
            const externalPaymentId =
              window.prompt("输入外部支付单号（可选）", "manual-" + Date.now()) ||
              "";
            const result = await api("/v1/admin/orders/" + id + "/mark-paid", {
              method: "POST",
              body: {
                externalPaymentId,
              },
            });
            createdOrderBox.style.display = "block";
            createdOrderBox.innerHTML =
              "<strong>订单已自动发码</strong>" +
              "<div class='mono'>订单号: " + escapeHtml(result.orderNo || "-") + "</div>" +
              "<div class='mono'>激活码: " + escapeHtml(result.licenseCode || "-") + "</div>";
            showStatus(result.message || "订单已支付并完成自动发码。", "success");
            await loadOrders();
            await loadLicenses();
            await loadSafetyEvents();
            return;
          }

          if (action === "delete-order") {
            const confirmed = window.confirm(
              "确定要删除这笔订单吗？订单事件会一起删除，但已经发出的激活码不会自动删除。",
            );
            if (!confirmed) {
              return;
            }
            await api("/v1/admin/orders/" + id, {
              method: "DELETE",
            });
            showStatus("订单已删除。", "success");
            await loadOrders();
            await loadSafetyEvents();
          }
        } catch (error) {
          showStatus(error.message || String(error), "error");
        }
      });

      async function loadLicenses(search = "") {
        try {
          showStatus("正在加载激活码列表...", "");
          const query = search ? "?q=" + encodeURIComponent(search) : "";
          const result = await api("/v1/admin/licenses" + query);
          const items = Array.isArray(result.items) ? result.items : [];
          renderLicenses(items);
          showStatus("列表已更新。", "success");
        } catch (error) {
          renderLicenses([]);
          showStatus(error.message || String(error), "error");
        }
      }

      async function loadOrders(search = "") {
        try {
          const query = search ? "?q=" + encodeURIComponent(search) : "";
          const result = await api("/v1/admin/orders" + query);
          const items = Array.isArray(result.items) ? result.items : [];
          renderOrders(items);
        } catch (error) {
          renderOrders([]);
          showStatus(error.message || String(error), "error");
        }
      }

      async function loadSafetyEvents(search = "") {
        try {
          const query = search ? "?q=" + encodeURIComponent(search) : "";
          const result = await api("/v1/admin/safety-events" + query);
          const items = Array.isArray(result.items) ? result.items : [];
          renderSafetyEvents(items);
        } catch (error) {
          renderSafetyEvents([]);
          showStatus(error.message || String(error), "error");
        }
      }

      function renderLicenses(items) {
        if (!items.length) {
          licenseTableBody.innerHTML =
            "<tr><td colspan='8' class='muted'>没有查到记录。</td></tr>";
          return;
        }

        licenseTableBody.innerHTML = items
          .map((item) => {
            const disabledClass = item.status === "active" ? "" : " disabled";
            const nextStatus = item.status === "active" ? "disabled" : "active";
            const toggleLabel = item.status === "active" ? "禁用" : "启用";
            return \`
              <tr>
                <td class="mono">\${escapeHtml(String(item.id))}</td>
                <td><span class="pill\${disabledClass}">\${escapeHtml(item.status || "-")}</span></td>
                <td>\${escapeHtml(item.tier || "-")}</td>
                <td class="mono">\${escapeHtml(item.expires_at || "永久")}</td>
                <td>\${escapeHtml(String(item.max_devices ?? "-"))}</td>
                <td>\${escapeHtml(String(item.binding_count ?? 0))}</td>
                <td>\${escapeHtml(item.note || "-")}</td>
                <td>
                  <div class="table-actions">
                    <button class="ghost" data-action="bindings" data-id="\${item.id}">绑定</button>
                    <button class="ghost" data-action="extend" data-id="\${item.id}" data-expires-at="\${escapeHtml(item.expires_at || "")}">延期</button>
                    <button class="ghost" data-action="devices" data-id="\${item.id}" data-max-devices="\${escapeHtml(String(item.max_devices ?? 1))}">设备数</button>
                    <button class="secondary" data-action="toggle" data-id="\${item.id}" data-next-status="\${nextStatus}">\${toggleLabel}</button>
                    <button class="danger" data-action="unbind" data-id="\${item.id}">清绑定</button>
                    <button class="danger" data-action="delete-license" data-id="\${item.id}">删除</button>
                  </div>
                </td>
              </tr>
            \`;
          })
          .join("");
      }

      function renderOrders(items) {
        if (!items.length) {
          orderTableBody.innerHTML =
            "<tr><td colspan='6' class='muted'>没有查到订单记录。</td></tr>";
          return;
        }

        orderTableBody.innerHTML = items
          .map((item) => {
            const statusClass = item.status === "fulfilled" ? "" : item.status === "pending" ? "" : " disabled";
            const amountLabel = item.amount_cents == null
              ? "-"
              : ((Number(item.amount_cents) / 100).toFixed(2) + " " + (item.currency || "CNY"));
            const actions = [];
            if (item.status === "pending") {
              actions.push("<button class='secondary' data-action='mark-paid' data-id='" + escapeHtml(String(item.id)) + "'>标记已支付并发码</button>");
            } else {
              actions.push("<span class='muted'>已完成</span>");
            }
            actions.push("<button class='danger' data-action='delete-order' data-id='" + escapeHtml(String(item.id)) + "'>删除订单</button>");
            return \`
              <tr>
                <td class="mono">\${escapeHtml(item.order_no || "-")}</td>
                <td><span class="pill\${statusClass}">\${escapeHtml(item.status || "-")}</span></td>
                <td>\${escapeHtml(amountLabel)}</td>
                <td>\${escapeHtml(item.buyer_contact || "-")}</td>
                <td class="mono">\${escapeHtml(item.issued_code_plaintext || "-")}</td>
                <td><div class="table-actions">\${actions.join("")}</div></td>
              </tr>
            \`;
          })
          .join("");
      }

      function renderSafetyEvents(items) {
        if (!items.length) {
          safetyEventTableBody.innerHTML =
            "<tr><td colspan='5' class='muted'>暂无安全拦截记录。</td></tr>";
          return;
        }

        safetyEventTableBody.innerHTML = items
          .map((item) => {
            const hasReferenceImage = Number(item.has_reference_image || 0) > 0
              ? "是"
              : "否";
            return \`
              <tr>
                <td class="mono">\${escapeHtml(item.created_at || "-")}</td>
                <td>\${escapeHtml(item.category || "-")}</td>
                <td>\${escapeHtml(item.safety_code || "-")}</td>
                <td>\${escapeHtml(hasReferenceImage)}</td>
                <td>\${escapeHtml(item.prompt_excerpt || "-")}</td>
              </tr>
            \`;
          })
          .join("");
      }

      async function api(path, options = {}) {
        const token = tokenInput.value.trim() || localStorage.getItem(tokenKey) || "";
        if (!token) {
          throw new Error("请先填写并保存管理员 Token。");
        }

        const headers = {
          "x-admin-token": token,
        };

        if (options.body) {
          headers["Content-Type"] = "application/json";
        }

        const response = await fetch(path, {
          method: options.method || "GET",
          headers,
          body: options.body ? JSON.stringify(options.body) : undefined,
        });

        const text = await response.text();
        let payload = {};
        try {
          payload = text ? JSON.parse(text) : {};
        } catch {
          payload = { raw: text };
        }

        if (!response.ok) {
          throw new Error(payload.error || payload.message || text || ("HTTP " + response.status));
        }

        return payload;
      }

      function normalizeExpiry(value) {
        if (!value) {
          return null;
        }
        if (value.endsWith("Z")) {
          return value;
        }
        const date = new Date(value);
        if (!Number.isNaN(date.getTime())) {
          return date.toISOString();
        }
        return value;
      }

      function showStatus(message, tone) {
        statusBar.textContent = message;
        statusBar.className = "status-bar" + (tone ? " " + tone : "");
      }

      function escapeHtml(value) {
        return String(value)
          .replaceAll("&", "&amp;")
          .replaceAll("<", "&lt;")
          .replaceAll(">", "&gt;")
          .replaceAll('"', "&quot;")
          .replaceAll("'", "&#39;");
      }

      loadLicenses();
      loadOrders();
      loadSafetyEvents();
    </script>
  </body>
</html>`;
}
