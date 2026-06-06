/**
 * ログイン state が有効か確認。Apps 一覧が表示できれば OK。
 * 実行: npm run asc:status
 */
import { ASC_STORAGE_STATE, launch } from "../lib/browser.js";

async function main() {
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE, headless: true });
  await page.goto("https://appstoreconnect.apple.com/apps", { waitUntil: "domcontentloaded" });
  const url = page.url();
  if (url.includes("/login") || url.includes("idmsa.apple.com")) {
    console.error("✗ session expired — run `npm run asc:login`");
    process.exit(1);
  }
  console.log("✓ session OK:", url);
  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
