/**
 * App Store version (PREPARE_FOR_SUBMISSION) の準備を進める：
 *   1. build を assign
 *   2. whatsNew を localizations に追加
 *
 * age rating と subscription bundling と submission は別スクリプト/Web UI で。
 *
 * 実行: NEW_VERSION=1.0.3 BUILD_NUMBER=1780796272 npx tsx src/asc/api-prepare-submission.ts
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const NEW_VERSION = process.env.NEW_VERSION ?? "1.0.3";
const BUILD_NUMBER = process.env.BUILD_NUMBER ?? "1780796272";
const WHATS_NEW_JA = process.env.WHATS_NEW_JA ?? [
  "- 月額プランに3日間の無料トライアルを追加しました",
  "- 設定画面から「Treow Premium」へアップグレードできるようになりました",
  "- 利用規約とプライバシーポリシーを最新化しました",
  "- AIコーチの応答エンジンを更新し、安定性を改善しました",
  "- タスクリストの表示エラーを修正しました",
].join("\n");

async function main() {
  // 1. find version
  const vers = await ascApi<any>(`/v1/apps/${APP_ID}/appStoreVersions`, {
    query: { "filter[versionString]": NEW_VERSION, limit: 1 },
  });
  const ver = vers.data?.[0];
  if (!ver) throw new Error(`version ${NEW_VERSION} not found`);
  console.log(`version id=${ver.id} state=${ver.attributes.appStoreState}`);

  // 2. find build id
  const builds = await ascApi<any>(`/v1/builds`, {
    query: {
      "filter[app]": APP_ID,
      "filter[version]": BUILD_NUMBER,
      limit: 1,
    },
  });
  const build = builds.data?.[0];
  if (!build) throw new Error(`build ${BUILD_NUMBER} not found`);
  console.log(`build id=${build.id} state=${build.attributes.processingState}`);

  // 3. assign build to version
  console.log("→ assign build to version");
  await ascApi(`/v1/appStoreVersions/${ver.id}/relationships/build`, {
    method: "PATCH",
    body: { data: { type: "builds", id: build.id } },
  });
  console.log("  ✓ assigned");

  // 4. find ja localization
  const locs = await ascApi<any>(`/v1/appStoreVersions/${ver.id}/appStoreVersionLocalizations`);
  const ja = locs.data?.find((l: any) => l.attributes?.locale === "ja");
  if (!ja) throw new Error("ja localization not found");
  console.log(`ja localization id=${ja.id}`);

  // 5. set whatsNew
  console.log("→ set whatsNew (ja)");
  await ascApi(`/v1/appStoreVersionLocalizations/${ja.id}`, {
    method: "PATCH",
    body: {
      data: {
        type: "appStoreVersionLocalizations",
        id: ja.id,
        attributes: { whatsNew: WHATS_NEW_JA },
      },
    },
  });
  console.log("  ✓ whatsNew set");

  console.log("\n✓ prepare-submission done. next: age rating, IAP bundling, submission");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
