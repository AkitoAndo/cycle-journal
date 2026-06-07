/**
 * App Store Connect の「アプリ情報」ページの DOM 構造を確認。
 * Privacy Policy URL / 利用規約 URL の入力欄を特定する。
 *
 * 実行: npx tsx src/asc/inspect-app-info.ts
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = required("ASC_APP_ID");
const URL = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/info`;

async function main() {
  const inspectDir = resolve(OPS_ROOT, ".inspect");
  mkdirSync(inspectDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);

  await page.screenshot({ path: resolve(inspectDir, "app-info.png"), fullPage: true });
  writeFileSync(resolve(inspectDir, "app-info.html"), await page.content());

  const summary = await page.evaluate(() => {
    const rows: { text: string; tag: string; name?: string; type?: string }[] = [];
    document
      .querySelectorAll("h1, h2, h3, h4, label, input, textarea, button, [role='button']")
      .forEach((el) => {
        const text = (el.textContent || (el as HTMLInputElement).value || "")
          .replace(/\s+/g, " ")
          .trim()
          .slice(0, 200);
        if (!text) return;
        const inputEl = el as HTMLInputElement;
        rows.push({
          text,
          tag: el.tagName.toLowerCase(),
          name: inputEl.name || undefined,
          type: inputEl.type || undefined,
        });
      });
    return rows;
  });
  writeFileSync(resolve(inspectDir, "app-info-summary.json"), JSON.stringify(summary, null, 2));
  console.log(`✓ inspected app-info (${summary.length} entries)`);

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
