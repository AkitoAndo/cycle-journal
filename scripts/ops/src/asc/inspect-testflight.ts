/**
 * ASC TestFlight ページを inspect。
 * - Build processing 状態
 * - Public Link (testflight.apple.com/join/...) 取得 UI
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";

async function main() {
  const outDir = resolve(OPS_ROOT, ".inspect/testflight");
  mkdirSync(outDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  const url = `https://appstoreconnect.apple.com/apps/${APP_ID}/testflight/ios`;
  console.log(`→ ${url}`);
  await page.goto(url, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(4000);

  await page.screenshot({ path: resolve(outDir, "main.png"), fullPage: true });
  writeFileSync(resolve(outDir, "main.html"), await page.content());

  const text = await page.evaluate(() => document.body.innerText);
  writeFileSync(resolve(outDir, "text.txt"), text);
  console.log("→ first 2000 chars:");
  console.log(text.slice(0, 2000));

  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
