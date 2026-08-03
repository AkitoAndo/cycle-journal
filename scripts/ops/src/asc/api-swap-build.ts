/**
 * App Store version の build relationship を差し替える試み。
 * 承認済み version の binary を 1.0.6 build に差し替えて再 review を発生させる。
 * 実行: cd scripts/ops && npx tsx src/asc/api-swap-build.ts <versionId> <buildId>
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const VERSION_ID = process.argv[2];
const BUILD_ID = process.argv[3];
if (!VERSION_ID || !BUILD_ID) {
  console.error("usage: api-swap-build.ts <versionId> <buildId>");
  process.exit(1);
}

async function main() {
  console.log(`→ PATCH /v1/appStoreVersions/${VERSION_ID}/relationships/build`);
  try {
    await ascApi(`/v1/appStoreVersions/${VERSION_ID}/relationships/build`, {
      method: "PATCH",
      body: {
        data: { type: "builds", id: BUILD_ID },
      },
    });
    console.log("✓ swapped");
  } catch (e) {
    console.log(`✗ ${(e as Error).message.slice(0, 600)}`);
  }
}

main().catch(console.error);
