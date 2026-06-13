/**
 * 指定の subscription localization を REST API で削除。
 * 実行: cd scripts/ops && npx tsx src/asc/api-delete-loc.ts <locId>
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const LOC_ID = process.argv[2];
if (!LOC_ID) {
  console.error("usage: api-delete-loc.ts <locId>");
  process.exit(1);
}

async function main() {
  try {
    await ascApi(`/v1/subscriptionLocalizations/${LOC_ID}`, { method: "DELETE" });
    console.log(`✓ deleted ${LOC_ID}`);
  } catch (e) {
    console.log("DELETE error:", (e as Error).message.slice(0, 500));
  }
}

main().catch(console.error);
