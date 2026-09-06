"use client";

import { useEffect, useRef, useState } from "react";

const GOOGLE_SCRIPT_ID = "google-identity-services";
const GOOGLE_SCRIPT_SRC = "https://accounts.google.com/gsi/client";
const GOOGLE_LOAD_TIMEOUT_MS = 10_000;

type GoogleStatus = "loading" | "ready" | "error";

interface GoogleWindow extends Window {
  google?: {
    accounts: {
      id: {
        initialize(options: {
          client_id: string;
          ux_mode: "redirect";
          login_uri: string;
        }): void;
        renderButton(
          element: HTMLElement,
          options: {
            theme: "outline";
            size: "large";
            width: number;
            text: "signin_with";
            state: "app" | "admin";
          }
        ): void;
      };
    };
  };
}

const AUTH_ERROR_MESSAGES: Record<string, string> = {
  csrf: "Googleログインの確認情報が一致しませんでした。もう一度お試しください。",
  credential: "Googleからログイン情報を受け取れませんでした。もう一度お試しください。",
  exchange: "GoogleログインをTreowのアカウントへ接続できませんでした。もう一度お試しください。",
  unexpected: "Googleログインを完了できませんでした。もう一度お試しください。"
};

export function GoogleSignInButton({
  clientId,
  destination = "app",
  width = 260
}: {
  clientId: string;
  destination?: "app" | "admin";
  width?: number;
}) {
  const targetRef = useRef<HTMLDivElement>(null);
  const [status, setStatus] = useState<GoogleStatus>("loading");
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const url = new URL(window.location.href);
    const authError = url.searchParams.get("auth_error");
    if (!authError) return;
    setError(AUTH_ERROR_MESSAGES[authError] ?? AUTH_ERROR_MESSAGES.unexpected);
    url.searchParams.delete("auth_error");
    window.history.replaceState({}, "", `${url.pathname}${url.search}${url.hash}`);
  }, []);

  useEffect(() => {
    let active = true;
    let timeoutId: number | null = null;

    const fail = () => {
      if (!active) return;
      setStatus("error");
      setError("Googleログインを読み込めませんでした。通信状態を確認して再試行してください。");
    };

    const render = () => {
      if (!active || !targetRef.current) return;
      const google = (window as GoogleWindow).google;
      if (!google) {
        fail();
        return;
      }
      try {
        targetRef.current.replaceChildren();
        google.accounts.id.initialize({
          client_id: clientId,
          ux_mode: "redirect",
          login_uri: `${window.location.origin}/auth/google/callback`
        });
        google.accounts.id.renderButton(targetRef.current, {
          theme: "outline",
          size: "large",
          width,
          text: "signin_with",
          state: destination
        });
        if (timeoutId !== null) window.clearTimeout(timeoutId);
        setStatus("ready");
      } catch {
        fail();
      }
    };

    setStatus("loading");
    const existing = document.getElementById(GOOGLE_SCRIPT_ID) as HTMLScriptElement | null;
    const script = existing ?? document.createElement("script");
    const handleLoad = () => render();
    const handleError = () => fail();

    script.addEventListener("load", handleLoad);
    script.addEventListener("error", handleError);
    if (!existing) {
      script.id = GOOGLE_SCRIPT_ID;
      script.src = GOOGLE_SCRIPT_SRC;
      script.async = true;
      script.defer = true;
      document.head.appendChild(script);
    }

    if ((window as GoogleWindow).google) render();
    else timeoutId = window.setTimeout(fail, GOOGLE_LOAD_TIMEOUT_MS);

    return () => {
      active = false;
      if (timeoutId !== null) window.clearTimeout(timeoutId);
      script.removeEventListener("load", handleLoad);
      script.removeEventListener("error", handleError);
    };
  }, [attempt, clientId, destination, width]);

  const retry = () => {
    setError(null);
    const script = document.getElementById(GOOGLE_SCRIPT_ID);
    if (!(window as GoogleWindow).google) script?.remove();
    setAttempt((current) => current + 1);
  };

  return (
    <div className="mt-4" aria-busy={status === "loading"}>
      <div ref={targetRef} className="min-h-[44px]" />
      {status === "loading" && (
        <div role="status" aria-live="polite" className="mt-2 text-[12px] text-muted-foreground">
          Googleログインを読み込んでいます…
        </div>
      )}
      {status === "ready" && (
        <div className="mt-2 text-[11px] leading-relaxed text-muted-foreground">
          Googleの安全なログイン画面へ移動します。この画面に戻る必要はありません。
        </div>
      )}
      {error && (
        <div role="alert" className="mt-3 rounded-xl bg-destructive/10 px-3 py-2.5 text-[13px] text-destructive">
          <div>{error}</div>
          <button
            type="button"
            onClick={retry}
            className="mt-2 font-semibold underline underline-offset-2"
          >
            Googleログインを再読み込み
          </button>
        </div>
      )}
    </div>
  );
}
