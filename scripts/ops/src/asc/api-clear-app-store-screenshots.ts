/**
 * 編集可能なApp Storeバージョンの特定表示枠から、登録済み画像を削除する。
 * 高解像度枠からの自動縮小へ戻す用途を想定する。デフォルトはdry-run。
 *
 * 実行:
 *   APP_STORE_VERSION=1.0.11 SCREENSHOT_DISPLAY_TYPE=APP_IPHONE_65 npx tsx src/asc/api-clear-app-store-screenshots.ts
 *   APP_STORE_VERSION=1.0.11 SCREENSHOT_DISPLAY_TYPE=APP_IPHONE_65 APPLY=1 npx tsx src/asc/api-clear-app-store-screenshots.ts
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const VERSION = process.env.APP_STORE_VERSION ?? "1.0.11";
const DISPLAY_TYPE = process.env.SCREENSHOT_DISPLAY_TYPE;
const APPLY = process.env.APPLY === "1";
const editableStates = new Set(["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"]);

async function main() {
  if (!DISPLAY_TYPE) throw new Error("SCREENSHOT_DISPLAY_TYPE is required");

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

  const sets = await ascApi<any>(
    `/v1/appStoreVersionLocalizations/${ja.id}/appScreenshotSets`,
    { query: { limit: 50 } },
  );
  const set = sets.data?.find(
    (candidate: any) => candidate.attributes?.screenshotDisplayType === DISPLAY_TYPE,
  );
  if (!set) throw new Error(`${DISPLAY_TYPE} screenshot set not found`);

  const screenshots = await ascApi<any>(`/v1/appScreenshotSets/${set.id}/appScreenshots`, {
    query: { limit: 50 },
  });
  console.log(JSON.stringify({
    appId: APP_ID,
    apply: APPLY,
    displayType: DISPLAY_TYPE,
    locale: ja.attributes.locale,
    screenshots: screenshots.data.map((screenshot: any) => ({
      fileName: screenshot.attributes?.fileName,
      id: screenshot.id,
      state: screenshot.attributes?.assetDeliveryState?.state,
    })),
    setId: set.id,
    state: version.attributes.appStoreState,
    version: VERSION,
  }, null, 2));

  if (!APPLY) {
    console.log("dry-run: no changes applied");
    return;
  }

  for (const screenshot of screenshots.data) {
    await ascApi(`/v1/appScreenshots/${screenshot.id}`, { method: "DELETE" });
    console.log(`  ✓ deleted ${screenshot.id}`);
  }

  const verified = await ascApi<any>(`/v1/appScreenshotSets/${set.id}/appScreenshots`, {
    query: { limit: 50 },
  });
  if (verified.data.length !== 0) throw new Error(`${DISPLAY_TYPE} still contains screenshots`);
  console.log(`✓ cleared ${DISPLAY_TYPE} screenshots for ${VERSION}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
