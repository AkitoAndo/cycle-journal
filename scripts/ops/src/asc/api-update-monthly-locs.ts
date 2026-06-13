/**
 * monthly subscription のローカライゼーションを新トライアル方針 (3日間無料 Intro Offer) に合わせて更新する。
 *
 * - ja: 既存 (REJECTED) を PATCH で更新
 * - en-US: 新規追加
 *
 * 実行: cd scripts/ops && npx tsx src/asc/api-update-monthly-locs.ts
 *   DRY_RUN=1 で実際の更新をスキップ
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const SUB_ID = process.env.ASC_PRODUCT_MONTHLY_SUB_ID || "6775457213";
const DRY_RUN = process.env.DRY_RUN === "1";

interface Loc {
  id: string;
  attributes: {
    locale?: string;
    name?: string;
    description?: string;
    state?: string;
  };
}

// 新トライアル方針に合わせた説明文。
// subscription localization の description は ~45 chars (Apple guideline) に収める。
// 価格は description には書かず、Apple が表示する localized price に任せる。
const JA_NAME = "プレミアム（月額）";
const JA_DESCRIPTION = "全機能の月額プラン。最初の3日間は無料。";

const EN_NAME = "Premium (Monthly)";
const EN_DESCRIPTION = "All Premium features. 3-day free trial included.";

async function main() {
  console.log(`DRY_RUN=${DRY_RUN}`);

  const locsResp = await ascApi<{ data: Loc[] }>(
    `/v1/subscriptions/${SUB_ID}/subscriptionLocalizations`,
    {},
  );
  const ja = locsResp.data.find((l) => l.attributes.locale === "ja");
  const en = locsResp.data.find((l) => l.attributes.locale === "en-US");

  // 順序重要: REJECTED な ja は直接編集も「最後の1つ」状態での削除も不可。
  // 先に en-US を POST してから ja を DELETE → POST し直す。
  // en-US: POST 新規 (or PATCH if exists)
  if (en) {
    console.log(`\n→ PATCH en-US (id=${en.id}, state=${en.attributes.state})`);
    console.log(`  name: ${EN_NAME}`);
    console.log(`  description: ${EN_DESCRIPTION}`);
    if (!DRY_RUN) {
      await ascApi(`/v1/subscriptionLocalizations/${en.id}`, {
        method: "PATCH",
        body: {
          data: {
            type: "subscriptionLocalizations",
            id: en.id,
            attributes: { name: EN_NAME, description: EN_DESCRIPTION },
          },
        },
      });
      console.log("  ✓ updated");
    }
  } else {
    console.log(`\n→ POST en-US`);
    console.log(`  name: ${EN_NAME}`);
    console.log(`  description: ${EN_DESCRIPTION}`);
    if (!DRY_RUN) {
      await ascApi(`/v1/subscriptionLocalizations`, {
        method: "POST",
        body: {
          data: {
            type: "subscriptionLocalizations",
            attributes: {
              locale: "en-US",
              name: EN_NAME,
              description: EN_DESCRIPTION,
            },
            relationships: {
              subscription: { data: { type: "subscriptions", id: SUB_ID } },
            },
          },
        },
      });
      console.log("  ✓ created");
    }
  }

  // ja: REJECTED は直接編集不可 (ASC API 409 ENTITY_ERROR.ATTRIBUTE.INVALID.UNMODIFIABLE)。
  // DELETE → POST で作り直す。それ以外の状態は PATCH。
  if (ja) {
    if (ja.attributes.state === "REJECTED") {
      console.log(`\n→ DELETE ja (id=${ja.id}, state=REJECTED)`);
      if (!DRY_RUN) {
        await ascApi(`/v1/subscriptionLocalizations/${ja.id}`, { method: "DELETE" });
        console.log("  ✓ deleted");
      }
      console.log(`→ POST ja (new)`);
      console.log(`  name: ${JA_NAME}`);
      console.log(`  description: ${JA_DESCRIPTION}`);
      if (!DRY_RUN) {
        await ascApi(`/v1/subscriptionLocalizations`, {
          method: "POST",
          body: {
            data: {
              type: "subscriptionLocalizations",
              attributes: {
                locale: "ja",
                name: JA_NAME,
                description: JA_DESCRIPTION,
              },
              relationships: {
                subscription: { data: { type: "subscriptions", id: SUB_ID } },
              },
            },
          },
        });
        console.log("  ✓ created");
      }
    } else {
      console.log(`\n→ PATCH ja (id=${ja.id}, state=${ja.attributes.state})`);
      console.log(`  name: ${JA_NAME}`);
      console.log(`  description: ${JA_DESCRIPTION}`);
      if (!DRY_RUN) {
        await ascApi(`/v1/subscriptionLocalizations/${ja.id}`, {
          method: "PATCH",
          body: {
            data: {
              type: "subscriptionLocalizations",
              id: ja.id,
              attributes: {
                name: JA_NAME,
                description: JA_DESCRIPTION,
              },
            },
          },
        });
        console.log("  ✓ updated");
      }
    }
  } else {
    console.log("\n(no ja localization found — will create)");
    if (!DRY_RUN) {
      await ascApi(`/v1/subscriptionLocalizations`, {
        method: "POST",
        body: {
          data: {
            type: "subscriptionLocalizations",
            attributes: {
              locale: "ja",
              name: JA_NAME,
              description: JA_DESCRIPTION,
            },
            relationships: {
              subscription: {
                data: { type: "subscriptions", id: SUB_ID },
              },
            },
          },
        },
      });
      console.log("  ✓ created");
    }
  }

  // 結果確認
  console.log("\n--- final state ---");
  const finalLocs = await ascApi<{ data: Loc[] }>(
    `/v1/subscriptions/${SUB_ID}/subscriptionLocalizations`,
    {},
  );
  console.log(JSON.stringify(finalLocs.data.map((d) => ({ id: d.id, ...d.attributes })), null, 2));

  const sub = await ascApi<{ data: { attributes: Record<string, unknown> } }>(
    `/v1/subscriptions/${SUB_ID}`,
    {},
  );
  console.log(`\nsubscription state: ${sub.data.attributes.state}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
