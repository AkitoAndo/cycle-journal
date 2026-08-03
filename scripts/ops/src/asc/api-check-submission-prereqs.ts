/**
 * App Store version 1.0.3 の submission 前提条件チェック。
 * 1.0 から流用できるもの、追加で設定すべきものを洗い出す。
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const NEW_VERSION = process.env.NEW_VERSION ?? "1.0.3";

async function main() {
  const vers = await ascApi<any>(`/v1/apps/${APP_ID}/appStoreVersions`, {
    query: { "filter[versionString]": NEW_VERSION, limit: 1 },
  });
  const ver = vers.data?.[0];
  if (!ver) throw new Error(`version ${NEW_VERSION} not found`);
  const vid = ver.id;
  console.log(`version id=${vid} state=${ver.attributes.appStoreState}\n`);

  // age rating
  const ar = await ascApi<any>(`/v1/appStoreVersions/${vid}/ageRatingDeclaration`).catch(
    (e) => ({ error: String(e) }),
  );
  console.log("=== ageRatingDeclaration ===");
  console.log(JSON.stringify(ar?.data ?? ar, null, 2).slice(0, 800));

  // app-level age rating (新しい API)
  const appAr = await ascApi<any>(`/v1/apps/${APP_ID}/appInfos?limit=5`).catch(
    (e) => ({ error: String(e) }),
  );
  console.log("\n=== appInfos (first) ===");
  console.log(
    JSON.stringify(appAr?.data?.[0]?.attributes ?? appAr?.data?.[0] ?? appAr, null, 2).slice(0, 800),
  );

  // App Review information
  const ari = await ascApi<any>(`/v1/appStoreVersions/${vid}/appStoreReviewDetail`).catch(
    (e) => ({ error: String(e) }),
  );
  console.log("\n=== appStoreReviewDetail ===");
  console.log(JSON.stringify(ari?.data ?? ari, null, 2).slice(0, 800));

  // screenshots（appScreenshotSets を持つか）
  const localizations = await ascApi<any>(
    `/v1/appStoreVersions/${vid}/appStoreVersionLocalizations`,
  );
  const ja = localizations.data?.find((l: any) => l.attributes?.locale === "ja");
  if (ja) {
    const screens = await ascApi<any>(
      `/v1/appStoreVersionLocalizations/${ja.id}/appScreenshotSets`,
    ).catch((e) => ({ error: String(e) }));
    console.log("\n=== screenshots (ja) ===");
    console.log(
      `count=${(screens?.data ?? []).length} ${JSON.stringify(
        (screens?.data ?? []).map((s: any) => ({ id: s.id, type: s.attributes?.screenshotDisplayType })),
      ).slice(0, 500)}`,
    );
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
