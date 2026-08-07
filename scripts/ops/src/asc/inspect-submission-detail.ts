/**
 * 「審査待ち」になっている既存 submission の詳細ページを inspect。
 * subscription を追加できる UI、キャンセルボタンの位置を特定する。
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = "6760911210";

async function main() {
  const outDir = resolve(OPS_ROOT, ".inspect/submission-detail");
  mkdirSync(outDir, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  const reviewUrl = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/reviewsubmissions`;
  await page.goto(reviewUrl, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);

  // 「今日 20:21」のリンクをクリック（提出日の column がリンクになっている）
  console.log("→ click 今日 link");
  await page.locator("a", { hasText: "今日" }).first().click();
  await page.waitForTimeout(3500);
  console.log(`URL after click: ${page.url()}`);

  await page.screenshot({ path: resolve(outDir, "detail.png"), fullPage: true });
  writeFileSync(resolve(outDir, "detail.html"), await page.content());

  const text = await page.evaluate(() => document.body.innerText);
  writeFileSync(resolve(outDir, "detail.txt"), text);
  console.log("--- submission detail (first 3000 chars) ---");
  console.log(text.slice(0, 3000));

  const buttons = await page.locator("button:visible").allTextContents();
  console.log("\nbuttons:", buttons.map((b) => b.trim()).filter(Boolean).slice(0, 30));

  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
