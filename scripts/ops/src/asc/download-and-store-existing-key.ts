/**
 * 既に発行済の ASC API Key の .p8 をダウンロードし、Secret Manager に投入する。
 * Key ID と Issuer ID は integrations ページから自動取得。
 *
 * 注: .p8 のダウンロードリンクは ASC では生成直後の限定時間しか有効でない可能性がある。
 * 「ダウンロード」リンクが消えていたら鍵を削除して再発行する必要あり。
 */
import "dotenv/config";
import { execSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const URL = "https://appstoreconnect.apple.com/access/integrations/api";
const KEY_NAME = process.env.ASC_API_KEY_NAME ?? "cycle-journal-claude-ops";
const GCP_PROJECT = process.env.GCP_PROJECT ?? "cycle-journal";
const SHOT_DIR = resolve(OPS_ROOT, ".inspect/download-key");
const DOWNLOAD_DIR = resolve(OPS_ROOT, ".auth/tmp-downloads");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  mkdirSync(DOWNLOAD_DIR, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  console.log("→ extract issuer id");
  const issuerId = await extractIssuerId(page);
  console.log(`  Issuer ID: ${issuerId}`);

  console.log("→ extract key id from row");
  const keyId = await extractKeyId(page, KEY_NAME);
  console.log(`  Key ID: ${keyId}`);

  if (!issuerId || !keyId) {
    await page.screenshot({ path: resolve(SHOT_DIR, "no-meta.png"), fullPage: true });
    throw new Error("missing issuer or key id");
  }

  console.log("→ click ダウンロード link in row");
  await clickDownload(page, KEY_NAME);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: resolve(SHOT_DIR, "confirm-dialog.png"), fullPage: true });

  console.log("→ confirm dialog: click ダウンロード button");
  const dlg = page.getByRole("dialog");
  const downloadPromise = page.waitForEvent("download", { timeout: 60_000 });
  await dlg.getByRole("button", { name: "ダウンロード" }).click();
  const download = await downloadPromise;
  const p8Path = resolve(DOWNLOAD_DIR, `AuthKey_${keyId}.p8`);
  await download.saveAs(p8Path);
  console.log(`  saved: ${p8Path}`);

  if (!existsSync(p8Path)) {
    throw new Error(`.p8 not found at ${p8Path}`);
  }

  console.log("→ store in Secret Manager");
  const p8 = readFileSync(p8Path, "utf-8");
  storeSecret("app-store-connect-api-key", p8, GCP_PROJECT);
  storeSecret("app-store-connect-key-id", keyId, GCP_PROJECT);
  storeSecret("app-store-connect-issuer-id", issuerId, GCP_PROJECT);

  console.log("→ remove local .p8");
  rmSync(p8Path, { force: true });
  console.log("✓ done");

  await browser.close();
}

async function extractIssuerId(page: Page): Promise<string | null> {
  // 「Issuer ID」見出しの下の行に UUID がある。
  // 全文から UUID 形式を取る（ページ全体に複数あっても 1 個目は Issuer ID と想定）
  const text = await page.evaluate(() => document.body.innerText);
  const m = text.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/);
  return m?.[0] ?? null;
}

async function extractKeyId(page: Page, keyName: string): Promise<string | null> {
  // page text 全体から keyName 直後の 200 chars 内に 10 文字英大数字を探す
  const text = await page.evaluate(() => document.body.innerText);
  const idx = text.indexOf(keyName);
  if (idx < 0) return null;
  const after = text.substring(idx + keyName.length, idx + keyName.length + 300);
  const m = after.match(/\b[A-Z0-9]{10}\b/);
  return m?.[0] ?? null;
}

async function clickDownload(page: Page, keyName: string): Promise<void> {
  // 名前を含む行内の「ダウンロード」リンクをクリック
  const row = page
    .locator("tr, [role='row']")
    .filter({ hasText: keyName })
    .first();
  if (await row.count()) {
    const link = row.getByText("ダウンロード").first();
    if (await link.count()) {
      await link.click();
      return;
    }
  }
  // フォールバック：ページ全体から「ダウンロード」link
  await page.getByText("ダウンロード").first().click();
}

function storeSecret(name: string, value: string, project: string): void {
  let exists = false;
  try {
    execSync(`gcloud secrets describe ${name} --project=${project} >/dev/null 2>&1`);
    exists = true;
  } catch {
    exists = false;
  }
  if (!exists) {
    execSync(
      `gcloud secrets create ${name} --replication-policy=automatic --project=${project} >/dev/null`,
    );
  }
  execSync(`gcloud secrets versions add ${name} --data-file=- --project=${project} >/dev/null`, {
    input: value,
  });
  console.log(`  ✓ ${name} (${exists ? "new version" : "created"})`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
