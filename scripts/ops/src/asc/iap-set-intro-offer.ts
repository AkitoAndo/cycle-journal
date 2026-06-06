/**
 * Monthly Premium に 3日 Introductory Offer (無料) を設定する。
 *
 * 環境変数:
 *   DRY_RUN=1     最後の保存を押さない（デフォルト）
 *   DRY_RUN=0     実際に登録
 *
 * 実行: DRY_RUN=1 npm run asc:set-intro-offer
 *      DRY_RUN=0 npm run asc:set-intro-offer
 */
import "dotenv/config";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = required("ASC_APP_ID");
const SUB_ID = process.env.ASC_PRODUCT_MONTHLY_SUB_ID || "6775457213";
const DRY_RUN = (process.env.DRY_RUN ?? "1") !== "0";
const URL = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/subscriptions/${SUB_ID}/pricing/intro-offers`;
const SHOT_DIR = resolve(OPS_ROOT, ".inspect/intro-flow");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  console.log(`→ open intro-offers page (DRY_RUN=${DRY_RUN ? "1" : "0"})`);
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);
  await shot(page, "00-before");

  console.log("→ click 「お試しオファーを設定」");
  await page.getByRole("button", { name: "お試しオファーを設定" }).click();
  await page.waitForTimeout(2000);
  await shot(page, "01-countries");

  console.log("→ countries: keep all selected, 次へ");
  await clickNext(page);
  await shot(page, "02-dates-empty");

  console.log("→ start date: today");
  await selectStartToday(page);
  await shot(page, "03-start-set");

  console.log("→ end date: 終了日なし");
  await selectEndNone(page);
  await shot(page, "04-end-set");

  await clickNext(page);
  await shot(page, "05-offer-type");

  console.log("→ offer type: 無料 (duration field appears on same screen)");
  await page.getByText("無料", { exact: true }).click();
  await page.waitForTimeout(800);
  await shot(page, "06-offer-type-set");

  console.log("→ duration: 3 日");
  await selectFreeDuration(page, "3日");
  await shot(page, "07-duration-set");
  await clickNext(page);
  await shot(page, "08-after-duration");

  // 確認画面のボタン候補をログ出力（DRY_RUN 時の調査用）
  const buttons = await page.locator("button:visible").allTextContents();
  console.log("→ buttons on confirm:", buttons.map((b) => b.trim()).filter(Boolean));

  if (DRY_RUN) {
    console.log("→ DRY_RUN: not saving. screenshots in .inspect/intro-flow/");
    await browser.close();
    return;
  }

  console.log("→ save");
  const saveBtn = page.getByRole("button", { name: /^(確認|保存|完了|確定)$/ });
  await saveBtn.click();
  await page.waitForTimeout(3000);
  await shot(page, "08-after-save");
  console.log("✓ saved");
  await browser.close();
}

async function clickNext(page: Page): Promise<void> {
  const next = page.getByRole("button", { name: /^次へ$/ });
  await next.waitFor({ state: "visible", timeout: 15_000 });
  for (let i = 0; i < 20; i++) {
    if (!(await next.isDisabled().catch(() => true))) break;
    await page.waitForTimeout(300);
  }
  await next.click();
  await page.waitForTimeout(2000);
}

async function selectStartToday(page: Page): Promise<void> {
  await page.locator(".react-datepicker__input-container input").nth(0).click();
  await page.waitForTimeout(800);
  // .react-datepicker__day--today にクリック可能なセルがあるはず
  const today = page.locator(".react-datepicker__day--today:not(.react-datepicker__day--disabled)");
  if (await today.count()) {
    await today.first().click();
  } else {
    // フォールバック: 最初の有効な日をクリック
    await page
      .locator(
        ".react-datepicker__day:not(.react-datepicker__day--disabled):not(.react-datepicker__day--outside-month)",
      )
      .first()
      .click();
  }
  await page.waitForTimeout(500);
}

async function selectEndNone(page: Page): Promise<void> {
  await page.locator(".react-datepicker__input-container input").nth(1).click();
  await page.waitForTimeout(800);
  await page.getByText("終了日なし", { exact: true }).click();
  await page.waitForTimeout(500);
}

async function selectFreeDuration(page: Page, label: string): Promise<void> {
  // 「無料期間」ラベル直下の dropdown。まず select を試す
  const select = page.locator("select").first();
  if (await select.count()) {
    try {
      await select.selectOption({ label });
      return;
    } catch {
      // fall through to custom dropdown
    }
  }
  // カスタムドロップダウン: 「選択する」ボタンをクリックして展開
  const trigger = page.getByText("選択する", { exact: true }).first();
  await trigger.click();
  await page.waitForTimeout(800);
  await page.getByText(label, { exact: true }).click();
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
