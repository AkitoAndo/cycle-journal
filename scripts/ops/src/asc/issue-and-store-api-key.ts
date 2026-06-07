/**
 * ASC API Key を発行し、.p8 / Key ID / Issuer ID を GCP Secret Manager に投入する。
 *
 * 環境変数:
 *   DRY_RUN=1     名前 / 役割選択まで進めて screenshot を撮るだけ（デフォルト）
 *   DRY_RUN=0     実際に発行 → ダウンロード → Secret Manager 投入 → ローカル削除
 *   ASC_API_KEY_NAME    Key 名前 (デフォルト: cycle-journal-claude-ops)
 *   ASC_API_KEY_ROLE    Key 役割 (デフォルト: App Manager)
 *   GCP_PROJECT         GCP プロジェクト ID (デフォルト: cycle-journal)
 *
 * .p8 / Key ID / Issuer ID は Secret Manager に保存され、ローカルからは削除される。
 *   Secret 名: app-store-connect-api-key (.p8 PEM)
 *             app-store-connect-key-id
 *             app-store-connect-issuer-id
 */
import "dotenv/config";
import { execSync } from "node:child_process";
import { existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import type { Page } from "playwright";
import { ASC_STORAGE_STATE, OPS_ROOT, launch } from "../lib/browser.js";

const URL = "https://appstoreconnect.apple.com/access/integrations/api";
const DRY_RUN = (process.env.DRY_RUN ?? "1") !== "0";
const KEY_NAME = process.env.ASC_API_KEY_NAME ?? "cycle-journal-claude-ops";
const ROLE = process.env.ASC_API_KEY_ROLE ?? "App Manager";
const GCP_PROJECT = process.env.GCP_PROJECT ?? "cycle-journal";

const SHOT_DIR = resolve(OPS_ROOT, ".inspect/issue-key");
const DOWNLOAD_DIR = resolve(OPS_ROOT, ".auth/tmp-downloads");

async function main() {
  mkdirSync(SHOT_DIR, { recursive: true });
  mkdirSync(DOWNLOAD_DIR, { recursive: true });

  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  console.log(`→ open integrations (DRY_RUN=${DRY_RUN ? "1" : "0"})`);
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  console.log("→ click APIキーを生成 or アクティブ + button");
  const primaryBtn = page.getByRole("button", { name: "APIキーを生成" });
  if (await primaryBtn.count()) {
    await primaryBtn.click();
  } else {
    // 既にキーが 1 つ以上ある場合：「アクティブ (N)」見出しの隣の + button
    const addBtn = page
      .locator("h3", { hasText: "アクティブ" })
      .locator("xpath=following-sibling::button")
      .first();
    await addBtn.click();
  }
  await page.waitForTimeout(2000);
  await shot(page, "00-form");

  console.log(`→ fill name: ${KEY_NAME}`);
  const dlg = page.getByRole("dialog");
  await dlg.locator("input").first().fill(KEY_NAME);
  await page.waitForTimeout(300);

  console.log(`→ select role: ${ROLE}`);
  await dlg.getByPlaceholder("役割の選択").click();
  await page.waitForTimeout(800);
  await page.getByText(ROLE, { exact: true }).first().click();
  await page.waitForTimeout(500);
  await shot(page, "01-ready");

  if (DRY_RUN) {
    console.log("→ DRY_RUN: stopping before 生成");
    await browser.close();
    return;
  }

  console.log("→ click 生成");
  const downloadPromise = waitForP8Download(page);
  await dlg.getByRole("button", { name: "生成" }).click();
  await page.waitForTimeout(4000);
  await shot(page, "02-after-generate");

  // 生成後ページ: スクショから Key ID / Issuer ID を抽出
  const meta = await extractKeyMeta(page);
  console.log("→ extracted meta:", meta);
  if (!meta.keyId || !meta.issuerId) {
    console.error("✗ failed to extract key meta. screenshot saved.");
    throw new Error("missing key id or issuer id");
  }

  // .p8 ダウンロード
  console.log("→ download .p8");
  await downloadP8(page, meta.keyId);
  const p8Path = resolve(DOWNLOAD_DIR, `AuthKey_${meta.keyId}.p8`);
  if (!existsSync(p8Path)) {
    // download トリガが拾えなかった場合
    const download = await downloadPromise;
    await download.saveAs(p8Path);
  }

  console.log("→ store secrets in Secret Manager");
  storeSecret("app-store-connect-api-key", await fileContent(p8Path), GCP_PROJECT);
  storeSecret("app-store-connect-key-id", meta.keyId, GCP_PROJECT);
  storeSecret("app-store-connect-issuer-id", meta.issuerId, GCP_PROJECT);

  console.log("→ remove local .p8");
  rmSync(p8Path, { force: true });
  console.log("✓ done. Secret names: app-store-connect-{api-key,key-id,issuer-id}");

  await browser.close();
}

interface KeyMeta {
  keyId: string | null;
  issuerId: string | null;
}

async function extractKeyMeta(page: Page): Promise<KeyMeta> {
  // ページから「Issuer ID」「Key ID」を文字列で抽出する。
  // ラベルとセル構造はテーブル風が一般的。
  const text = await page.evaluate(() => document.body.innerText);
  const keyId = matchAfter(text, /(?:Key\s*ID|キーID)[:\s]*([A-Z0-9]{6,})/i);
  const issuerId = matchAfter(
    text,
    /(?:Issuer\s*ID|発行者\s*ID)[:\s]*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i,
  );
  return { keyId, issuerId };
}

function matchAfter(text: string, re: RegExp): string | null {
  const m = text.match(re);
  return m?.[1] ?? null;
}

async function downloadP8(page: Page, keyId: string): Promise<void> {
  // ダウンロードボタン候補
  const candidates = [
    /^APIキーをダウンロード$/,
    /^ダウンロード$/,
    /^Download API Key$/,
    /^Download$/,
  ];
  for (const re of candidates) {
    const btn = page.getByRole("button", { name: re });
    if (await btn.count()) {
      await btn.first().click();
      await page.waitForTimeout(1000);
      return;
    }
  }
  // link 形式の可能性
  for (const re of candidates) {
    const link = page.getByRole("link", { name: re });
    if (await link.count()) {
      await link.first().click();
      return;
    }
  }
  console.warn(`! no download button found for keyId=${keyId}`);
}

function waitForP8Download(page: Page) {
  return page.waitForEvent("download", { timeout: 60_000 }).then((download) => download);
}

async function fileContent(path: string): Promise<string> {
  const { readFile } = await import("node:fs/promises");
  return readFile(path, "utf-8");
}

function storeSecret(name: string, value: string, project: string): void {
  // create or add new version
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
  // value を stdin 経由で渡す
  const cmd = `gcloud secrets versions add ${name} --data-file=- --project=${project} >/dev/null`;
  execSync(cmd, { input: value });
  console.log(`  ✓ ${name} (${exists ? "new version" : "created"})`);
}

async function shot(page: Page, name: string): Promise<void> {
  await page.screenshot({ path: resolve(SHOT_DIR, `${name}.png`), fullPage: true });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
