/**
 * 既存の ja (REJECTED で固着) の代わりに ja_JP を新規追加する試み。
 * 実行: cd scripts/ops && npx tsx src/asc/api-add-ja-jp-loc.ts
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const SUB_ID = process.env.ASC_PRODUCT_MONTHLY_SUB_ID || "6775457213";

const JA_NAME = "プレミアム（月額）";
const JA_DESCRIPTION = "全機能の月額プラン。最初の3日間は無料。";

const candidates = ["ja_JP", "ja-JP", "ja-Hani"];

async function main() {
  for (const locale of candidates) {
    console.log(`\n→ POST locale=${locale}`);
    try {
      await ascApi(`/v1/subscriptionLocalizations`, {
        method: "POST",
        body: {
          data: {
            type: "subscriptionLocalizations",
            attributes: {
              locale,
              name: JA_NAME,
              description: JA_DESCRIPTION,
            },
            relationships: {
              subscription: { data: { type: "subscriptions", id: SUB_ID } },
            },
          },
        },
      });
      console.log(`  ✓ ${locale} created`);
      break;
    } catch (e) {
      console.log(`  ✗ ${(e as Error).message.slice(0, 400)}`);
    }
  }
}

main().catch(console.error);
