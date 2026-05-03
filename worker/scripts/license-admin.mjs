import crypto from "node:crypto";
import { spawnSync } from "node:child_process";

const DATABASE_NAME = "xii-license-db";
const DEFAULT_TIER = "premium";
const DEFAULT_MAX_DEVICES = 1;
const DEFAULT_EXPIRY = "2027-12-31T23:59:59.000Z";

const [, , command, ...restArgs] = process.argv;

if (!command || command === "help" || command === "--help" || command === "-h") {
  printHelp();
  process.exit(0);
}

const options = parseOptions(restArgs);

switch (command) {
  case "create":
    handleCreate(options);
    break;
  case "list":
    handleList(options);
    break;
  case "update":
    handleUpdate(options);
    break;
  case "extend":
    handleExtend(options);
    break;
  case "disable":
    handleDisable(options);
    break;
  case "enable":
    handleEnable(options);
    break;
  case "unbind":
    handleUnbind(options);
    break;
  case "delete":
    handleDelete(options);
    break;
  case "bindings":
    handleBindings(options);
    break;
  default:
    console.error(`Unknown command: ${command}`);
    printHelp();
    process.exit(1);
}

function handleCreate(options) {
  const code = options.code || generateLicenseCode();
  const codeHash = hashCode(code);
  const tier = options.tier || DEFAULT_TIER;
  const expiresAt = options.expires || DEFAULT_EXPIRY;
  const maxDevices = Number.parseInt(options.maxDevices || `${DEFAULT_MAX_DEVICES}`, 10);
  const note = options.note || "";

  executeRemoteSql(`
    INSERT INTO license_codes (
      code_hash,
      status,
      tier,
      expires_at,
      max_devices,
      note,
      created_at,
      updated_at
    ) VALUES (
      '${escapeSql(codeHash)}',
      'active',
      '${escapeSql(tier)}',
      '${escapeSql(expiresAt)}',
      ${Number.isFinite(maxDevices) ? maxDevices : DEFAULT_MAX_DEVICES},
      '${escapeSql(note)}',
      datetime('now'),
      datetime('now')
    );
  `);

  console.log("");
  console.log("License created successfully.");
  console.log(`Code      : ${code}`);
  console.log(`Hash      : ${codeHash}`);
  console.log(`Tier      : ${tier}`);
  console.log(`Expires   : ${expiresAt}`);
  console.log(`Devices   : ${maxDevices}`);
  console.log(`Note      : ${note || "-"}`);
}

function handleList(options) {
  const noteFilter = options.note
    ? `WHERE note LIKE '%${escapeSql(options.note)}%'`
    : "";

  executeRemoteSql(`
    SELECT
      id,
      status,
      tier,
      expires_at,
      max_devices,
      note,
      created_at,
      updated_at
    FROM license_codes
    ${noteFilter}
    ORDER BY id DESC;
  `);
}

function handleUpdate(options) {
  const whereClause = resolveIdentifierWhereClause(options);
  const assignments = [];

  if (options.tier) {
    assignments.push(`tier = '${escapeSql(options.tier)}'`);
  }
  if (options.expires) {
    assignments.push(`expires_at = '${escapeSql(options.expires)}'`);
  }
  if (options.maxDevices) {
    const maxDevices = Number.parseInt(options.maxDevices, 10);
    if (!Number.isFinite(maxDevices)) {
      console.error("Invalid --maxDevices value.");
      process.exit(1);
    }
    assignments.push(`max_devices = ${maxDevices}`);
  }
  if (options.note) {
    assignments.push(`note = '${escapeSql(options.note)}'`);
  }
  if (options.status) {
    assignments.push(`status = '${escapeSql(options.status)}'`);
  }

  if (assignments.length === 0) {
    console.error(
      "Nothing to update. Use one of: --tier, --expires, --maxDevices, --note, --status",
    );
    process.exit(1);
  }

  assignments.push("updated_at = datetime('now')");

  executeRemoteSql(`
    UPDATE license_codes
    SET ${assignments.join(", ")}
    ${whereClause};
  `);
}

function handleExtend(options) {
  const whereClause = resolveIdentifierWhereClause(options);
  const expires = options.expires;

  if (!expires) {
    console.error("Missing --expires. Example: --expires 2028-12-31T23:59:59.000Z");
    process.exit(1);
  }

  executeRemoteSql(`
    UPDATE license_codes
    SET expires_at = '${escapeSql(expires)}',
        updated_at = datetime('now')
    ${whereClause};
  `);
}

function handleDisable(options) {
  const whereClause = resolveIdentifierWhereClause(options);
  executeRemoteSql(`
    UPDATE license_codes
    SET status = 'disabled',
        updated_at = datetime('now')
    ${whereClause};
  `);
}

