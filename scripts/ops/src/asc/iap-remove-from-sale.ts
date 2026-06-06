/**
 * Yearly Premium を「配信から削除」する（フェーズ1の間の販売停止）。
 *
 * 環境変数:
 *   DRY_RUN=1     確認ダイアログまでで止める（デフォルト）
 *   DRY_RUN=0     実際に削除
 */
import "dotenv/config";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = required("ASC_APP_ID");
const SUB_ID = process.env.ASC_PRODUCT_YEARLY_SUB_ID || "6775448821";
const DRY_RUN = (process.env.DRY_RUN ?? "1") !== "0";
const URL = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/subscriptions/${SUB_ID}`;
const SHOT_DIR = resolve(OPS_ROOT, ".inspect/remove-from-sale");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  console.log(`→ open yearly subscription page (DRY_RUN=${DRY_RUN ? "1" : "0"})`);
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);
  await shot(page, "00-before");

  console.log("→ click 「配信から削除」");
  await page.getByRole("button", { name: "配信から削除" }).click();
  await page.waitForTimeout(2000);
  await shot(page, "01-confirm-dialog");

  const dialog = page.getByRole("dialog");
  const dialogButtons = await dialog.locator("button").allTextContents();
  console.log("→ buttons in dialog:", dialogButtons.map((b) => b.trim()).filter(Boolean));

  if (DRY_RUN) {
    console.log("→ DRY_RUN: not confirming. screenshot in .inspect/remove-from-sale/");
    await browser.close();
    return;
  }

  const confirm = dialog.getByRole("button", { name: /^(削除|確認|OK|配信から削除|はい)$/ });
  await confirm.click();
  await page.waitForTimeout(3000);
  await shot(page, "02-after-confirm");
  console.log("✓ removed from sale");
  await browser.close();
}

async function shot(page: Page, name: string): Promise<void> {
  await page.screenshot({ path: resolve(SHOT_DIR, `${name}.png`), fullPage: true });
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
