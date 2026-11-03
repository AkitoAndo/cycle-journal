/**
 * App Store Connect の編集可能バージョンへ、App Store用画像を登録する。
 *
 * デフォルトはiPhone 6.9インチ・dry-run。既存画像がある場合、
 * REPLACE=1がない限り停止する。
 *
 * 実行:
 *   APP_STORE_VERSION=1.0.11 npm run asc:upload-screenshots
 *   APP_STORE_VERSION=1.0.11 APPLY=1 npm run asc:upload-screenshots
 *   APP_STORE_VERSION=1.0.11 APPLY=1 REPLACE=1 npm run asc:upload-screenshots
 *   APP_STORE_VERSION=1.0.11 SCREENSHOT_DISPLAY_TYPE=APP_IPAD_PRO_3GEN_129 npm run asc:upload-screenshots
 */
import "dotenv/config";
import { createHash } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import { basename, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { ascApi } from "../lib/asc-api.js";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../../../..");
const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const VERSION = process.env.APP_STORE_VERSION ?? "1.0.11";
// App Store Connect API keeps the APP_IPHONE_67 identifier for the current
// large-iPhone slot, which accepts Apple's 6.9-inch 1290x2796 asset size.
const DISPLAY_TYPE = process.env.SCREENSHOT_DISPLAY_TYPE ?? "APP_IPHONE_67";
if (!["APP_IPHONE_67", "APP_IPAD_PRO_3GEN_129"].includes(DISPLAY_TYPE)) {
  throw new Error(`Unsupported screenshot display type: ${DISPLAY_TYPE}`);
}
const APPLY = process.env.APPLY === "1";
const REPLACE = process.env.REPLACE === "1";
const target = DISPLAY_TYPE === "APP_IPAD_PRO_3GEN_129"
  ? { directory: "ipad-13", height: 2732, width: 2048 }
  : { directory: "iphone-6.9", height: 2796, width: 1290 };
const screenshotDir = resolve(repoRoot, "marketing/app-store/output/ja-JP", target.directory);
const screenshotPaths = [
  resolve(screenshotDir, "01-journal-to-action.png"),
  resolve(screenshotDir, "02-questioning-coach.png"),
  resolve(screenshotDir, "03-insight-to-task.png"),
  resolve(screenshotDir, "04-easy-journaling.png"),
  resolve(screenshotDir, "05-find-your-words.png"),
  resolve(screenshotDir, "06-dialogue-with-past.png"),
  resolve(screenshotDir, "07-daily-reflection.png"),
];
const editableStates = new Set(["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"]);
const pngSignature = "89504e470d0a1a0a";

type Resource<T> = {
  id: string;
  attributes: T;
};

type UploadOperation = {
  length: number;
  method: string;
  offset: number;
  requestHeaders: Array<{ name: string; value: string }>;
  url: string;
};

type ScreenshotAttributes = {
  assetDeliveryState?: { errors?: unknown[]; state?: string };
  fileName?: string;
  imageAsset?: { height?: number; width?: number };
  uploadOperations?: UploadOperation[];
};

async function validateScreenshots() {
  return Promise.all(
    screenshotPaths.map(async (path) => {
      const [buffer, info] = await Promise.all([readFile(path), stat(path)]);
      if (buffer.subarray(0, 8).toString("hex") !== pngSignature) {
        throw new Error(`${basename(path)} is not a PNG`);
      }
      const width = buffer.readUInt32BE(16);
      const height = buffer.readUInt32BE(20);
      const colorType = buffer.readUInt8(25);
      if (width !== target.width || height !== target.height) {
        throw new Error(`${basename(path)} has invalid dimensions: ${width}x${height}`);
      }
      if (colorType === 4 || colorType === 6) {
        throw new Error(`${basename(path)} contains an alpha channel`);
      }
      return { buffer, fileName: basename(path), fileSize: info.size, height, path, width };
    }),
  );
}

async function findVersion() {
  const response = await ascApi<{
    data: Array<Resource<{ appStoreState: string; platform: string; versionString: string }>>;
  }>(`/v1/apps/${APP_ID}/appStoreVersions`, {
    query: {
      "filter[platform]": "IOS",
      "filter[versionString]": VERSION,
      limit: 1,
    },
  });
  const version = response.data[0];
  if (!version) throw new Error(`App Store version ${VERSION} not found`);
  if (!editableStates.has(version.attributes.appStoreState)) {
    throw new Error(`Version ${VERSION} is not editable: ${version.attributes.appStoreState}`);
  }
  return version;
}

async function findJapaneseLocalization(versionId: string) {
  const response = await ascApi<{ data: Array<Resource<{ locale: string }>> }>(
    `/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations`,
  );
  const localization = response.data.find(({ attributes }) =>
    attributes.locale === "ja" || attributes.locale === "ja-JP"
  );
  if (!localization) throw new Error(`Japanese localization for ${VERSION} not found`);
  return localization;
}

async function findScreenshotSet(localizationId: string) {
  const response = await ascApi<{
    data: Array<Resource<{ screenshotDisplayType: string }>>;
  }>(`/v1/appStoreVersionLocalizations/${localizationId}/appScreenshotSets`, {
    query: { limit: 50 },
  });
  return {
    all: response.data,
    target: response.data.find(({ attributes }) => attributes.screenshotDisplayType === DISPLAY_TYPE),
  };
}

async function createScreenshotSet(localizationId: string) {
  return ascApi<{ data: Resource<{ screenshotDisplayType: string }> }>("/v1/appScreenshotSets", {
    method: "POST",
    body: {
      data: {
        type: "appScreenshotSets",
        attributes: { screenshotDisplayType: DISPLAY_TYPE },
        relationships: {
          appStoreVersionLocalization: {
            data: { type: "appStoreVersionLocalizations", id: localizationId },
          },
        },
      },
    },
  });
}

async function listScreenshots(setId: string) {
  return ascApi<{ data: Array<Resource<ScreenshotAttributes>> }>(
    `/v1/appScreenshotSets/${setId}/appScreenshots`,
    { query: { limit: 50 } },
  );
}

async function uploadScreenshot(
  setId: string,
  file: Awaited<ReturnType<typeof validateScreenshots>>[number],
) {
  const reservation = await ascApi<{ data: Resource<ScreenshotAttributes> }>("/v1/appScreenshots", {
    method: "POST",
    body: {
      data: {
        type: "appScreenshots",
        attributes: { fileName: file.fileName, fileSize: file.fileSize },
        relationships: {
          appScreenshotSet: { data: { type: "appScreenshotSets", id: setId } },
        },
      },
    },
  });

  const screenshotId = reservation.data.id;
  const operations = reservation.data.attributes.uploadOperations ?? [];
  if (operations.length === 0) throw new Error(`${file.fileName}: no upload operations returned`);

  for (const operation of operations) {
    const headers = Object.fromEntries(
      operation.requestHeaders.map(({ name, value }) => [name, value]),
    );
    const part = file.buffer.subarray(operation.offset, operation.offset + operation.length);
    if (part.length !== operation.length) {
      throw new Error(`${file.fileName}: invalid upload range`);
    }
    const response = await fetch(operation.url, {
      method: operation.method,
      headers,
      body: part,
    });
    if (!response.ok) {
      throw new Error(`${file.fileName}: upload failed with ${response.status}`);
    }
  }

  const checksum = createHash("md5").update(file.buffer).digest("hex");
  await ascApi(`/v1/appScreenshots/${screenshotId}`, {
    method: "PATCH",
    body: {
      data: {
        type: "appScreenshots",
        id: screenshotId,
        attributes: { uploaded: true, sourceFileChecksum: checksum },
      },
    },
  });

  const deadline = Date.now() + 180_000;
  while (Date.now() < deadline) {
    const current = await ascApi<{ data: Resource<ScreenshotAttributes> }>(
      `/v1/appScreenshots/${screenshotId}`,
    );
    const delivery = current.data.attributes.assetDeliveryState;
    if (delivery?.state === "COMPLETE") {
      console.log(`  ✓ ${file.fileName} COMPLETE (${screenshotId})`);
      return screenshotId;
    }
    if (delivery?.state === "FAILED") {
      throw new Error(`${file.fileName}: processing failed ${JSON.stringify(delivery.errors ?? [])}`);
    }
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 2_000));
  }
  throw new Error(`${file.fileName}: processing timed out`);
}

