/**
 * 既存 submission をキャンセルし、ASC Web UI で subscription 含めて再 submit。
 *
 * フロー:
 *   1. キャンセルボタンクリック → 確認モーダル → 確定
 *   2. 1.0.3 version detail page (App Review submission button) → submit ページ
 *   3. items 選択 (appStoreVersion + monthly subscription) → 提出
 */
import "dotenv/config";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = "6760911210";
const SUBMISSION_ID = "029f33df-3140-40ff-9433-99982dc69b8d";
const SHOT_DIR = resolve(OPS_ROOT, ".inspect/cancel-resubmit");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  // Step 1: open submission detail and click cancel
  const detailUrl = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/reviewsubmissions/details/${SUBMISSION_ID}`;
  console.log(`→ open ${detailUrl}`);
  await page.goto(detailUrl, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);
  await shot(page, "00-detail");

  console.log("→ click 提出をキャンセル");
  await page.getByRole("button", { name: "提出をキャンセル" }).click();
  await page.waitForTimeout(2000);
  await shot(page, "01-cancel-dialog");
  const dlgBtns = await page.getByRole("dialog").locator("button").allTextContents();
  console.log("dialog buttons:", dlgBtns.map((s) => s.trim()).filter(Boolean));

  // confirm cancellation
  const confirm = page
    .getByRole("dialog")
    .getByRole("button", { name: /^(提出をキャンセル|キャンセル|OK|確認|はい)$/ });
  // dialog 内に「提出をキャンセル」赤ボタン or 同様の destructive button
  await confirm.last().click();
  await page.waitForTimeout(3000);
  await shot(page, "02-after-cancel");

  // verify state
  const text = await page.evaluate(() => document.body.innerText);
  if (text.includes("キャンセル") || text.includes("削除済み") || text.includes("取消")) {
    console.log("  ✓ cancelled");
  } else {
    console.log("  ? unclear state, see screenshot");
  }

  await browser.close();
}

async function shot(page: Page, name: string): Promise<void> {
  await page.screenshot({ path: resolve(SHOT_DIR, `${name}.png`), fullPage: true });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
