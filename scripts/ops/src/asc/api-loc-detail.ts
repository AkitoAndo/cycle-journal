/**
 * subscription の各ローカライゼーション詳細 (id, rejection 情報含む) を確認する。
 * 実行: cd scripts/ops && npx tsx src/asc/api-loc-detail.ts <subscriptionId>
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const SUB_ID = process.argv[2] || process.env.ASC_PRODUCT_MONTHLY_SUB_ID || "6775457213";

interface Loc {
  id: string;
  attributes: Record<string, unknown>;
}

async function main() {
  const locs = await ascApi<{ data: Loc[] }>(
    `/v1/subscriptions/${SUB_ID}/subscriptionLocalizations`,
    {},
  );
  for (const loc of locs.data) {
    console.log(`\n=== ${loc.id} (${loc.attributes.locale}) ===`);
    console.log(JSON.stringify(loc.attributes, null, 2));

    // /v1/subscriptionLocalizations/{id} で詳細 (sometimes contains additional fields)
    try {
      const detail = await ascApi<{ data: Loc }>(`/v1/subscriptionLocalizations/${loc.id}`, {});
      console.log("--- detail ---");
      console.log(JSON.stringify(detail.data.attributes, null, 2));
    } catch (e) {
      console.log("(failed to fetch detail)", (e as Error).message.slice(0, 200));
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
