/**
 * 承認済みの App Store version の binary を reject して 編集可能状態に戻す試み。
 * 実行: cd scripts/ops && npx tsx src/asc/api-reject-binary.ts <appStoreVersionId>
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const VERSION_ID = process.argv[2];
if (!VERSION_ID) {
  console.error("usage: api-reject-binary.ts <appStoreVersionId>");
  process.exit(1);
}

async function main() {
  // Try 1: DELETE
  console.log(`→ try DELETE /v1/appStoreVersions/${VERSION_ID}`);
  try {
    await ascApi(`/v1/appStoreVersions/${VERSION_ID}`, { method: "DELETE" });
    console.log("✓ deleted");
    return;
  } catch (e) {
    console.log(`  ✗ ${(e as Error).message.slice(0, 400)}`);
  }
}

main().catch(console.error);
