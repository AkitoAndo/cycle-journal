/**
 * 1.0.3 version page で「審査用に追加」 → 新規 submission ページ → 「Apple に提出」。
 * Monthly Premium は既に items として bundled されている前提。
 */
import "dotenv/config";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = "6760911210";
const SHOT_DIR = resolve(OPS_ROOT, ".inspect/add-to-review");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  await page.goto(
    `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/ios/version/inflight`,
    { waitUntil: "domcontentloaded" },
  );
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);
  await shot(page, "00-version");

  // 既に「審査用に追加」済みの場合は skip
  const addBtn = page.getByRole("button", { name: "審査用に追加" });
  if (await addBtn.count()) {
    console.log("→ click 審査用に追加");
    await addBtn.click();
    await page.waitForTimeout(4000);
  } else {
    console.log("→ 審査用に追加 already done, skipping");
  }
  await shot(page, "01-after-add");

  // 「提出物の下書き（N）」をクリックして下書き submission ページへ
  const draftBtn = page.getByRole("button", { name: /提出物の下書き/ });
  if (await draftBtn.count()) {
    console.log("→ click 提出物の下書き");
    await draftBtn.click();
    await page.waitForTimeout(3500);
    await shot(page, "01b-draft-page");
    console.log(`URL: ${page.url()}`);
  }

  // 新規 submission ページに遷移しているはず
  // 「Apple に提出」「審査に提出」「提出」 等のボタンを探す
  const buttons = await page.locator("button:visible").allTextContents();
  console.log("buttons:", buttons.map((b) => b.trim()).filter(Boolean).slice(0, 30));

  // 提出ボタン候補
  const submit = page.getByRole("button", {
    name: /^(Apple に提出|審査(へ|に)提出|提出|送信|Submit|審査へ提出)$/,
  });
  if (await submit.count()) {
    console.log("→ click submit");
    await submit.first().click();
    // ローダーがあるため十分待つ
    await page.waitForTimeout(8000);
    await shot(page, "02-submit-confirm");

    // 確認モーダル：ロード完了を待つ
    const dlg = page.getByRole("dialog");
    if (await dlg.count()) {
      // ボタンが描画されるまで polling
      for (let i = 0; i < 12; i++) {
        const btnTexts = await dlg.locator("button").allTextContents();
        const cleaned = btnTexts.map((b) => b.trim()).filter(Boolean);
        if (cleaned.length > 0) {
          console.log("dialog buttons:", cleaned);
          break;
        }
        await page.waitForTimeout(2000);
      }

      const confirm = dlg.getByRole("button", {
        name: /^(提出|送信|Apple に提出|確認|はい|OK|Submit|審査(へ|に)提出)$/,
      });
      if (await confirm.count()) {
        await confirm.last().click();
        await page.waitForTimeout(5000);
        await shot(page, "03-after-confirm");
        console.log("✓ submitted");
      } else {
        await shot(page, "03-no-confirm-btn");
        console.log("! confirm button not found");
      }
    }
  } else {
    console.log("! submit button not found, page may need extra step");
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
