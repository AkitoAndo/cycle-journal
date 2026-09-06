import type {
  AuthTokens,
  JournalEntry,
  MeditationLog,
  ScheduleEvent,
  TaskLocalDetails,
  TaskTemplate,
  WebPreferences
} from "@/types/api";

const AUTH_KEY = "cycle.web.auth";
const JOURNAL_KEY = "cycle.web.journals";
const JOURNAL_DRAFT_KEY = "cycle.web.journal-draft";
const JOURNAL_LAST_SYNC_KEY = "cycle.web.journal-last-sync";
const JOURNAL_PENDING_DELETIONS_KEY = "cycle.web.journal-pending-deletions";
const SCHEDULE_KEY = "cycle.web.schedule-events";
const MEDITATION_KEY = "cycle.web.meditation-logs";
const TASK_TEMPLATE_KEY = "cycle.web.task-templates";
const TASK_DETAILS_KEY = "cycle.web.task-details";
const PREFERENCES_KEY = "cycle.web.preferences";

function loadJson<T>(key: string, fallback: T): T {
  if (typeof window === "undefined") return fallback;
  const raw = window.localStorage.getItem(key);
  if (!raw) return fallback;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function saveJson<T>(key: string, value: T): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(key, JSON.stringify(value));
}

export function loadAuth(): AuthTokens | null {
  return loadJson<AuthTokens | null>(AUTH_KEY, null);
}

export function saveAuth(tokens: AuthTokens | null): void {
  if (typeof window === "undefined") return;
  if (tokens) window.localStorage.setItem(AUTH_KEY, JSON.stringify(tokens));
  else window.localStorage.removeItem(AUTH_KEY);
}

export function loadJournals(): JournalEntry[] {
  return loadJson<JournalEntry[]>(JOURNAL_KEY, []);
}

export function saveJournals(entries: JournalEntry[]): void {
  saveJson(JOURNAL_KEY, entries);
}

export function loadJournalDraft(): string {
  if (typeof window === "undefined") return "";
  return window.localStorage.getItem(JOURNAL_DRAFT_KEY) ?? "";
}

export function saveJournalDraft(text: string): void {
  if (typeof window === "undefined") return;
  if (text) window.localStorage.setItem(JOURNAL_DRAFT_KEY, text);
  else window.localStorage.removeItem(JOURNAL_DRAFT_KEY);
}

export function loadJournalLastSync(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(JOURNAL_LAST_SYNC_KEY);
}

export function saveJournalLastSync(value: string | null): void {
  if (typeof window === "undefined") return;
  if (value) window.localStorage.setItem(JOURNAL_LAST_SYNC_KEY, value);
  else window.localStorage.removeItem(JOURNAL_LAST_SYNC_KEY);
}

export function loadPendingJournalDeletions(): string[] {
  return loadJson<string[]>(JOURNAL_PENDING_DELETIONS_KEY, []);
}

export function savePendingJournalDeletions(ids: string[]): void {
  saveJson(JOURNAL_PENDING_DELETIONS_KEY, [...new Set(ids)]);
}

export function loadScheduleEvents(): ScheduleEvent[] {
  return loadJson<ScheduleEvent[]>(SCHEDULE_KEY, []);
}

export function saveScheduleEvents(events: ScheduleEvent[]): void {
  saveJson(SCHEDULE_KEY, events);
}

export function loadMeditationLogs(): MeditationLog[] {
  return loadJson<MeditationLog[]>(MEDITATION_KEY, []);
}

export function saveMeditationLogs(logs: MeditationLog[]): void {
  saveJson(MEDITATION_KEY, logs);
}

export function loadTaskTemplates(): TaskTemplate[] {
  return loadJson<TaskTemplate[]>(TASK_TEMPLATE_KEY, []).map((template) => ({
    ...template,
    intent: template.intent ?? "",
    achievementVision: template.achievementVision ?? "",
    notes: template.notes ?? ""
  }));
}

export function saveTaskTemplates(templates: TaskTemplate[]): void {
  saveJson(TASK_TEMPLATE_KEY, templates);
}

export function loadTaskDetails(): TaskLocalDetails[] {
  return loadJson<TaskLocalDetails[]>(TASK_DETAILS_KEY, []);
}

export function saveTaskDetails(details: TaskLocalDetails[]): void {
  saveJson(TASK_DETAILS_KEY, details);
}

export function loadWebPreferences(): WebPreferences {
  return loadJson<WebPreferences>(PREFERENCES_KEY, {
    notificationEnabled: false,
    reminderTime: "21:00"
  });
}

export function saveWebPreferences(preferences: WebPreferences): void {
  saveJson(PREFERENCES_KEY, preferences);
}

export function clearLocalUserData(): void {
  if (typeof window === "undefined") return;
  [
    AUTH_KEY,
    JOURNAL_KEY,
    JOURNAL_DRAFT_KEY,
    JOURNAL_LAST_SYNC_KEY,
    JOURNAL_PENDING_DELETIONS_KEY,
    SCHEDULE_KEY,
    MEDITATION_KEY,
    TASK_TEMPLATE_KEY,
    TASK_DETAILS_KEY,
    PREFERENCES_KEY
  ].forEach((key) => window.localStorage.removeItem(key));
}
