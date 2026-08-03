/**
 * App の最新 App Store version 一覧を取得 (state, version string, attached build)。
 * 実行: cd scripts/ops && npx tsx src/asc/api-list-app-versions.ts
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";

interface AppVersion {
  id: string;
  attributes: {
    versionString?: string;
    appStoreState?: string;
    appVersionState?: string;
    releaseType?: string;
    platform?: string;
    createdDate?: string;
  };
  relationships?: {
    build?: { data?: { id: string } };
  };
}

async function main() {
  const versions = await ascApi<{ data: AppVersion[] }>(
    `/v1/apps/${APP_ID}/appStoreVersions`,
    { query: { "fields[appStoreVersions]": "versionString,appStoreState,appVersionState,releaseType,platform,createdDate,build", "include": "build", limit: 10 } },
  );
  for (const v of versions.data) {
    console.log(JSON.stringify({ id: v.id, ...v.attributes, buildId: v.relationships?.build?.data?.id }, null, 2));
  }
}

main().catch(console.error);
