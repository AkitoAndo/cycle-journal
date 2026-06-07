/**
 * App Store Connect REST API クライアント。GET / POST / PATCH に対応。
 * Secret Manager の API Key で ES256 JWT を生成。
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
  const exp = Math.floor(Date.now() / 1000) + 1140;
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
  method?: "GET" | "POST" | "PATCH" | "DELETE";
  body?: unknown;
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
  const headers: Record<string, string> = {
    Authorization: `Bearer ${token}`,
    Accept: "application/json",
  };
  let bodyStr: string | undefined;
  if (opts.body !== undefined) {
    headers["Content-Type"] = "application/json";
    bodyStr = JSON.stringify(opts.body);
  }
  const res = await fetch(url, {
    method: opts.method ?? "GET",
    headers,
    body: bodyStr,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`ASC API ${res.status} ${opts.method ?? "GET"} ${path}: ${text.slice(0, 1000)}`);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}
