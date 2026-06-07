/**
 * Export Compliance を「2. 標準的な暗号化アルゴリズム」で申告し、続く exemption 質問の DOM を確認。
 * 最終「保存」ボタンは押さず、フォームの全質問が見える状態で停止する。
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

async function main() {
  const outDir = resolve(OPS_ROOT, ".inspect/compliance-step2");
  mkdirSync(outDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto("https://appstoreconnect.apple.com/apps/6760911210/testflight/ios", {
    waitUntil: "domcontentloaded",
  });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);

  console.log("→ click 管理");
  await page.getByText("管理", { exact: true }).first().click();
  await page.waitForTimeout(2000);

  console.log("→ select 標準的な暗号化アルゴリズム");
  await page
    .getByText(/標準的な暗号化アルゴリズム.*Apple/, { exact: false })
    .first()
    .click();
  await page.waitForTimeout(2000);

  await page.screenshot({ path: resolve(outDir, "01-after-select.png"), fullPage: true });
  writeFileSync(resolve(outDir, "01.html"), await page.content());

  const text = await page.evaluate(() => document.body.innerText);
  writeFileSync(resolve(outDir, "01-text.txt"), text);
  console.log("→ full text:");
  console.log(text.slice(0, 4000));

  // 保存は押さずに終了
  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
