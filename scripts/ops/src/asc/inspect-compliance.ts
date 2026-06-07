/**
 * 「コンプライアンスがありません 管理」リンクを click した後の DOM 構造を inspect。
 * Export Compliance form の選択肢を確認。送信はしない。
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

async function main() {
  const outDir = resolve(OPS_ROOT, ".inspect/compliance");
  mkdirSync(outDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto("https://appstoreconnect.apple.com/apps/6760911210/testflight/ios", {
    waitUntil: "domcontentloaded",
  });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);

  await page.screenshot({ path: resolve(outDir, "00-before.png"), fullPage: true });

  console.log("→ click 管理 link");
  // 「コンプライアンスがありません 管理」 の隣の「管理」リンク
  await page.getByText("管理", { exact: true }).first().click();
  await page.waitForTimeout(3000);

  await page.screenshot({ path: resolve(outDir, "01-after-manage.png"), fullPage: true });
  writeFileSync(resolve(outDir, "01.html"), await page.content());

  const text = await page.evaluate(() => document.body.innerText);
  writeFileSync(resolve(outDir, "01-text.txt"), text);
  console.log("→ page text (first 3000):");
  console.log(text.slice(0, 3000));

  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
