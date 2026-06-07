/**
 * 「役割の選択」ドロップダウンを開いて選択肢を確認。
 * 鍵生成は行わない。
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const URL = "https://appstoreconnect.apple.com/access/integrations/api";

async function main() {
  const outDir = resolve(OPS_ROOT, ".inspect/role-options");
  mkdirSync(outDir, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  await page.getByRole("button", { name: "APIキーを生成" }).click();
  await page.waitForTimeout(2000);

  console.log("→ click 役割の選択 dropdown (placeholder/combobox)");
  const trigger = page.getByPlaceholder("役割の選択");
  if (await trigger.count()) {
    await trigger.click();
  } else {
    // fallback: combobox role
    await page.getByRole("combobox").click();
  }
  await page.waitForTimeout(1500);

  await page.screenshot({ path: resolve(outDir, "open.png"), fullPage: false });
  writeFileSync(resolve(outDir, "open.html"), await page.content());

  const opts = await page.evaluate(() => {
    const items: string[] = [];
    document.querySelectorAll("li, [role='option'], [role='menuitem']").forEach((el) => {
      const text = (el.textContent || "").replace(/\s+/g, " ").trim();
      if (text && text.length < 80) items.push(text);
    });
    return [...new Set(items)];
  });
  console.log("→ options:", opts);
  writeFileSync(resolve(outDir, "options.json"), JSON.stringify(opts, null, 2));

  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
