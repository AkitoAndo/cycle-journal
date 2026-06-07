/**
 * Internal Test Group「Internal Testers」に Account Holder 自身を tester に追加する。
 *
 * DRY_RUN=1: 追加モーダルを開いて screenshot 取って停止
 * DRY_RUN=0: 実際に追加
 */
import "dotenv/config";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const GROUP_NAME = process.env.GROUP_NAME ?? "Internal Testers";
const TESTER_EMAIL = process.env.TESTER_EMAIL ?? "28ww.lo.ol.ww28@gmail.com";
const DRY_RUN = (process.env.DRY_RUN ?? "1") !== "0";
const SHOT_DIR = resolve(OPS_ROOT, ".inspect/add-tester");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  await page.goto(`https://appstoreconnect.apple.com/apps/${APP_ID}/testflight/ios`, {
    waitUntil: "domcontentloaded",
  });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);

  console.log(`→ click sidebar group: ${GROUP_NAME}`);
  await page.getByText(GROUP_NAME, { exact: true }).first().click();
  await page.waitForTimeout(2000);
  await shot(page, "00-group-open");

  console.log("→ click テスター + button");
  // 「テスター (0) ⊕」見出しの隣の + button
  const addBtn = page
    .locator("h3, h2", { hasText: /テスター \(\d+\)/ })
    .locator("xpath=following-sibling::button")
    .first();
  await addBtn.click();
  await page.waitForTimeout(2500);
  await shot(page, "01-add-form");

  const buttons = await page.locator("button:visible").allTextContents();
  console.log("→ visible buttons:", buttons.map((b) => b.trim()).filter(Boolean).slice(0, 20));

  if (DRY_RUN) {
    console.log("→ DRY_RUN: stop");
    await browser.close();
    return;
  }

  // ASC user 一覧（自分の Apple ID メアド）にチェックを入れて追加する想定
  const dlg = page.getByRole("dialog");
  // メアド文字列で row を特定して checkbox を check
  const row = dlg.locator("tr, [role='row']", { hasText: TESTER_EMAIL }).first();
  if (await row.count()) {
    await row.locator("input[type='checkbox']").first().check();
    console.log(`  checked: ${TESTER_EMAIL}`);
  } else {
    // checkbox + label テキストで取る fallback
    await dlg
      .locator("input[type='checkbox']")
      .first()
      .check();
    console.log("  checked first checkbox (fallback)");
  }
  await page.waitForTimeout(500);
  await shot(page, "02-checked");

  const submit = dlg.getByRole("button", { name: /^(追加|Add|保存|Save)$/ });
  await submit.click();
  await page.waitForTimeout(3000);
  await shot(page, "03-after-add");
  console.log("✓ tester added");
  await browser.close();
}

async function shot(page: Page, name: string): Promise<void> {
  await page.screenshot({ path: resolve(SHOT_DIR, `${name}.png`), fullPage: true });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
