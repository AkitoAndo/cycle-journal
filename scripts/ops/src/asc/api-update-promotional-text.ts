/**
 * 公開中バージョンの日本語プロモーションテキストを更新する。
 *
 * デフォルトはdry-run。実際に更新する場合だけ APPLY=1 を指定する。
 *
 * 実行:
 *   APP_STORE_VERSION=1.0.10 npx tsx src/asc/api-update-promotional-text.ts
 *   APP_STORE_VERSION=1.0.10 APPLY=1 npx tsx src/asc/api-update-promotional-text.ts
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const VERSION = process.env.APP_STORE_VERSION ?? "1.0.10";
const APPLY = process.env.APPLY === "1";
const PROMOTIONAL_TEXT =
  "書く、話す、動く、振り返る。モヤモヤした頭を、ひとつの循環で整える。Treowは通常有料のサービスです。現在は期間限定で、すべての機能を無料で利用できます。";

type Resource<T> = {
  id: string;
  attributes: T;
};

type VersionAttributes = {
  appStoreState: string;
  platform: string;
  versionString: string;
};

type LocalizationAttributes = {
  description?: string;
  locale: string;
  promotionalText?: string;
};

async function main() {
  const versions = await ascApi<{ data: Resource<VersionAttributes>[] }>(
    `/v1/apps/${APP_ID}/appStoreVersions`,
    {
      query: {
        "filter[platform]": "IOS",
        "filter[versionString]": VERSION,
        limit: 1,
      },
    },
  );
  const version = versions.data?.[0];
  if (!version) throw new Error(`App Store version ${VERSION} not found`);

  const localizations = await ascApi<{ data: Resource<LocalizationAttributes>[] }>(
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`,
  );
  const ja = localizations.data.find((item) => item.attributes.locale === "ja");
  if (!ja) throw new Error(`Japanese localization for ${VERSION} not found`);

  console.log(
    JSON.stringify(
      {
        apply: APPLY,
        locale: ja.attributes.locale,
        nextPromotionalText: PROMOTIONAL_TEXT,
        previousPromotionalText: ja.attributes.promotionalText ?? "",
        state: version.attributes.appStoreState,
        version: version.attributes.versionString,
      },
      null,
      2,
    ),
  );

  if (!APPLY) {
    console.log("dry-run: no changes applied");
    return;
  }

  await ascApi(`/v1/appStoreVersionLocalizations/${ja.id}`, {
    method: "PATCH",
    body: {
      data: {
        type: "appStoreVersionLocalizations",
        id: ja.id,
        attributes: { promotionalText: PROMOTIONAL_TEXT },
      },
    },
  });

  const updated = await ascApi<{ data: Resource<LocalizationAttributes> }>(
    `/v1/appStoreVersionLocalizations/${ja.id}`,
  );
  if (updated.data.attributes.promotionalText !== PROMOTIONAL_TEXT) {
    throw new Error("Promotional text verification failed");
  }
  console.log("updated and verified");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
