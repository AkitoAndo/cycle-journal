/**
 * 1.0.3 version page で「審査へ提出」 → 確認モーダル → 提出。
 */
import "dotenv/config";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const SHOT_DIR = resolve(OPS_ROOT, ".inspect/click-submit");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  await page.goto(
    "https://appstoreconnect.apple.com/apps/6760911210/distribution/ios/version/inflight",
    { waitUntil: "domcontentloaded" },
  );
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);
  await shot(page, "00-page");

  console.log("→ click 「審査へ提出」");
  await page.getByRole("button", { name: "審査へ提出" }).click();
  await page.waitForTimeout(3000);
  await shot(page, "01-after-click");
  console.log(`URL: ${page.url()}`);

  const dlg = page.getByRole("dialog");
  if (await dlg.count()) {
    const dlgBtns = await dlg.locator("button").allTextContents();
    console.log("dialog buttons:", dlgBtns.map((b) => b.trim()).filter(Boolean));
    const confirm = dlg.getByRole("button", {
      name: /^(審査(へ|に)提出|提出|送信|確認|はい|OK|Submit|Apple に提出)$/,
    });
    if (await confirm.count()) {
      await confirm.last().click();
      await page.waitForTimeout(4000);
      await shot(page, "02-after-confirm");
      console.log("✓ submitted (confirm dialog clicked)");
    }
  } else {
    console.log("? no dialog, maybe submit done already");
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
