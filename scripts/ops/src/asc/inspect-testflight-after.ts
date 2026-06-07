/**
 * 1.0.1 processing 完了後の TestFlight ページを inspect。
 * Internal Testing group 作成 UI と Build 1.0.1 の状態を確認。
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

async function main() {
  const outDir = resolve(OPS_ROOT, ".inspect/testflight-after");
  mkdirSync(outDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto("https://appstoreconnect.apple.com/apps/6760911210/testflight/ios", {
    waitUntil: "domcontentloaded",
  });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);

  await page.screenshot({ path: resolve(outDir, "main.png"), fullPage: true });
  writeFileSync(resolve(outDir, "main.html"), await page.content());

  const text = await page.evaluate(() => document.body.innerText);
  writeFileSync(resolve(outDir, "text.txt"), text);
  console.log("→ first 3000 chars:");
  console.log(text.slice(0, 3000));

  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
