/**
 * App Store Connect の「アプリのプライバシー」ページに Privacy Policy URL を登録する。
 *
 * Apple 公式手順 (https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/):
 *   1. App を選択 → サイドバーの「App privacy」(アプリのプライバシー)
 *   2. 「Privacy Policy」(プライバシーポリシー) の横の「Edit」(編集)
 *   3. URL を入力 → Save (保存)
 *
 * 環境変数:
 *   PRIVACY_URL    登録する URL
 *   DRY_RUN=1      編集モーダルを開いて screenshot を取り、保存せず終了 (デフォルト)
 *   DRY_RUN=0      実際に保存
 *
 * 実行:
 *   DRY_RUN=1 PRIVACY_URL=https://akitoando.github.io/cycle-journal/legal/PRIVACY_POLICY.html \
 *     npx tsx src/asc/set-privacy-url.ts
 */
import "dotenv/config";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = required("ASC_APP_ID");
const PRIVACY_URL = required("PRIVACY_URL");
const DRY_RUN = (process.env.DRY_RUN ?? "1") !== "0";
const URL = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/privacy`;
const SHOT_DIR = resolve(OPS_ROOT, ".inspect/privacy-url");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  console.log(`→ open app privacy page (DRY_RUN=${DRY_RUN ? "1" : "0"})`);
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);
  await shot(page, "00-before");

  // 「プライバシーポリシー」セクションの「編集」ボタンを探す。
  // ASC の「アプリのプライバシー」ページには複数の「編集」ボタンがあるため、
  // 「プライバシーポリシー」見出し近くの編集ボタンに限定する。
  console.log("→ locate 'プライバシーポリシー' section");
  const privacySection = page
    .locator("section, div")
    .filter({ has: page.getByRole("heading", { name: /プライバシーポリシー|Privacy Policy/i }) })
    .first();

  console.log("→ click 編集 inside privacy section");
  await privacySection.getByRole("button", { name: /^(編集|Edit)$/ }).first().click();
  await page.waitForTimeout(2000);
  await shot(page, "01-edit-dialog");

  console.log("→ inspect editable controls");
  const inputsCount = await page.locator("input[type='text'], input[type='url']").count();
  const textareaCount = await page.locator("textarea").count();
  console.log(`  inputs=${inputsCount}, textarea=${textareaCount}`);

  if (DRY_RUN) {
    console.log("→ DRY_RUN: stopping before any input/save");
    await browser.close();
    return;
  }

  // 本実行: URL 入力欄を埋める。Privacy Policy URL は通常 1 つの入力欄なのでそれを使う。
  const urlInput = page.locator("input[type='text'], input[type='url']").first();
  await urlInput.fill(PRIVACY_URL);
  await shot(page, "02-filled");

  console.log("→ save");
  const dialog = page.getByRole("dialog");
  const saveBtn = dialog.getByRole("button", { name: /^(保存|Save|確認|完了)$/ }).last();
  await saveBtn.click();
  await page.waitForTimeout(3000);
  await shot(page, "03-after-save");
  console.log("✓ saved");
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
