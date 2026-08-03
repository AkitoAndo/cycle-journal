/**
 * 1.0.3 version page で「アプリ内購入またはサブスクリプションを選択」 →
 * Monthly Premium を選び、「審査用に追加」 で submission に bundle して submit。
 */
import "dotenv/config";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = "6760911210";
const MONTHLY_PRODUCT_ID = "com.akitoando.CycleJournal.monthly_1800";
const SHOT_DIR = resolve(OPS_ROOT, ".inspect/select-iap");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  await page.goto(
    `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/reviewsubmissions`,
    { waitUntil: "domcontentloaded" },
  );
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);
  console.log("→ click sidebar 1.0.3");
  await page.locator("text=1.0.3").first().click();
  await page.waitForTimeout(3000);
  await shot(page, "00-version-page");

  console.log("→ click 「アプリ内購入またはサブスクリプションを選択」");
  await page
    .getByRole("button", { name: "アプリ内購入またはサブスクリプションを選択" })
    .click();
  await page.waitForTimeout(2500);
  await shot(page, "01-iap-picker");

  const dlg = page.getByRole("dialog");
  console.log("→ click Monthly Premium row label");
  // ASC のリストは <label>+<input> 構造。label テキストをクリックで toggle。
  const target = dlg.getByText(MONTHLY_PRODUCT_ID).first();
  if (await target.count()) {
    await target.click();
    console.log("  ✓ clicked monthly row by product id");
  } else {
    await dlg.getByText("Monthly Premium", { exact: false }).first().click();
    console.log("  ✓ clicked monthly row by name");
  }
  await page.waitForTimeout(500);
  await shot(page, "02-checked");

  const btns = await dlg.locator("button").allTextContents();
  console.log("dialog buttons:", btns.map((b) => b.trim()).filter(Boolean));

  // 「選択」「追加」「保存」「Add」 系のボタンで confirm
  const confirm = dlg.getByRole("button", {
    name: /^(選択|追加|保存|完了|Add|Save|Done|OK)$/,
  });
  await confirm.last().click();
  await page.waitForTimeout(2500);
  await shot(page, "03-after-add");

  console.log("→ click 「審査用に追加」");
  await page.getByRole("button", { name: "審査用に追加" }).click();
  await page.waitForTimeout(3000);
  await shot(page, "04-after-add-for-review");

  const visible = await page.locator("button:visible").allTextContents();
  console.log("visible:", visible.map((b) => b.trim()).filter(Boolean).slice(0, 20));

  await browser.close();
}

async function shot(page: Page, name: string): Promise<void> {
  await page.screenshot({ path: resolve(SHOT_DIR, `${name}.png`), fullPage: true });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
