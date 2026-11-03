/**
 * App Store Connect の編集可能バージョンへ、処理済みのビルドを紐付ける。
 *
 * デフォルトはdry-run。
 * 実行:
 *   APP_STORE_VERSION=1.0.11 BUILD_NUMBER=1789344790 npm run asc:attach-build
 *   APP_STORE_VERSION=1.0.11 BUILD_NUMBER=1789344790 APPLY=1 npm run asc:attach-build
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const VERSION = process.env.APP_STORE_VERSION ?? "1.0.11";
const BUILD_NUMBER = process.env.BUILD_NUMBER;
const APPLY = process.env.APPLY === "1";
const editableStates = new Set(["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"]);

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
  if (!editableStates.has(version.attributes.appStoreState)) {
    throw new Error(`Version ${VERSION} is not editable: ${version.attributes.appStoreState}`);
  }
  if (version.attributes?.releaseType !== "AFTER_APPROVAL") {
    throw new Error(`Automatic release is not enabled: ${version.attributes?.releaseType}`);
  }

  const builds = await ascApi<any>("/v1/builds", {
    query: {
      "filter[app]": APP_ID,
      "filter[version]": BUILD_NUMBER,
      include: "preReleaseVersion",
      limit: 2,
    },
  });
  if (builds.data?.length !== 1) {
    throw new Error(`Expected one build ${BUILD_NUMBER}, found ${builds.data?.length ?? 0}`);
  }
  const build = builds.data[0];
  if (build.attributes?.processingState !== "VALID") {
    throw new Error(`Build ${BUILD_NUMBER} is not VALID: ${build.attributes?.processingState}`);
  }
  if (build.attributes?.version !== BUILD_NUMBER) {
    throw new Error(`Unexpected build number: ${build.attributes?.version}`);
  }
  if (build.attributes?.expired) throw new Error(`Build ${BUILD_NUMBER} is expired`);
  if (build.attributes?.usesNonExemptEncryption !== false) {
    throw new Error(
      `Build encryption declaration is not exempt: ${build.attributes?.usesNonExemptEncryption}`,
    );
  }

  const preReleaseId = build.relationships?.preReleaseVersion?.data?.id;
  const preRelease = builds.included?.find((candidate: any) => candidate.id === preReleaseId);
  if (preRelease?.attributes?.version !== VERSION) {
    throw new Error(
      `Build ${BUILD_NUMBER} belongs to version ${preRelease?.attributes?.version ?? "unknown"}`,
    );
  }
  if (preRelease?.attributes?.platform !== "IOS") {
    throw new Error(`Build ${BUILD_NUMBER} is not an iOS build: ${preRelease?.attributes?.platform}`);
  }

  const current = await ascApi<any>(
    `/v1/appStoreVersions/${version.id}/relationships/build`,
  );
  const currentBuildId = current.data?.id ?? null;
  console.log(JSON.stringify({
    appId: APP_ID,
    apply: APPLY,
    buildId: build.id,
    buildNumber: BUILD_NUMBER,
    currentBuildId,
    processingState: build.attributes.processingState,
    releaseType: version.attributes.releaseType,
    state: version.attributes.appStoreState,
    version: VERSION,
  }, null, 2));

  if (!APPLY) {
    console.log("dry-run: no changes applied");
    return;
  }
  if (currentBuildId && currentBuildId !== build.id) {
    throw new Error(`Version ${VERSION} already has a different build: ${currentBuildId}`);
  }
  if (currentBuildId === build.id) {
    console.log(`✓ build ${BUILD_NUMBER} is already attached to ${VERSION}`);
    return;
  }

  await ascApi(`/v1/appStoreVersions/${version.id}/relationships/build`, {
    method: "PATCH",
    body: { data: { type: "builds", id: build.id } },
  });
  const verified = await ascApi<any>(`/v1/appStoreVersions/${version.id}/build`);
  if (verified.data?.id !== build.id || verified.data?.attributes?.version !== BUILD_NUMBER) {
    throw new Error("Build relationship verification failed");
  }
  console.log(`✓ attached and verified build ${BUILD_NUMBER} for ${VERSION}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