async function replaceOrder(setId: string, screenshotIds: string[]) {
  await ascApi(`/v1/appScreenshotSets/${setId}/relationships/appScreenshots`, {
    method: "PATCH",
    body: {
      data: screenshotIds.map((id) => ({ type: "appScreenshots", id })),
    },
  });
}

async function main() {
  const files = await validateScreenshots();
  const version = await findVersion();
  const localization = await findJapaneseLocalization(version.id);
  const sets = await findScreenshotSet(localization.id);
  const existing = sets.target ? (await listScreenshots(sets.target.id)).data : [];

  console.log(
    JSON.stringify(
      {
        appId: APP_ID,
        apply: APPLY,
        displayType: DISPLAY_TYPE,
        expectedDimensions: `${target.width}x${target.height}`,
        existingDisplayTypes: sets.all.map(({ attributes }) => attributes.screenshotDisplayType),
        existingTargetScreenshots: existing.map(({ id, attributes }) => ({
          fileName: attributes.fileName,
          id,
          state: attributes.assetDeliveryState?.state,
        })),
        files: files.map(({ fileName, fileSize, height, width }) => ({
          fileName,
          fileSize,
          height,
          width,
        })),
        locale: localization.attributes.locale,
        replace: REPLACE,
        screenshotDirectory: screenshotDir,
        state: version.attributes.appStoreState,
        version: VERSION,
      },
      null,
      2,
    ),
  );

  if (existing.length + files.length > 10) {
    throw new Error(
      "Uploading before replacement would exceed the 10-screenshot limit. " +
      "Review and run asc:clear-screenshots for this version/display type before uploading.",
    );
  }

  if (!APPLY) {
    console.log("dry-run: no changes applied");
    return;
  }
  if (existing.length > 0 && !REPLACE) {
    throw new Error(`${DISPLAY_TYPE} already contains screenshots; rerun with REPLACE=1`);
  }

  const screenshotSet = sets.target ?? (await createScreenshotSet(localization.id)).data;
  console.log(`→ uploading ${files.length} screenshots to set ${screenshotSet.id}`);

  const uploadedIds: string[] = [];
  for (const file of files) {
    uploadedIds.push(await uploadScreenshot(screenshotSet.id, file));
  }

  for (const old of existing) {
    await ascApi(`/v1/appScreenshots/${old.id}`, { method: "DELETE" });
    console.log(`  ✓ deleted previous screenshot ${old.id}`);
  }
  await replaceOrder(screenshotSet.id, uploadedIds);

  const verified = await listScreenshots(screenshotSet.id);
  const verifiedIds = verified.data.map(({ id }) => id);
  if (JSON.stringify(verifiedIds) !== JSON.stringify(uploadedIds)) {
    throw new Error(`Screenshot order verification failed: ${JSON.stringify(verifiedIds)}`);
  }
  for (const screenshot of verified.data) {
    if (screenshot.attributes.assetDeliveryState?.state !== "COMPLETE") {
      throw new Error(`Screenshot ${screenshot.id} is not complete`);
    }
  }

  console.log(`✓ uploaded and verified ${uploadedIds.length} screenshots for ${VERSION}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
