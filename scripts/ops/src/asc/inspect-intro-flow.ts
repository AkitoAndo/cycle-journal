/**
 * Introductory Offer 作成フローを「次へ」だけ押しながら各画面の screenshot + summary を撮る。
 * これでフロー全体の順序と各画面の選択肢を確定する。
 * 「キャンセル」または最後のステップで終了する（保存はしない）。
 *
 * 実行: npx tsx src/asc/inspect-intro-flow.ts
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = required("ASC_APP_ID");
const SUB_ID = process.env.ASC_PRODUCT_MONTHLY_SUB_ID || "6775457213";
const URL = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/subscriptions/${SUB_ID}/pricing/intro-offers`;
const OUT = resolve(OPS_ROOT, ".inspect/intro-walk");

async function main() {
  mkdirSync(OUT, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  await page.getByRole("button", { name: "お試しオファーを設定" }).click();
  await page.waitForTimeout(2000);

  for (let step = 1; step <= 10; step++) {
    const pad = String(step).padStart(2, "0");
    await page.screenshot({ path: resolve(OUT, `${pad}.png`), fullPage: true });
    writeFileSync(resolve(OUT, `${pad}.html`), await page.content());
    const summary = await page.evaluate(() => {
      const rows: { text: string; tag: string }[] = [];
      document
        .querySelectorAll(
          "h1, h2, h3, h4, label, input, select, option, button, [role='button']",
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
    writeFileSync(resolve(OUT, `${pad}.json`), JSON.stringify(summary, null, 2));
    console.log(`✓ step ${pad}: ${summary.length} entries`);

    // 「次へ」or「保存」or「確認」が押せる状態か確認
    const next = page.getByRole("button", { name: /^次へ$/ });
    if (await next.isVisible().catch(() => false)) {
      const disabled = await next.isDisabled().catch(() => false);
      if (disabled) {
        console.log(`  → 「次へ」disabled — likely waiting for input. stop here.`);
        break;
      }
      await next.click();
      await page.waitForTimeout(2000);
      continue;
    }
    const save = page.getByRole("button", { name: /^(保存|確認|完了)$/ });
    if (await save.isVisible().catch(() => false)) {
      console.log(`  → 「保存/確認/完了」detected. NOT clicking. stop here.`);
      break;
    }
    console.log(`  → no 次へ / no 保存. stop here.`);
    break;
  }

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
