/**
 * 初回 ASC ログイン: ヘッドフルブラウザで Apple ID + 2FA を通し、storageState を保存する。
 *
 * 流れ:
 *   1. chromium ヘッドフルで appstoreconnect.apple.com/apps を開く
 *   2. ユーザーが画面で Apple ID / パスワード / 2FA を入力
 *   3. ログイン完了して /apps に到達したら storageState を保存して終了
 *
 * 実行: npm run asc:login
 */
import { ASC_STORAGE_STATE, launch, saveState } from "../lib/browser.js";

const APPS_URL = "https://appstoreconnect.apple.com/apps";
const LOGIN_TIMEOUT_MS = 10 * 60 * 1000;

async function main() {
  console.log("→ ヘッドフル Chromium を開きます。Apple ID / パスワード / 2FA を画面で入力してください。");
  console.log("→ 最大 10 分待ちます。ログイン完了（Apps 一覧表示）を検知したら自動で state を保存します。");

  const { browser, context, page } = await launch({ headless: false });
  await page.goto(APPS_URL);

  await page.waitForURL(/appstoreconnect\.apple\.com\/apps(\/|$|\?)/, {
    timeout: LOGIN_TIMEOUT_MS,
  });

  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {
    // networkidle に到達しないテナントもあるため失敗は無視
  });

  await saveState(context, ASC_STORAGE_STATE);
  console.log(`✓ saved: ${ASC_STORAGE_STATE}`);
  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
