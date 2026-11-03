/**
 * App Store versionだけを審査提出する。サブスクリプションは追加しない。
 * 7枚のiPhone/iPad画像、更新内容、ビルド、自動公開設定を事前検証する。
 *
 * デフォルトはdry-run。
 * 実行:
 *   APP_STORE_VERSION=1.0.11 BUILD_NUMBER=1789344790 npm run asc:submit-app-version-review
 *   APP_STORE_VERSION=1.0.11 BUILD_NUMBER=1789344790 APPLY=1 npm run asc:submit-app-version-review
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const VERSION = process.env.APP_STORE_VERSION ?? "1.0.11";
const BUILD_NUMBER = process.env.BUILD_NUMBER;
const APPLY = process.env.APPLY === "1";
const REQUIRED_SCREENSHOTS: Record<string, number> = {
  APP_IPHONE_67: 7,
  APP_IPHONE_65: 0,
  APP_IPAD_PRO_3GEN_129: 7,
};

type Submission = {
  id: string;
  attributes?: { state?: string; submittedDate?: string };
};

async function screenshotCounts(localizationId: string) {
  const sets = await ascApi<any>(
    `/v1/appStoreVersionLocalizations/${localizationId}/appScreenshotSets`,
    { query: { limit: 50 } },
  );
  const counts: Record<string, number> = {};
  for (const set of sets.data ?? []) {
    const displayType = set.attributes?.screenshotDisplayType;
    if (!(displayType in REQUIRED_SCREENSHOTS)) continue;
    const screenshots = await ascApi<any>(`/v1/appScreenshotSets/${set.id}/appScreenshots`, {
      query: { limit: 50 },
    });
    for (const screenshot of screenshots.data ?? []) {
      const state = screenshot.attributes?.assetDeliveryState?.state;
      if (state !== "COMPLETE") {
        throw new Error(`${displayType} screenshot ${screenshot.id} is not COMPLETE: ${state}`);
      }
    }
    counts[displayType] = screenshots.data?.length ?? 0;
  }
  for (const displayType of Object.keys(REQUIRED_SCREENSHOTS)) counts[displayType] ??= 0;
  return counts;
}

async function listSubmissions() {
  const response = await ascApi<{ data: Submission[] }>(
    `/v1/apps/${APP_ID}/reviewSubmissions`,
    { query: { "filter[platform]": "IOS", limit: 50 } },
  );
  return response.data ?? [];
}

async function submissionItems(submissionId: string) {
  return ascApi<any>(`/v1/reviewSubmissions/${submissionId}/items`, {
    query: { include: "appStoreVersion", limit: 50 },
  });
}

function validateVersionOnlyItems(response: any, versionId: string) {
  const items = response.data ?? [];
  if (items.length !== 1) throw new Error(`Review submission has ${items.length} items; expected 1`);
  const item = items[0];
  const itemVersionId = item.relationships?.appStoreVersion?.data?.id;
  if (itemVersionId !== versionId) {
    throw new Error(`Review item targets appStoreVersion ${itemVersionId ?? "none"}`);
  }
  const subscriptionId = item.relationships?.subscription?.data?.id;
  if (subscriptionId) throw new Error(`Review item unexpectedly includes subscription ${subscriptionId}`);
  return item;
}

async function main() {
  if (!BUILD_NUMBER) throw new Error("BUILD_NUMBER is required");

  const versions = await ascApi<any>(`/v1/apps/${APP_ID}/appStoreVersions`, {
    query: {
      "filter[platform]": "IOS",
      "filter[versionString]": VERSION,
      limit: 1,
    },
  });
  const version = versions.data?.[0];
  if (!version) throw new Error(`App Store version ${VERSION} not found`);
  if (version.attributes?.appStoreState !== "PREPARE_FOR_SUBMISSION") {
    throw new Error(`Version ${VERSION} cannot be submitted: ${version.attributes?.appStoreState}`);
  }
  if (version.attributes?.releaseType !== "AFTER_APPROVAL") {
    throw new Error(`Automatic release is not enabled: ${version.attributes?.releaseType}`);
  }

  const build = await ascApi<any>(`/v1/appStoreVersions/${version.id}/build`);
  if (build.data?.attributes?.version !== BUILD_NUMBER) {
    throw new Error(
      `Attached build is ${build.data?.attributes?.version ?? "none"}, expected ${BUILD_NUMBER}`,
    );
  }
  if (build.data?.attributes?.processingState !== "VALID") {
    throw new Error(`Attached build is not VALID: ${build.data?.attributes?.processingState}`);
  }
  if (build.data?.attributes?.expired) throw new Error(`Attached build ${BUILD_NUMBER} is expired`);
  if (build.data?.attributes?.usesNonExemptEncryption !== false) {
    throw new Error(
      `Attached build encryption declaration is not exempt: ${build.data?.attributes?.usesNonExemptEncryption}`,
    );
  }

  const localizations = await ascApi<any>(
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`,
  );
  const ja = localizations.data?.find(
    (localization: any) => ["ja", "ja-JP"].includes(localization.attributes?.locale),
  );
  if (!ja) throw new Error(`Japanese localization for ${VERSION} not found`);
  if (!ja.attributes?.whatsNew?.trim()) throw new Error("Japanese whatsNew is empty");
  for (const field of ["description", "keywords", "supportUrl"]) {
    if (!ja.attributes?.[field]?.trim()) throw new Error(`Japanese localization is empty: ${field}`);
  }

  const counts = await screenshotCounts(ja.id);
  for (const [displayType, expected] of Object.entries(REQUIRED_SCREENSHOTS)) {
    if (counts[displayType] !== expected) {
      throw new Error(`${displayType} has ${counts[displayType]} screenshots; expected ${expected}`);
    }
  }

  const reviewDetail = await ascApi<any>(`/v1/appStoreVersions/${version.id}/appStoreReviewDetail`);
  const requiredReviewFields = ["contactFirstName", "contactLastName", "contactEmail", "contactPhone"];
  for (const field of requiredReviewFields) {
    if (!reviewDetail.data?.attributes?.[field]?.trim()) {
      throw new Error(`App Review field is empty: ${field}`);
    }
  }
  if (!reviewDetail.data?.attributes?.notes?.trim()) throw new Error("App Review notes are empty");

  const submissions = await listSubmissions();
  const active = submissions.find((submission) => submission.attributes?.state !== "COMPLETE");
  if (active && active.attributes?.state !== "READY_FOR_REVIEW") {
    throw new Error(
      `An active review submission already exists: ${active.id} (${active.attributes?.state})`,
    );
  }
  const activeItems = active ? await submissionItems(active.id) : null;
  const activeItemCount = activeItems?.data?.length ?? 0;
  if (activeItemCount > 0) validateVersionOnlyItems(activeItems, version.id);
  console.log(JSON.stringify({
    activeSubmission: active
      ? { id: active.id, itemCount: activeItemCount, state: active.attributes?.state }
      : null,
    appId: APP_ID,
    apply: APPLY,
    buildId: build.data.id,
    buildNumber: BUILD_NUMBER,
    locale: ja.attributes.locale,
    releaseType: version.attributes.releaseType,
    screenshots: counts,
    state: version.attributes.appStoreState,
    version: VERSION,
    versionId: version.id,
    whatsNew: ja.attributes.whatsNew,
  }, null, 2));

  if (!APPLY) {
    console.log(active ? "dry-run: existing draft would be reused" : "dry-run: no submission created");
    return;
  }

  let submissionId = active?.id;
  if (!submissionId) {
    const created = await ascApi<any>("/v1/reviewSubmissions", {
      method: "POST",
      body: {
        data: {
          type: "reviewSubmissions",
          attributes: { platform: "IOS" },
          relationships: { app: { data: { type: "apps", id: APP_ID } } },
        },
      },
    });
    submissionId = created.data?.id;
    if (!submissionId) throw new Error("Review submission creation returned no id");
    console.log(`✓ created review submission ${submissionId}`);
  } else {
    console.log(`✓ reusing review submission ${submissionId}`);
  }

  if (activeItemCount === 0) {
    const item = await ascApi<any>("/v1/reviewSubmissionItems", {
      method: "POST",
      body: {
        data: {
          type: "reviewSubmissionItems",
          relationships: {
            appStoreVersion: { data: { type: "appStoreVersions", id: version.id } },
            reviewSubmission: {
              data: { type: "reviewSubmissions", id: submissionId },
            },
          },
        },
      },
    });
    console.log(`✓ added appStoreVersion item ${item.data?.id}`);
  }

  validateVersionOnlyItems(await submissionItems(submissionId), version.id);

  await ascApi(`/v1/reviewSubmissions/${submissionId}`, {
    method: "PATCH",
    body: {
      data: {
        type: "reviewSubmissions",
        id: submissionId,
        attributes: { submitted: true },
      },
    },
  });
  const acceptedStates = new Set(["WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING", "COMPLETE"]);
  let verified: any;
  for (let attempt = 0; attempt < 10; attempt += 1) {
    verified = await ascApi<any>(`/v1/reviewSubmissions/${submissionId}`);
    if (acceptedStates.has(verified.data?.attributes?.state)) break;
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 2_000));
  }
  const state = verified?.data?.attributes?.state;
  const submittedDate = verified?.data?.attributes?.submittedDate;
  if (!acceptedStates.has(state) || !submittedDate) {
    throw new Error(`Submission ${submissionId} was not accepted: ${state ?? "unknown"}`);
  }
  const verifiedVersion = await ascApi<any>(`/v1/appStoreVersions/${version.id}`);
  if (verifiedVersion.data?.attributes?.releaseType !== "AFTER_APPROVAL") {
    throw new Error(`Automatic release changed to ${verifiedVersion.data?.attributes?.releaseType}`);
  }
  console.log(
    `✓ submitted ${submissionId}: state=${state} submittedDate=${submittedDate} releaseType=AFTER_APPROVAL`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
