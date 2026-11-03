/**
 * 編集可能なApp Storeバージョンの審査メモだけを更新する。
 * 連絡先やデモアカウント設定は変更しない。デフォルトはdry-run。
 */
import "dotenv/config";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const VERSION = process.env.APP_STORE_VERSION ?? "1.0.11";
const REVIEW_NOTES_PATH = process.env.REVIEW_NOTES_PATH;
const APPLY = process.env.APPLY === "1";
const editableStates = new Set(["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"]);

async function main() {
  if (!REVIEW_NOTES_PATH) throw new Error("REVIEW_NOTES_PATH is required");
  const notes = (await readFile(resolve(REVIEW_NOTES_PATH), "utf8")).trim();
  if (!notes) throw new Error("review notes must not be empty");
  if (notes.length > 4_000) throw new Error(`review notes are too long: ${notes.length}`);

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

  const current = await ascApi<any>(`/v1/appStoreVersions/${version.id}/appStoreReviewDetail`);
  if (!current.data?.id) throw new Error(`Review detail for ${VERSION} not found`);

  console.log(JSON.stringify({
    appId: APP_ID,
    apply: APPLY,
    currentContactEmail: current.data.attributes?.contactEmail,
    currentDemoAccountRequired: current.data.attributes?.demoAccountRequired,
    notes,
    reviewDetailId: current.data.id,
    state: version.attributes.appStoreState,
    version: VERSION,
  }, null, 2));

  if (!APPLY) {
    console.log("dry-run: no changes applied");
    return;
  }

  await ascApi(`/v1/appStoreReviewDetails/${current.data.id}`, {
    method: "PATCH",
    body: {
      data: {
        type: "appStoreReviewDetails",
        id: current.data.id,
        attributes: { notes },
      },
    },
  });

  const verified = await ascApi<any>(`/v1/appStoreReviewDetails/${current.data.id}`);
  if (verified.data?.attributes?.notes !== notes) throw new Error("Review notes verification failed");
  console.log(`✓ updated and verified review notes for ${VERSION}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
