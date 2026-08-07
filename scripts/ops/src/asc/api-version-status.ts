/**
 * ASC REST API で App Store version の状態を確認。
 * - 最新の version とその state
 * - 紐付いている build
 * - 紐付いている IAP (subscriptions)
 * - 不足メタデータ (screenshots, description 等)
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";

async function main() {
  const versions = await ascApi<any>(`/v1/apps/${APP_ID}/appStoreVersions`, {
    query: { limit: 10, "fields[appStoreVersions]": "versionString,appStoreState,createdDate,platform" },
  });
  console.log("=== App Store versions ===");
  for (const v of versions.data ?? []) {
    console.log(
      `id=${v.id} version=${v.attributes.versionString} ` +
        `state=${v.attributes.appStoreState} platform=${v.attributes.platform} ` +
        `created=${v.attributes.createdDate}`,
    );
  }

  const latest = (versions.data ?? [])[0];
  if (!latest) {
    console.log("→ no App Store versions");
    return;
  }
  const vid = latest.id;
  console.log(`\n=== latest (${vid}) details ===`);

  // build 紐付け
  const buildRel = await ascApi<any>(`/v1/appStoreVersions/${vid}/build`).catch((e) => ({
    error: String(e),
  }));
  console.log("build:", JSON.stringify(buildRel?.data?.attributes ?? buildRel, null, 2).slice(0, 500));

  // localizations (description / keywords)
  const locs = await ascApi<any>(`/v1/appStoreVersions/${vid}/appStoreVersionLocalizations`).catch(
    (e) => ({ error: String(e) }),
  );
  console.log("\nlocalizations:");
  for (const l of locs.data ?? []) {
    const a = l.attributes ?? {};
    console.log(
      `  locale=${a.locale} desc=${a.description ? "yes" : "no"} keywords=${a.keywords ? "yes" : "no"} promo=${a.promotionalText ? "yes" : "no"} whatsnew=${a.whatsNew ? "yes" : "no"}`,
    );
  }

  // age rating
  const ageRating = await ascApi<any>(`/v1/appStoreVersions/${vid}/ageRatingDeclaration`).catch(
    () => null,
  );
  console.log(
    "\nageRating:",
    ageRating?.data?.id ? "set" : "missing",
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
