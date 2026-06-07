/**
 * Apple Developer Portal の Certificates ページを inspect。
 * Distribution certificate が登録されているか確認。
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

async function main() {
  const outDir = resolve(OPS_ROOT, ".inspect/dev-certificates");
  mkdirSync(outDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  await page.goto("https://developer.apple.com/account/resources/certificates/list", {
    waitUntil: "domcontentloaded",
  });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(4000);

  await page.screenshot({ path: resolve(outDir, "list.png"), fullPage: true });
  writeFileSync(resolve(outDir, "list.html"), await page.content());

  const text = await page.evaluate(() => document.body.innerText);
  writeFileSync(resolve(outDir, "text.txt"), text);
  console.log("→ first 1000 chars of page text:");
  console.log(text.slice(0, 1000));

  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
