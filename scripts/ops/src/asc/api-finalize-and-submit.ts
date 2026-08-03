/**
 * App Store version 1.0.3 の最終仕上げと Review 提出：
 *   1. App Store Review Detail (連絡先) を埋める
 *   2. Review Submission を作成
 *   3. Items に appStoreVersion + subscription を追加
 *   4. Submit (state を SUBMITTED に)
 *
 * 実行: DRY_RUN=1 npx tsx src/asc/api-finalize-and-submit.ts
 *      DRY_RUN=0 で本実行
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const NEW_VERSION = process.env.NEW_VERSION ?? "1.0.3";
const MONTHLY_SUB_ID = process.env.ASC_PRODUCT_MONTHLY_SUB_ID ?? "6775457213";
const DRY_RUN = (process.env.DRY_RUN ?? "1") !== "0";

const CONTACT_FIRST = "Akito";
const CONTACT_LAST = "Ando";
const CONTACT_EMAIL = "28ww.lo.ol.ww28@gmail.com";
const CONTACT_PHONE = process.env.CONTACT_PHONE ?? "+81-80-8808-7838";

async function main() {
  // version & review detail id
  const vers = await ascApi<any>(`/v1/apps/${APP_ID}/appStoreVersions`, {
    query: { "filter[versionString]": NEW_VERSION, limit: 1 },
  });
  const ver = vers.data?.[0];
  if (!ver) throw new Error(`version ${NEW_VERSION} not found`);
  const vid = ver.id;
  console.log(`version id=${vid} state=${ver.attributes.appStoreState}`);

  const detail = await ascApi<any>(`/v1/appStoreVersions/${vid}/appStoreReviewDetail`);
  const detailId = detail.data?.id;
  if (!detailId) throw new Error("appStoreReviewDetail id not found");
  console.log(`review detail id=${detailId}`);

  // step 1: PATCH review detail
  const detailPayload = {
    data: {
      type: "appStoreReviewDetails",
      id: detailId,
      attributes: {
        contactFirstName: CONTACT_FIRST,
        contactLastName: CONTACT_LAST,
        contactPhone: CONTACT_PHONE,
        contactEmail: CONTACT_EMAIL,
        demoAccountRequired: false,
        notes:
          "Sign in with Apple required. AI コーチ機能は Premium (Monthly Subscription) でアンロックされます。テスト時は Sandbox Tester アカウントで購入してください。",
      },
    },
  };
  console.log("→ step1 PATCH appStoreReviewDetails");
  if (DRY_RUN) {
    console.log(JSON.stringify(detailPayload, null, 2));
  } else {
    await ascApi(`/v1/appStoreReviewDetails/${detailId}`, {
      method: "PATCH",
      body: detailPayload,
    });
    console.log("  ✓ review detail patched");
  }

  // step 2: create reviewSubmission
  console.log("\n→ step2 POST /v1/reviewSubmissions");
  let submissionId: string | null = null;
  const submissionPayload = {
    data: {
      type: "reviewSubmissions",
      attributes: { platform: "IOS" },
      relationships: { app: { data: { type: "apps", id: APP_ID } } },
    },
  };
  if (DRY_RUN) {
    console.log(JSON.stringify(submissionPayload, null, 2));
  } else {
    const created = await ascApi<any>("/v1/reviewSubmissions", {
      method: "POST",
      body: submissionPayload,
    });
    submissionId = created.data?.id;
    console.log(`  ✓ submission id=${submissionId} state=${created.data?.attributes?.state}`);
  }

  // step 3: add items (appStoreVersion + subscription)
  console.log("\n→ step3 POST /v1/reviewSubmissionItems x2");
  const itemPayloads = [
    {
      data: {
        type: "reviewSubmissionItems",
        relationships: {
          reviewSubmission: {
            data: { type: "reviewSubmissions", id: submissionId ?? "<DRY>" },
          },
          appStoreVersion: { data: { type: "appStoreVersions", id: vid } },
        },
      },
    },
    {
      data: {
        type: "reviewSubmissionItems",
        relationships: {
          reviewSubmission: {
            data: { type: "reviewSubmissions", id: submissionId ?? "<DRY>" },
          },
          subscription: { data: { type: "subscriptions", id: MONTHLY_SUB_ID } },
        },
      },
    },
  ];
  if (DRY_RUN) {
    for (const p of itemPayloads) console.log(JSON.stringify(p, null, 2));
  } else {
    for (const p of itemPayloads) {
      const created = await ascApi<any>("/v1/reviewSubmissionItems", {
        method: "POST",
        body: p,
      });
      const type = Object.keys(p.data.relationships).find((k) => k !== "reviewSubmission");
      console.log(`  ✓ item ${type} id=${created.data?.id}`);
    }
  }

  // step 4: submit (PATCH state)
  console.log("\n→ step4 PATCH /v1/reviewSubmissions/{id} (submitted: true)");
  const submitPayload = {
    data: {
      type: "reviewSubmissions",
      id: submissionId ?? "<DRY>",
      attributes: { submitted: true },
    },
  };
  if (DRY_RUN) {
    console.log(JSON.stringify(submitPayload, null, 2));
    console.log("\n→ DRY_RUN: not submitting");
  } else {
    await ascApi(`/v1/reviewSubmissions/${submissionId}`, {
      method: "PATCH",
      body: submitPayload,
    });
    console.log("  ✓ SUBMITTED");
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
