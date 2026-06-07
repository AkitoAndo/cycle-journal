/**
 * App Store Connect REST API クライアント。
 * Secret Manager から API Key を取得し ES256 JWT を生成して fetch する。
 *
 * 必要な Secrets (project=cycle-journal):
 *   app-store-connect-api-key     ← .p8 PEM
 *   app-store-connect-key-id
 *   app-store-connect-issuer-id
 */
import { execSync } from "node:child_process";
import * as jose from "jose";

const GCP_PROJECT = process.env.GCP_PROJECT ?? "cycle-journal";

let cachedJwt: { token: string; exp: number } | null = null;

function fetchSecret(name: string): string {
  return execSync(
    `gcloud secrets versions access latest --secret=${name} --project=${GCP_PROJECT} 2>/dev/null`,
  )
    .toString()
    .trim();
}

async function buildJwt(): Promise<string> {
  if (cachedJwt && cachedJwt.exp > Date.now() / 1000 + 60) {
    return cachedJwt.token;
  }
  const keyId = fetchSecret("app-store-connect-key-id");
  const issuerId = fetchSecret("app-store-connect-issuer-id");
  const p8 = fetchSecret("app-store-connect-api-key");

  const privateKey = await jose.importPKCS8(p8, "ES256");
  const exp = Math.floor(Date.now() / 1000) + 1140; // 19m, ASC は max 20m
  const token = await new jose.SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId, typ: "JWT" })
    .setIssuer(issuerId)
    .setIssuedAt()
    .setExpirationTime(exp)
    .setAudience("appstoreconnect-v1")
    .sign(privateKey);
  cachedJwt = { token, exp };
  return token;
}

export interface AscApiOptions {
  query?: Record<string, string | number | string[]>;
}

export async function ascApi<T>(path: string, opts: AscApiOptions = {}): Promise<T> {
  const url = new URL(`https://api.appstoreconnect.apple.com${path}`);
  for (const [k, v] of Object.entries(opts.query ?? {})) {
    if (Array.isArray(v)) {
      v.forEach((s) => url.searchParams.append(k, s));
    } else {
      url.searchParams.append(k, String(v));
    }
  }
  const token = await buildJwt();
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`ASC API ${res.status} ${path}: ${body.slice(0, 500)}`);
  }
  return (await res.json()) as T;
}
