/**
 * developer.apple.com にアクセスして Team ID を取得できるか確認。
 * ASC と同じ Apple ID で SSO されている前提。されていなければ手動ログイン必要。
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

async function main() {
  const outDir = resolve(OPS_ROOT, ".inspect/developer-account");
  mkdirSync(outDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  await page.goto("https://developer.apple.com/account/", { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);

  await page.screenshot({ path: resolve(outDir, "account.png"), fullPage: true });
  writeFileSync(resolve(outDir, "account.html"), await page.content());

  const url = page.url();
  console.log(`current URL: ${url}`);

  const text = await page.evaluate(() => document.body.innerText);
  // Team ID = 10 文字英大数字
  const teamIdMatch = text.match(/\b[A-Z0-9]{10}\b/g);
  console.log("possible team IDs in page text:", teamIdMatch?.slice(0, 5) ?? "none");
  writeFileSync(resolve(outDir, "text-snippet.txt"), text.slice(0, 3000));

  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
