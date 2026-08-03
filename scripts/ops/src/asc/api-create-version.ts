/**
 * 新しい App Store version を作成する。
 *
 * 環境変数:
 *   NEW_VERSION   作成する versionString (例: 1.0.3)
 *   COPYRIGHT     コピーライト表記 (任意)
 *   DRY_RUN=1     payload 表示のみで作成しない
 *
 * 実行: NEW_VERSION=1.0.3 DRY_RUN=1 npx tsx src/asc/api-create-version.ts
 */
import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

const APP_ID = process.env.ASC_APP_ID ?? "6760911210";
const NEW_VERSION = process.env.NEW_VERSION ?? "1.0.3";
const COPYRIGHT = process.env.COPYRIGHT ?? "© 2026 Akito Ando";
const DRY_RUN = (process.env.DRY_RUN ?? "1") !== "0";

interface VersionResponse {
  data: {
    id: string;
    attributes: {
      versionString: string;
      appStoreState: string;
      platform: string;
      createdDate: string;
    };
  };
}

async function main() {
  const payload = {
    data: {
      type: "appStoreVersions",
      attributes: {
        versionString: NEW_VERSION,
        platform: "IOS",
        copyright: COPYRIGHT,
      },
      relationships: {
        app: { data: { type: "apps", id: APP_ID } },
      },
    },
  };

  console.log(`→ create App Store version ${NEW_VERSION} (DRY_RUN=${DRY_RUN ? "1" : "0"})`);
  console.log(JSON.stringify(payload, null, 2));

  if (DRY_RUN) {
    console.log("→ DRY_RUN: not creating");
    return;
  }

  const res = await fetch("https://api.appstoreconnect.apple.com/v1/appStoreVersions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${await import("../lib/asc-api.js").then(async (m) => {
        // private helper not exported; mimic by calling ascApi indirectly
        // 代わりに ascApi の path 経由 POST を別途実装する必要があるが、
        // ここはシンプルに fetch を直接書く。
        const { execSync } = await import("node:child_process");
        const keyId = execSync(
          "gcloud secrets versions access latest --secret=app-store-connect-key-id --project=cycle-journal 2>/dev/null",
        )
          .toString()
          .trim();
        const issuerId = execSync(
          "gcloud secrets versions access latest --secret=app-store-connect-issuer-id --project=cycle-journal 2>/dev/null",
        )
          .toString()
          .trim();
        const p8 = execSync(
          "gcloud secrets versions access latest --secret=app-store-connect-api-key --project=cycle-journal 2>/dev/null",
        ).toString();
        const jose = await import("jose");
        const pk = await jose.importPKCS8(p8, "ES256");
        return await new jose.SignJWT({})
          .setProtectedHeader({ alg: "ES256", kid: keyId, typ: "JWT" })
          .setIssuer(issuerId)
          .setIssuedAt()
          .setExpirationTime(Math.floor(Date.now() / 1000) + 1140)
          .setAudience("appstoreconnect-v1")
          .sign(pk);
      })}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    console.error(`✗ ${res.status} ${await res.text()}`);
    process.exit(1);
  }
  const body = (await res.json()) as VersionResponse;
  console.log(`✓ created version id=${body.data.id} state=${body.data.attributes.appStoreState}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
