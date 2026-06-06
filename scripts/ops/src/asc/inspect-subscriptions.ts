/**
 * Subscriptions ページの screenshot + 主要 DOM ダンプを取得し、
 * iap-set-intro-offer / iap-remove-from-sale のセレクタ調整に使う。
 *
 * 実行: npx tsx src/asc/inspect-subscriptions.ts
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = required("ASC_APP_ID");
const SUBSCRIPTIONS_URL = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/subscriptions`;

async function main() {
  const inspectDir = resolve(OPS_ROOT, ".inspect");
  mkdirSync(inspectDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto(SUBSCRIPTIONS_URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  const screenshotPath = resolve(inspectDir, "subscriptions.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`✓ screenshot: ${screenshotPath}`);

  const html = await page.content();
  const htmlPath = resolve(inspectDir, "subscriptions.html");
  writeFileSync(htmlPath, html);
  console.log(`✓ html: ${htmlPath}`);

  // テキストノードと href を抽出して、商品行を見つけやすくする
  const summary = await page.evaluate(() => {
    const rows: { text: string; href?: string; testId?: string }[] = [];
    document.querySelectorAll("a, button, tr, [role='row'], [data-testid]").forEach((el) => {
      const text = (el.textContent || "").replace(/\s+/g, " ").trim().slice(0, 120);
      if (!text) return;
      rows.push({
        text,
        href: (el as HTMLAnchorElement).href || undefined,
        testId: (el as HTMLElement).dataset?.testid,
      });
    });
    return rows;
  });
  const summaryPath = resolve(inspectDir, "subscriptions-summary.json");
  writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
  console.log(`✓ summary: ${summaryPath} (${summary.length} entries)`);

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
