/**
 * 既に作成された reviewSubmission を submit する（subscription item を含めずに）。
 *
 * 実行: SUBMISSION_ID=... DRY_RUN=0 npx tsx src/asc/api-submit-existing.ts
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const SUBMISSION_ID = process.env.SUBMISSION_ID;
const DRY_RUN = (process.env.DRY_RUN ?? "1") !== "0";

async function main() {
  if (!SUBMISSION_ID) throw new Error("SUBMISSION_ID is required");

  // 現状確認
  const cur = await ascApi<any>(`/v1/reviewSubmissions/${SUBMISSION_ID}`, {
    query: { include: "items" },
  });
  console.log(`submission state=${cur.data?.attributes?.state}`);
  console.log("items:", (cur.included ?? []).map((i: any) => i.type));

  if (DRY_RUN) {
    console.log("→ DRY_RUN: not submitting");
    return;
  }

  console.log("→ PATCH submitted=true");
  await ascApi(`/v1/reviewSubmissions/${SUBMISSION_ID}`, {
    method: "PATCH",
    body: {
      data: {
        type: "reviewSubmissions",
        id: SUBMISSION_ID,
        attributes: { submitted: true },
      },
    },
  });
  const after = await ascApi<any>(`/v1/reviewSubmissions/${SUBMISSION_ID}`);
  console.log(`✓ state=${after.data?.attributes?.state} submittedDate=${after.data?.attributes?.submittedDate}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
