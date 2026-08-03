/**
 * ASC REST API で In-App Purchases / Subscriptions の review state を確認。
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";

interface Sub {
  id: string;
  attributes: {
    name?: string;
    productId?: string;
    state?: string;
    reviewNote?: string;
  };
}

async function main() {
  const subs = await ascApi<{ data: Sub[] }>(
    `/v1/apps/${APP_ID}/subscriptionGroups`,
    { query: { include: "subscriptions" } },
  );

  console.log("=== subscriptionGroups ===");
  console.log(JSON.stringify(subs, null, 2).slice(0, 3000));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
