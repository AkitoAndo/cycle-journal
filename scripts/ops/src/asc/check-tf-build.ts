/**
 * TestFlight ビルド 1.0.1 が ASC に visible か確認するワンショット。
 * 出力: 「READY: 1.0.1 visible」 or 「WAITING」
 */
import "dotenv/config";
import { ASC_STORAGE_STATE, launch } from "../lib/browser.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const TARGET = process.env.TARGET_VERSION ?? "1.0.1";

async function main() {
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE, headless: true });
  await page.goto(`https://appstoreconnect.apple.com/apps/${APP_ID}/testflight/ios`, {
    waitUntil: "domcontentloaded",
  });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(3000);
  const text = await page.evaluate(() => document.body.innerText);
  const visible = text.includes(TARGET);
  await browser.close();
  if (visible) {
    console.log(`READY: ${TARGET} visible`);
  } else {
    console.log("WAITING");
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
