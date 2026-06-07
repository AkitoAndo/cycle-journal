/**
 * Internal Test Group を作成し、Account Holder (28ww...) を internal tester に追加する。
 *
 * DRY_RUN=1 (default): 「グループを作成」モーダルを開いて screenshot を取って停止
 * DRY_RUN=0          : 名前入力 → 保存 → tester 追加 → build 自動配信設定
 */
import "dotenv/config";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const DRY_RUN = (process.env.DRY_RUN ?? "1") !== "0";
const GROUP_NAME = process.env.GROUP_NAME ?? "Internal Testers";
const SHOT_DIR = resolve(OPS_ROOT, ".inspect/internal-group");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  const url = `https://appstoreconnect.apple.com/apps/${APP_ID}/testflight/ios`;
  console.log(`→ open ${url} (DRY_RUN=${DRY_RUN ? "1" : "0"})`);
  await page.goto(url, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);
  await shot(page, "00-before");

  console.log("→ click グループを作成 link (or 内部テスト + button)");
  const createLink = page.getByText("グループを作成", { exact: true });
  if (await createLink.count()) {
    await createLink.first().click();
  } else {
    // sidebar の「内部テスト +」 button
    await page.locator("text=内部テスト").locator("xpath=..").locator("button").first().click();
  }
  await page.waitForTimeout(2500);
  await shot(page, "01-create-form");

  const buttons = await page.locator("button:visible").allTextContents();
  console.log("→ visible buttons:", buttons.map((b) => b.trim()).filter(Boolean).slice(0, 20));

  if (DRY_RUN) {
    console.log("→ DRY_RUN: stopping before save");
    await browser.close();
    return;
  }

  // 名前入力
  const dlg = page.getByRole("dialog");
  await dlg.locator("input").first().fill(GROUP_NAME);
  await page.waitForTimeout(500);
  await shot(page, "02-name-filled");

  // 「作成」or「保存」ボタン
  const submit = dlg.getByRole("button", { name: /^(作成|保存|Create|Save)$/ });
  await submit.click();
  await page.waitForTimeout(3000);
  await shot(page, "03-after-create");

  console.log("✓ group created");
  await browser.close();
}

async function shot(page: Page, name: string): Promise<void> {
  await page.screenshot({ path: resolve(SHOT_DIR, `${name}.png`), fullPage: true });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
