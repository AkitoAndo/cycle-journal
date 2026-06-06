/**
 * 個別サブスクリプション商品ページの screenshot + DOM ダンプ。
 * 実行: npx tsx src/asc/inspect-subscription.ts <subscriptionId> <label>
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = required("ASC_APP_ID");
const SUB_ID = process.argv[2];
const LABEL = process.argv[3] || SUB_ID;

if (!SUB_ID) {
  console.error("usage: inspect-subscription.ts <subscriptionId> [label]");
  process.exit(1);
}

const URL = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/subscriptions/${SUB_ID}`;

async function main() {
  const inspectDir = resolve(OPS_ROOT, ".inspect");
  mkdirSync(inspectDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  await page.screenshot({ path: resolve(inspectDir, `sub-${LABEL}.png`), fullPage: true });
  writeFileSync(resolve(inspectDir, `sub-${LABEL}.html`), await page.content());

  const summary = await page.evaluate(() => {
    const rows: { text: string; href?: string; tag: string }[] = [];
    document
      .querySelectorAll("a, button, [role='button'], h1, h2, h3, h4, label, input, select")
      .forEach((el) => {
        const text = (el.textContent || (el as HTMLInputElement).value || "")
          .replace(/\s+/g, " ")
          .trim()
          .slice(0, 200);
        if (!text) return;
        rows.push({
          text,
          href: (el as HTMLAnchorElement).href || undefined,
          tag: el.tagName.toLowerCase(),
        });
      });
    return rows;
  });
  writeFileSync(resolve(inspectDir, `sub-${LABEL}-summary.json`), JSON.stringify(summary, null, 2));
  console.log(`✓ inspected ${LABEL} (${summary.length} entries)`);

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
