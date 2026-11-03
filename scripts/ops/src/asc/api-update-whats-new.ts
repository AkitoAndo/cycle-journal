/**
 * 編集可能なApp Storeバージョンの日本語「このバージョンの新機能」を更新する。
 *
 * デフォルトはdry-run。
 * 実行:
 *   APP_STORE_VERSION=1.0.11 WHATS_NEW_PATH=../../docs/whats-new.md npx tsx src/asc/api-update-whats-new.ts
 *   APP_STORE_VERSION=1.0.11 WHATS_NEW_PATH=../../docs/whats-new.md APPLY=1 npx tsx src/asc/api-update-whats-new.ts
 */
import "dotenv/config";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const VERSION = process.env.APP_STORE_VERSION ?? "1.0.11";
const WHATS_NEW_PATH = process.env.WHATS_NEW_PATH;
const APPLY = process.env.APPLY === "1";
const editableStates = new Set(["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"]);

async function main() {
  if (!WHATS_NEW_PATH) throw new Error("WHATS_NEW_PATH is required");
  const whatsNew = (await readFile(resolve(WHATS_NEW_PATH), "utf8")).trim();
  if (!whatsNew) throw new Error("whatsNew must not be empty");
  if (whatsNew.length > 4_000) throw new Error(`whatsNew is too long: ${whatsNew.length}`);

  const versions = await ascApi<any>(`/v1/apps/${APP_ID}/appStoreVersions`, {
    query: {
      "filter[platform]": "IOS",
      "filter[versionString]": VERSION,
      limit: 1,
    },
  });
  const version = versions.data?.[0];
  if (!version) throw new Error(`App Store version ${VERSION} not found`);
  if (!editableStates.has(version.attributes.appStoreState)) {
    throw new Error(`Version ${VERSION} is not editable: ${version.attributes.appStoreState}`);
  }

  const localizations = await ascApi<any>(
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`,
  );
  const ja = localizations.data?.find(
    (localization: any) => ["ja", "ja-JP"].includes(localization.attributes?.locale),
  );
  if (!ja) throw new Error(`Japanese localization for ${VERSION} not found`);

  console.log(JSON.stringify({
    appId: APP_ID,
    apply: APPLY,
    locale: ja.attributes.locale,
    state: version.attributes.appStoreState,
    version: VERSION,
    whatsNew,
  }, null, 2));

  if (!APPLY) {
    console.log("dry-run: no changes applied");
    return;
  }

  await ascApi(`/v1/appStoreVersionLocalizations/${ja.id}`, {
    method: "PATCH",
    body: {
      data: {
        type: "appStoreVersionLocalizations",
        id: ja.id,
        attributes: { whatsNew },
      },
    },
  });

  const verified = await ascApi<any>(`/v1/appStoreVersionLocalizations/${ja.id}`);
  if (verified.data?.attributes?.whatsNew !== whatsNew) {
    throw new Error("whatsNew verification failed");
  }
  console.log(`✓ updated and verified whatsNew for ${VERSION}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
