import { NextRequest, NextResponse } from "next/server";
import { ADMIN_API_BASE_URL, verifyGoogle } from "@/lib/api";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const AUTH_STORAGE_KEY = "cycle.web.auth";

function destinationPath(state: FormDataEntryValue | null): "/" | "/admin" {
  return state === "admin" ? "/admin" : "/";
}

function errorRedirect(
  destination: "/" | "/admin",
  code: "csrf" | "credential" | "exchange" | "unexpected"
) {
  const query = new URLSearchParams({ auth_error: code });
  return new NextResponse(null, {
    status: 303,
    headers: {
      Location: `${destination}?${query.toString()}`,
      "Cache-Control": "no-store, max-age=0"
    }
  });
}

function authHandoffPage(
  accessToken: string,
  refreshToken: string,
  destination: "/" | "/admin"
) {
  const nonce = crypto.randomUUID();
  const authValue = JSON.stringify({ accessToken, refreshToken });
  const script = [
    `window.localStorage.setItem(${JSON.stringify(AUTH_STORAGE_KEY)}, ${JSON.stringify(authValue)});`,
    `window.location.replace(${JSON.stringify(destination)});`
  ].join("\n");

  return new NextResponse(
    `<!doctype html>
<html lang="ja">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Treowにログインしています</title>
  </head>
  <body style="margin:0;display:grid;min-height:100vh;place-items:center;background:#f8f2e5;color:#4f443b;font-family:-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif">
    <main style="padding:24px;text-align:center">
      <h1 style="font-size:20px">Treowにログインしています…</h1>
      <p style="font-size:14px">このまま少しお待ちください。</p>
    </main>
    <script nonce="${nonce}">${script}</script>
  </body>
</html>`,
    {
      status: 200,
      headers: {
        "Cache-Control": "no-store, max-age=0",
        "Content-Security-Policy": `default-src 'none'; script-src 'nonce-${nonce}'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'`,
        "Content-Type": "text/html; charset=utf-8",
        "Referrer-Policy": "no-referrer",
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY"
      }
    }
  );
}

export async function POST(request: NextRequest) {
  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    return errorRedirect("/", "unexpected");
  }

  const destination = destinationPath(form.get("state"));
  const csrfBody = form.get("g_csrf_token");
  const csrfCookies = request.cookies.getAll("g_csrf_token");
  const csrfMatches =
    typeof csrfBody === "string" &&
    csrfCookies.some(({ value }) => value === csrfBody);
  if (!csrfMatches) {
    console.warn("Google auth callback rejected by CSRF validation", {
      csrfCookieCount: csrfCookies.length,
      hasCsrfBody: typeof csrfBody === "string"
    });
    return errorRedirect(destination, "csrf");
  }

  const credential = form.get("credential");
  if (typeof credential !== "string" || !credential) {
    return errorRedirect(destination, "credential");
  }

  try {
    const auth = await verifyGoogle(
      credential,
      destination === "/admin" ? ADMIN_API_BASE_URL : undefined
    );
    if (!auth.accessToken || !auth.refreshToken) {
      return errorRedirect(destination, "exchange");
    }
    return authHandoffPage(auth.accessToken, auth.refreshToken, destination);
  } catch {
    return errorRedirect(destination, "exchange");
  }
}

export function GET() {
  return errorRedirect("/", "credential");
}
