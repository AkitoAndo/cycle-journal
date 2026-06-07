/**
 * 「APIキーを生成」ボタンを押した後のフォーム DOM を inspect。
 * 入力フィールド・権限選択・生成ボタンの構造を確認するだけ。
 * 鍵生成は行わない（キャンセルで閉じる）。
 *
 * 実行: npx tsx src/asc/inspect-generate-key.ts
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const URL = "https://appstoreconnect.apple.com/access/integrations/api";

async function main() {
  const outDir = resolve(OPS_ROOT, ".inspect/generate-key");
  mkdirSync(outDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  console.log("→ click APIキーを生成");
  await page.getByRole("button", { name: "APIキーを生成" }).click();
  await page.waitForTimeout(2500);

  await page.screenshot({ path: resolve(outDir, "form.png"), fullPage: true });
  writeFileSync(resolve(outDir, "form.html"), await page.content());

  const summary = await page.evaluate(() => {
    const rows: { text: string; tag: string }[] = [];
    document
      .querySelectorAll(
        "h1, h2, h3, h4, label, input, select, option, textarea, button, a, [role='button']",
      )
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
  writeFileSync(resolve(outDir, "form-summary.json"), JSON.stringify(summary, null, 2));
  console.log(`✓ captured (${summary.length} entries) — no key generated`);

  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
