/**
 * 1.0.3 version の detail ページに行き、「Submit to App Review」 UI を探す。
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

async function main() {
  const outDir = resolve(OPS_ROOT, ".inspect/new-submission");
  mkdirSync(outDir, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  // reviewsubmissions list page にもどる
  await page.goto(
    "https://appstoreconnect.apple.com/apps/6760911210/distribution/reviewsubmissions",
    { waitUntil: "domcontentloaded" },
  );
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  // サイドバーの 1.0.3 リンクを試す
  console.log("→ click sidebar 1.0.3");
  await page.locator("text=1.0.3").first().click();
  await page.waitForTimeout(3000);
  console.log(`URL: ${page.url()}`);

  await page.screenshot({ path: resolve(outDir, "version-page.png"), fullPage: true });
  writeFileSync(resolve(outDir, "version.html"), await page.content());

  const text = await page.evaluate(() => document.body.innerText);
  writeFileSync(resolve(outDir, "version.txt"), text);
  console.log("--- text first 2000 ---");
  console.log(text.slice(0, 2000));

  const buttons = await page.locator("button:visible").allTextContents();
  console.log("\nbuttons:", buttons.map((b) => b.trim()).filter(Boolean).slice(0, 30));

  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
