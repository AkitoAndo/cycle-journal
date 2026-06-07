/**
 * ASC REST API で直近 builds の processingState を一覧。
 *
 * 実行:
 *   npx tsx src/asc/api-list-builds.ts
 *   TARGET_VERSION=1.0.3 npx tsx src/asc/api-list-builds.ts  ← 特定 version のみ
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const TARGET_VERSION = process.env.TARGET_VERSION;

interface BuildRow {
  id: string;
  attributes: {
    version: string;
    uploadedDate: string;
    processingState: string;
    expired: boolean;
  };
  relationships: {
    preReleaseVersion?: {
      data?: { id: string; type: string };
    };
  };
}

interface PreReleaseVersion {
  id: string;
  attributes: { version: string; platform: string };
}

async function main() {
  const builds = await ascApi<{ data: BuildRow[]; included?: PreReleaseVersion[] }>(
    "/v1/builds",
    {
      query: {
        "filter[app]": APP_ID,
        sort: "-uploadedDate",
        limit: 20,
        include: "preReleaseVersion",
      },
    },
  );

  const preVersions = new Map<string, string>();
  for (const inc of builds.included ?? []) {
    preVersions.set(inc.id, inc.attributes.version);
  }

  let rows = builds.data.map((b) => {
    const preId = b.relationships.preReleaseVersion?.data?.id;
    const releaseVersion = preId ? preVersions.get(preId) ?? "?" : "?";
    return {
      releaseVersion,
      buildNumber: b.attributes.version,
      state: b.attributes.processingState,
      expired: b.attributes.expired,
      uploadedAt: b.attributes.uploadedDate,
    };
  });

  if (TARGET_VERSION) {
    rows = rows.filter((r) => r.releaseVersion === TARGET_VERSION);
  }

  console.log(
    rows
      .map(
        (r) =>
          `${r.releaseVersion.padEnd(8)} build=${r.buildNumber.padEnd(4)} ` +
          `state=${r.state.padEnd(12)} expired=${r.expired} ${r.uploadedAt}`,
      )
      .join("\n"),
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
