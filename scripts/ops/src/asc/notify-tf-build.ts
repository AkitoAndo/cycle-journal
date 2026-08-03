/**
 * 指定の TestFlight build について Internal Tester への通知を発火する。
 *
 * 実行: BUILD_NUMBER=1780809064 npx tsx src/asc/notify-tf-build.ts
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const BUILD_NUMBER = process.env.BUILD_NUMBER;

async function main() {
  if (!BUILD_NUMBER) throw new Error("BUILD_NUMBER is required");

  const builds = await ascApi<{ data: { id: string; attributes: { version: string } }[] }>(
    "/v1/builds",
    {
      query: {
        "filter[app]": APP_ID,
        "filter[version]": BUILD_NUMBER,
        limit: 1,
      },
    },
  );
  const build = builds.data?.[0];
  if (!build) throw new Error(`build ${BUILD_NUMBER} not found`);
  console.log(`build id=${build.id} (build number ${build.attributes.version})`);

  console.log("→ POST /v1/buildBetaNotifications");
  await ascApi("/v1/buildBetaNotifications", {
    method: "POST",
    body: {
      data: {
        type: "buildBetaNotifications",
        relationships: {
          build: { data: { type: "builds", id: build.id } },
        },
      },
    },
  });
  console.log("✓ notification sent to internal testers");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
