/**
 * ASC Integrations (API Key 発行) と Membership (Team ID 取得) ページの DOM 構造を inspect。
 * 実行: npx tsx src/asc/inspect-integrations.ts
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const INTEGRATIONS_URL = "https://appstoreconnect.apple.com/access/integrations/api";
const MEMBERSHIP_URL = "https://appstoreconnect.apple.com/access/users";

async function main() {
  const inspectDir = resolve(OPS_ROOT, ".inspect");
  mkdirSync(inspectDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });

  await capture(page, INTEGRATIONS_URL, "integrations", inspectDir);
  await capture(page, MEMBERSHIP_URL, "membership", inspectDir);

  await browser.close();
}

async function capture(page: Page, url: string, label: string, outDir: string) {
  console.log(`→ ${label}: ${url}`);
  await page.goto(url, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);
  await page.screenshot({ path: resolve(outDir, `${label}.png`), fullPage: true });
  writeFileSync(resolve(outDir, `${label}.html`), await page.content());

  const summary = await page.evaluate(() => {
    const rows: { text: string; tag: string }[] = [];
    document
      .querySelectorAll("h1, h2, h3, h4, label, input, textarea, button, a, [role='button'], td, th")
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
  writeFileSync(resolve(outDir, `${label}-summary.json`), JSON.stringify(summary, null, 2));
  console.log(`  ${summary.length} entries`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
