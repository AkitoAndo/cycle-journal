/**
 * Monthly の「お試しオファーを設定」ボタンを押した先の入力画面を inspect。
 * モーダルが出るかページ遷移するかを確認する。実際の保存はしない。
 *
 * 実行: npx tsx src/asc/inspect-create-intro.ts
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = required("ASC_APP_ID");
const SUB_ID = required("ASC_PRODUCT_MONTHLY_SUB_ID", "6775457213");
const URL = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/subscriptions/${SUB_ID}/pricing/intro-offers`;

async function main() {
  const inspectDir = resolve(OPS_ROOT, ".inspect");
  mkdirSync(inspectDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  console.log("→ clicking 「お試しオファーを設定」");
  await page.getByRole("button", { name: "お試しオファーを設定" }).click();
  await page.waitForTimeout(3000);

  await page.screenshot({ path: resolve(inspectDir, "create-intro-step1.png"), fullPage: true });
  writeFileSync(resolve(inspectDir, "create-intro-step1.html"), await page.content());

  const summary = await page.evaluate(() => {
    const rows: { text: string; href?: string; tag: string; name?: string; type?: string }[] = [];
    document
      .querySelectorAll(
        "a, button, [role='button'], h1, h2, h3, h4, label, input, select, option, [role='dialog']",
      )
      .forEach((el) => {
        const text = (el.textContent || (el as HTMLInputElement).value || "")
          .replace(/\s+/g, " ")
          .trim()
          .slice(0, 200);
        const inputEl = el as HTMLInputElement;
        rows.push({
          text,
          href: (el as HTMLAnchorElement).href || undefined,
          tag: el.tagName.toLowerCase(),
          name: inputEl.name || undefined,
          type: inputEl.type || undefined,
        });
      });
    return rows;
  });
  writeFileSync(resolve(inspectDir, "create-intro-step1-summary.json"), JSON.stringify(summary, null, 2));
  console.log(`✓ captured step1 (${summary.length} entries) — no save performed`);

  await browser.close();
}

function required(name: string, fallback?: string): string {
  const v = process.env[name] ?? fallback;
  if (!v) throw new Error(`missing env: ${name}`);
  return v;
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
