import type { AuthTokens, JournalEntry } from "@/types/api";

const AUTH_KEY = "cycle.web.auth";
const JOURNAL_KEY = "cycle.web.journals";

export function loadAuth(): AuthTokens | null {
  if (typeof window === "undefined") return null;
  const raw = window.localStorage.getItem(AUTH_KEY);
  return raw ? (JSON.parse(raw) as AuthTokens) : null;
}

export function saveAuth(tokens: AuthTokens | null): void {
  if (typeof window === "undefined") return;
  if (tokens) window.localStorage.setItem(AUTH_KEY, JSON.stringify(tokens));
  else window.localStorage.removeItem(AUTH_KEY);
}

export function loadJournals(): JournalEntry[] {
  if (typeof window === "undefined") return [];
  const raw = window.localStorage.getItem(JOURNAL_KEY);
  return raw ? (JSON.parse(raw) as JournalEntry[]) : [];
}

export function saveJournals(entries: JournalEntry[]): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(JOURNAL_KEY, JSON.stringify(entries));
}
