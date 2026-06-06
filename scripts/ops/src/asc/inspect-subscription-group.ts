/**
 * サブスクリプショングループ詳細ページの screenshot + DOM ダンプ。
 * グループ ID と商品行のセレクタを特定する。
 *
 * 実行: npx tsx src/asc/inspect-subscription-group.ts <groupId>
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = required("ASC_APP_ID");
const GROUP_ID = process.argv[2] || "22126843";
const GROUP_URL = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/subscription-groups/${GROUP_ID}`;

async function main() {
  const inspectDir = resolve(OPS_ROOT, ".inspect");
  mkdirSync(inspectDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto(GROUP_URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  await page.screenshot({ path: resolve(inspectDir, "group.png"), fullPage: true });
  writeFileSync(resolve(inspectDir, "group.html"), await page.content());

  const summary = await page.evaluate(() => {
    const rows: { text: string; href?: string; testId?: string; tag: string }[] = [];
    document
      .querySelectorAll("a, button, tr, [role='row'], [data-testid], h1, h2, h3, label")
      .forEach((el) => {
        const text = (el.textContent || "").replace(/\s+/g, " ").trim().slice(0, 160);
        if (!text) return;
        rows.push({
          text,
          href: (el as HTMLAnchorElement).href || undefined,
          testId: (el as HTMLElement).dataset?.testid,
          tag: el.tagName.toLowerCase(),
        });
      });
    return rows;
  });
  writeFileSync(resolve(inspectDir, "group-summary.json"), JSON.stringify(summary, null, 2));
  console.log(`✓ inspected group ${GROUP_ID} (${summary.length} entries)`);

  await browser.close();
}

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`missing env: ${name}`);
  return v;
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
