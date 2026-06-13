/**
 * monthly/yearly subscription の詳細状態 (localizations, screenshot, prices, intro offers) を確認する。
 * 実行: cd scripts/ops && npx tsx src/asc/api-sub-detail.ts <subscriptionId>
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const SUB_ID = process.argv[2] || process.env.ASC_PRODUCT_MONTHLY_SUB_ID || "6775457213";

async function main() {
  console.log(`=== subscription ${SUB_ID} ===`);

  const sub = await ascApi<{ data: { attributes: Record<string, unknown> } }>(
    `/v1/subscriptions/${SUB_ID}`,
    {},
  );
  console.log("\n--- attributes ---");
  console.log(JSON.stringify(sub.data.attributes, null, 2));

  const locs = await ascApi<{ data: { attributes: Record<string, unknown> }[] }>(
    `/v1/subscriptions/${SUB_ID}/subscriptionLocalizations`,
    {},
  );
  console.log(`\n--- localizations (${locs.data.length}) ---`);
  console.log(JSON.stringify(locs.data.map((d) => d.attributes), null, 2));

  const screenshots = await ascApi<{ data: unknown[] }>(
    `/v1/subscriptions/${SUB_ID}/appStoreReviewScreenshot`,
    {},
  ).catch(() => ({ data: [] }));
  console.log(`\n--- screenshot ---`);
  console.log(JSON.stringify(screenshots, null, 2));

  const prices = await ascApi<{ data: unknown[] }>(
    `/v1/subscriptions/${SUB_ID}/prices`,
    {},
  ).catch(() => ({ data: [] }));
  console.log(`\n--- prices count: ${(prices as { data: unknown[] }).data.length} ---`);

  const introOffers = await ascApi<{ data: unknown[] }>(
    `/v1/subscriptions/${SUB_ID}/introductoryOffers`,
    {},
  ).catch(() => ({ data: [] }));
  console.log(`\n--- intro offers count: ${(introOffers as { data: unknown[] }).data.length} ---`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
