import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

async function main() {
  try {
    await ascApi(`/v1/subscriptionLocalizations`, {
      method: "POST",
      body: {
        data: {
          type: "subscriptionLocalizations",
          attributes: {
            locale: "ja",
            name: "プレミアム（月額）",
            description: "全機能の月額プラン。最初の3日間は無料。",
          },
          relationships: {
            subscription: { data: { type: "subscriptions", id: "6775457213" } },
          },
        },
      },
    });
    console.log("✓ duplicate ja created");
  } catch (e) {
    console.log((e as Error).message.slice(0, 800));
  }
}

main();
