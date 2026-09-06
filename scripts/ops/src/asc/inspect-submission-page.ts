/**
 * App Review submission ページ（version 1.0.3 のもの）を inspect。
 * subscription を追加できる UI を探す。
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = "6760911210";

async function main() {
  const outDir = resolve(OPS_ROOT, ".inspect/submission-page");
  mkdirSync(outDir, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  // 1) App Review Submissions page (Treow)
  const reviewUrl = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/reviewsubmissions`;
  console.log(`→ ${reviewUrl}`);
  await page.goto(reviewUrl, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);
  await page.screenshot({ path: resolve(outDir, "review-list.png"), fullPage: true });
  writeFileSync(resolve(outDir, "review-list.html"), await page.content());

  const text1 = await page.evaluate(() => document.body.innerText);
  writeFileSync(resolve(outDir, "review-list.txt"), text1);
  console.log("--- review submissions list (first 2000 chars) ---");
  console.log(text1.slice(0, 2000));

  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
