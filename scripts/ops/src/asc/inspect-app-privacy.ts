/**
 * App Store Connect の「アプリのプライバシー」ページの DOM 構造を確認。
 * Privacy Policy URL の入力欄を特定する。
 *
 * 実行: npx tsx src/asc/inspect-app-privacy.ts
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = required("ASC_APP_ID");
const URL = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/privacy`;

async function main() {
  const inspectDir = resolve(OPS_ROOT, ".inspect");
  mkdirSync(inspectDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);

  await page.screenshot({ path: resolve(inspectDir, "app-privacy.png"), fullPage: true });
  writeFileSync(resolve(inspectDir, "app-privacy.html"), await page.content());

  const summary = await page.evaluate(() => {
    const rows: { text: string; tag: string }[] = [];
    document
      .querySelectorAll("h1, h2, h3, h4, label, input, textarea, button, a, [role='button']")
      .forEach((el) => {
        const text = (el.textContent || (el as HTMLInputElement).value || "")
          .replace(/\s+/g, " ")
          .trim()
          .slice(0, 200);
        if (!text) return;
        rows.push({ text, tag: el.tagName.toLowerCase() });
      });
    return rows;
  });
  writeFileSync(resolve(inspectDir, "app-privacy-summary.json"), JSON.stringify(summary, null, 2));
  console.log(`✓ inspected app-privacy (${summary.length} entries)`);

  await browser.close();
}

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`missing env: ${name}`);
  return v;
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
