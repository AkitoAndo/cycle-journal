/**
 * ASC Apps 一覧から App ID を取得して表示する。
 * Cycle が1個だけならそれを .env の ASC_APP_ID に書き込む。
 *
 * 実行: npx tsx src/asc/list-apps.ts
 */
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APPS_URL = "https://appstoreconnect.apple.com/apps";

interface AppInfo {
  id: string;
  name: string;
}

async function main() {
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto(APPS_URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});

  const apps: AppInfo[] = await page.$$eval('a[href*="/apps/"]', (anchors) => {
    const seen = new Map<string, string>();
    for (const a of anchors as HTMLAnchorElement[]) {
      const m = a.href.match(/\/apps\/(\d+)(\/|$)/);
      if (!m) continue;
      const id = m[1];
      const name = a.textContent?.trim() || "";
      if (name && !seen.has(id)) seen.set(id, name);
    }
    return Array.from(seen, ([id, name]) => ({ id, name }));
  });

  await browser.close();

  if (apps.length === 0) {
    console.error("✗ no apps found — session may be expired. run `npm run asc:login`");
    process.exit(1);
  }

  console.log("Apps:");
  for (const a of apps) {
    console.log(`  ${a.id}  ${a.name}`);
  }

  const cycle = apps.find((a) => /cycle/i.test(a.name));
  if (cycle) {
    await upsertEnv("ASC_APP_ID", cycle.id);
    console.log(`✓ wrote ASC_APP_ID=${cycle.id} (${cycle.name}) to .env`);
  } else if (apps.length === 1) {
    await upsertEnv("ASC_APP_ID", apps[0].id);
    console.log(`✓ wrote ASC_APP_ID=${apps[0].id} (${apps[0].name}) to .env`);
  } else {
    console.log("→ multiple apps found and none match 'cycle'. set ASC_APP_ID manually.");
  }
}

async function upsertEnv(key: string, value: string): Promise<void> {
  const envPath = resolve(OPS_ROOT, ".env");
  let content = existsSync(envPath) ? readFileSync(envPath, "utf-8") : "";
  const line = `${key}=${value}`;
  const re = new RegExp(`^${key}=.*$`, "m");
  content = re.test(content) ? content.replace(re, line) : `${content.replace(/\n?$/, "\n")}${line}\n`;
  writeFileSync(envPath, content);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