function handleEnable(options) {
  const whereClause = resolveIdentifierWhereClause(options);
  executeRemoteSql(`
    UPDATE license_codes
    SET status = 'active',
        updated_at = datetime('now')
    ${whereClause};
  `);
}

function handleUnbind(options) {
  const whereClause = resolveIdentifierWhereClause(options, {
    tableAlias: "lc",
    bindingColumn: "license_code_id",
  });

  executeRemoteSql(`
    DELETE FROM license_bindings
    WHERE license_code_id IN (
      SELECT lc.id
      FROM license_codes lc
      ${whereClause.replace("WHERE", "WHERE")}
    );
  `);
}

function handleDelete(options) {
  const whereClause = resolveIdentifierWhereClause(options);

  executeRemoteSql(`
    DELETE FROM license_bindings
    WHERE license_code_id IN (
      SELECT id
      FROM license_codes
      ${whereClause}
    );
  `);

  executeRemoteSql(`
    DELETE FROM license_events
    WHERE license_code_id IN (
      SELECT id
      FROM license_codes
      ${whereClause}
    );
  `);

  executeRemoteSql(`
    DELETE FROM license_codes
    ${whereClause};
  `);
}

function handleBindings(options) {
  const whereClause = resolveIdentifierWhereClause(options, {
    tableAlias: "lc",
  });

  executeRemoteSql(`
    SELECT
      lb.id,
      lb.license_code_id,
      lb.install_id_hash,
      lb.device_name,
      lb.bound_at,
      lb.last_seen_at,
      lb.revoked_at,
      lc.status,
      lc.tier,
      lc.note
    FROM license_bindings lb
    INNER JOIN license_codes lc ON lc.id = lb.license_code_id
    ${whereClause}
    ORDER BY lb.id DESC;
  `);
}

function resolveIdentifierWhereClause(options, extra = {}) {
  const tableAlias = extra.tableAlias ? `${extra.tableAlias}.` : "";

  if (options.id) {
    return `WHERE ${tableAlias}id = ${Number.parseInt(options.id, 10)}`;
  }

  if (options.note) {
    return `WHERE ${tableAlias}note = '${escapeSql(options.note)}'`;
  }

  if (options.hash) {
    return `WHERE ${tableAlias}code_hash = '${escapeSql(options.hash)}'`;
  }

  if (options.code) {
    return `WHERE ${tableAlias}code_hash = '${hashCode(options.code)}'`;
  }

  console.error("Missing identifier. Use one of: --id, --note, --hash, --code");
  process.exit(1);
}

function executeRemoteSql(sql) {
  const command = [
    "wrangler",
    "d1",
    "execute",
    DATABASE_NAME,
    "--remote",
    "--command",
    compactSql(sql),
  ];

  const result = spawnSync("npx", command, {
    stdio: "inherit",
    shell: process.platform === "win32",
  });

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
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

function randomSegment(length) {
  return crypto
    .randomBytes(length)
    .toString("base64url")
    .replace(/[^A-Z0-9]/gi, "")
    .toUpperCase()
    .slice(0, length)
    .padEnd(length, "X");
}

function hashCode(code) {
  return crypto.createHash("sha256").update(code, "utf8").digest("hex");
}

function parseOptions(args) {
  const parsed = {};

  for (let index = 0; index < args.length; index += 1) {
    const part = args[index];
    if (!part.startsWith("--")) {
      continue;
    }

    const key = part.slice(2);
    const next = args[index + 1];
    if (!next || next.startsWith("--")) {
      parsed[key] = "true";
      continue;
    }

    parsed[key] = next;
    index += 1;
  }

  return parsed;
}

function compactSql(sql) {
  return sql.replace(/\s+/g, " ").trim();
}

function escapeSql(value) {
  return `${value}`.replace(/'/g, "''");
}

function printHelp() {
  console.log(`
Usage:
  npm run license -- <command> [options]

Commands:
  create     Create a new license code and insert it into remote D1
  list       List license records
  update     Update a license (tier / expiry / devices / note / status)
  extend     Extend or replace the expiry time of a license
  disable    Disable a license
  enable     Re-enable a license
  bindings   Show bindings for a license
  unbind     Remove bindings for a license
  delete     Delete a license and related bindings/events

Examples:
  npm run license -- create --note "首批用户" --expires "2027-12-31T23:59:59.000Z" --maxDevices 1
  npm run license -- create --code "XII-2026-ABCD-EFGH" --note "手动指定码"
  npm run license -- list
  npm run license -- update --id 3 --maxDevices 2 --tier "premium-plus"
  npm run license -- extend --code "XII-2026-ABCD-EFGH" --expires "2028-12-31T23:59:59.000Z"
  npm run license -- bindings --note "首批用户"
  npm run license -- unbind --code "XII-2026-ABCD-EFGH"
  npm run license -- disable --id 3
  npm run license -- enable --note "首批用户"
  npm run license -- delete --hash "<sha256>"
`);
}
