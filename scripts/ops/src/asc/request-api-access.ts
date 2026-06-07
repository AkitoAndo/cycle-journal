/**
 * App Store Connect API へのアクセス権をリクエストする。
 *
 * DRY_RUN=1 (default): 規約モーダルを開いて screenshot を撮るところで停止。
 * DRY_RUN=0          : 最終同意ボタンまで押す。
 *
 * 実行: DRY_RUN=1 npx tsx src/asc/request-api-access.ts
 */
import "dotenv/config";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const URL = "https://appstoreconnect.apple.com/access/integrations/api";
const DRY_RUN = (process.env.DRY_RUN ?? "1") !== "0";
const SHOT_DIR = resolve(OPS_ROOT, ".inspect/api-access-request");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  console.log(`→ open integrations page (DRY_RUN=${DRY_RUN ? "1" : "0"})`);
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);
  await shot(page, "00-before");

  console.log("→ click 「アクセス権をリクエスト」");
  await page.getByRole("button", { name: "アクセス権をリクエスト" }).click();
  await page.waitForTimeout(2000);
  await shot(page, "01-terms-dialog");

  const buttons = await page.locator("button:visible").allTextContents();
  console.log("→ visible buttons:", buttons.map((b) => b.trim()).filter(Boolean).slice(0, 30));

  // ダイアログ内のボタンも別途出す
  const dialog = page.getByRole("dialog");
  if (await dialog.count()) {
    const dlgBtns = await dialog.locator("button").allTextContents();
    console.log("→ dialog buttons:", dlgBtns.map((b) => b.trim()).filter(Boolean));
  }

  if (DRY_RUN) {
    console.log("→ DRY_RUN: stopping before agreement");
    await browser.close();
    return;
  }

  // 規約モーダル: チェックボックスを check → 「提出」ボタン押下
  console.log("→ check agreement checkbox");
  const dlg = page.getByRole("dialog");
  await dlg.getByRole("checkbox").check();
  await page.waitForTimeout(500);

  console.log("→ click 提出");
  await dlg.getByRole("button", { name: "提出" }).click();
  await page.waitForTimeout(3000);
  await shot(page, "02-after-submit");
  console.log("✓ access requested");
  await browser.close();
}

async function shot(page: Page, name: string): Promise<void> {
  await page.screenshot({ path: resolve(SHOT_DIR, `${name}.png`), fullPage: true });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
