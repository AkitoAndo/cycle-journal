/**
 * 「開始日」「終了日」のセレクタの選択肢を確認する。
 * step2 まで進めてから datepicker をクリックして、何が出るか撮る。
 */
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const APP_ID = required("ASC_APP_ID");
const SUB_ID = process.env.ASC_PRODUCT_MONTHLY_SUB_ID || "6775457213";
const URL = `https://appstoreconnect.apple.com/apps/${APP_ID}/distribution/subscriptions/${SUB_ID}/pricing/intro-offers`;
const OUT = resolve(OPS_ROOT, ".inspect/datepicker");

async function main() {
  mkdirSync(OUT, { recursive: true });
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  await page.getByRole("button", { name: "お試しオファーを設定" }).click();
  await page.waitForTimeout(2000);
  await page.getByRole("button", { name: "次へ" }).click();
  await page.waitForTimeout(2000);

  console.log("→ inspect react-datepicker inputs");
  const inputs = page.locator(".react-datepicker__input-container input");
  const count = await inputs.count();
  console.log(`  found ${count} datepicker inputs`);

  // 開始日ドロップダウンを開く
  console.log("→ click 開始日 input");
  await inputs.nth(0).click();
  await page.waitForTimeout(1500);
  await page.screenshot({ path: resolve(OUT, "start-open.png"), fullPage: false });
  writeFileSync(resolve(OUT, "start-open.html"), await page.content());

  // 終了日ドロップダウンを開く（先に開始日を閉じてから）
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);
  console.log("→ click 終了日 input");
  await inputs.nth(1).click();
  await page.waitForTimeout(1500);
  await page.screenshot({ path: resolve(OUT, "end-open.png"), fullPage: false });
  writeFileSync(resolve(OUT, "end-open.html"), await page.content());

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
