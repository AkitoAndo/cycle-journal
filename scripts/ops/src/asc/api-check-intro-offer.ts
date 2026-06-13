/**
 * Monthly subscription の Introductory Offer 設定を REST API で確認する。
 * 実行: cd scripts/ops && npx tsx src/asc/api-check-intro-offer.ts
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const SUB_ID = process.env.ASC_PRODUCT_MONTHLY_SUB_ID || "6775457213";

interface IntroOffer {
  id: string;
  attributes: {
    startDate?: string;
    endDate?: string;
    duration?: string;
    offerMode?: string;
    territoryCodes?: string[] | null;
  };
}

async function main() {
  const offers = await ascApi<{ data: IntroOffer[] }>(
    `/v1/subscriptions/${SUB_ID}/introductoryOffers`,
    {},
  );
  console.log(`=== introductory offers for subscription ${SUB_ID} ===`);
  console.log(JSON.stringify(offers, null, 2));
  if ((offers.data ?? []).length === 0) {
    console.log("(no intro offers configured)");
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
