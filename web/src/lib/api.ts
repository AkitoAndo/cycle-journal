import { camelize, snakeize } from "@/lib/case";
import { loadAuth, saveAuth } from "@/lib/storage";
import type {
  ApiEnvelope,
  AuthTokens,
  AuthResponse,
  CoachResponseData,
  JournalEntry,
  JournalSyncData,
  PromptCurrentData,
  PromptDeploymentData,
  PromptTestData,
  PromptVersionData,
  PromptVersionListData,
  RefreshResponse,
  SessionDetailData,
  SessionListData,
  TaskReflectionData,
  TaskData,
  TaskListData,
  UserData
} from "@/types/api";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ??
  "https://cycle-api-prod-1031235624127.asia-northeast1.run.app";

const ADMIN_API_BASE_URL =
  process.env.NEXT_PUBLIC_ADMIN_API_BASE_URL ??
  API_BASE_URL;

const ADMIN_AUTH_BYPASS = process.env.NEXT_PUBLIC_ADMIN_AUTH_BYPASS === "true";

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number
  ) {
    super(message);
  }
}

async function parseResponse<T>(response: Response): Promise<T> {
  const text = await response.text();
  const json = text ? (JSON.parse(text) as unknown) : null;
  if (!response.ok) {
    const message = (() => {
      if (typeof json !== "object" || !json) return `HTTP ${response.status}`;
      if ("error" in json) {
        const error = (json as { error: unknown }).error;
        if (typeof error === "object" && error && "message" in error) {
          return String((error as { message: unknown }).message);
        }
        return JSON.stringify(error);
      }
      if ("detail" in json) return JSON.stringify((json as { detail: unknown }).detail);
      return `HTTP ${response.status}`;
    })();
    throw new ApiError(message, response.status);
  }
  return camelize<T>(json as never);
}

let refreshInFlight: Promise<AuthTokens> | null = null;

async function rotateStoredTokens(): Promise<AuthTokens> {
  if (refreshInFlight) return refreshInFlight;
  const current = loadAuth();
  if (!current?.refreshToken) throw new ApiError("再ログインが必要です", 401);

  refreshInFlight = (async () => {
    const response = await fetch(`${API_BASE_URL}/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(snakeize({ refreshToken: current.refreshToken }))
    });
    const payload = await parseResponse<ApiEnvelope<RefreshResponse>>(response);
    const next = {
      accessToken: payload.data.accessToken,
      refreshToken: payload.data.refreshToken
    };
    saveAuth(next);
    return next;
  })();

  try {
    return await refreshInFlight;
  } catch (error) {
    saveAuth(null);
    throw error;
  } finally {
    refreshInFlight = null;
  }
}

async function fetchWithAuthRetry(
  path: string,
  options: RequestInit & { accessToken?: string; apiBaseUrl?: string } = {}
): Promise<Response> {
  const apiBaseUrl = options.apiBaseUrl ?? API_BASE_URL;
  const stored = loadAuth();
  const accessToken = options.accessToken
    ? stored?.accessToken ?? options.accessToken
    : undefined;

  const makeRequest = (token?: string) => {
    const headers = new Headers(options.headers);
    headers.set("Content-Type", "application/json");
    if (token && token !== "local-admin-bypass") {
      headers.set("Authorization", `Bearer ${token}`);
    }
    return fetch(`${apiBaseUrl}${path}`, { ...options, headers });
  };

  let response = await makeRequest(accessToken);
  if (
    response.status === 401 &&
    options.accessToken &&
    accessToken !== "local-admin-bypass" &&
    apiBaseUrl === API_BASE_URL
  ) {
    const refreshed = await rotateStoredTokens();
    response = await makeRequest(refreshed.accessToken);
  }
  return response;
}

async function request<T>(
  path: string,
  options: RequestInit & { accessToken?: string; apiBaseUrl?: string } = {}
): Promise<T> {
  const response = await fetchWithAuthRetry(path, options);
  return parseResponse<T>(response);
}

export async function verifyGoogle(
  idToken: string,
  apiBaseUrl: string = API_BASE_URL
): Promise<AuthResponse> {
  const response = await request<ApiEnvelope<AuthResponse>>("/auth/google", {
    method: "POST",
    apiBaseUrl,
    body: JSON.stringify(snakeize({ idToken }))
  });
  return response.data;
}

export async function refreshTokens(refreshToken: string): Promise<RefreshResponse> {
  const response = await request<ApiEnvelope<RefreshResponse>>("/auth/refresh", {
    method: "POST",
    body: JSON.stringify(snakeize({ refreshToken }))
  });
  return response.data;
}

export async function logout(refreshToken: string): Promise<void> {
  const currentRefreshToken = loadAuth()?.refreshToken ?? refreshToken;
  await request<ApiEnvelope<{ ok: boolean }>>("/auth/logout", {
    method: "POST",
    body: JSON.stringify(snakeize({ refreshToken: currentRefreshToken }))
  });
}

export async function syncJournals(
  accessToken: string,
  entries: JournalEntry[],
  deletedJournalIds: string[],
  lastPulledAt: string | null
): Promise<JournalSyncData> {
  const response = await request<ApiEnvelope<JournalSyncData>>("/journals/sync", {
    method: "POST",
    accessToken,
    body: JSON.stringify(
      snakeize({
        journals: entries.map((entry) => ({
          journalId: entry.id,
          text: entry.text,
          tags: entry.tags,
          entryDate: entry.date,
          deletedAt: entry.deletedAt ?? null,
          createdAt: entry.createdAt ?? entry.date,
          updatedAt: entry.updatedAt ?? entry.deletedAt ?? entry.date
        })),
        deletedJournalIds,
        lastPulledAt
      })
    )
  });
  return response.data;
}

export async function listTasks(accessToken: string, status?: string): Promise<TaskListData> {
  const params = new URLSearchParams({ limit: "50", offset: "0" });
  if (status) params.set("status", status);
  const response = await request<ApiEnvelope<TaskListData>>(`/tasks?${params}`, { accessToken });
  return response.data;
}

export async function createTask(
  accessToken: string,
  body: { title: string; description?: string; dueDate?: string | null }
): Promise<TaskData> {
  const response = await request<ApiEnvelope<TaskData>>("/tasks", {
    method: "POST",
    accessToken,
    body: JSON.stringify(snakeize(body))
  });
  return response.data;
}

export async function updateTask(
  accessToken: string,
  taskId: string,
  body: Partial<Pick<TaskData, "title" | "description" | "status" | "dueDate">>
): Promise<TaskData> {
  const response = await request<ApiEnvelope<TaskData>>(`/tasks/${taskId}`, {
    method: "PUT",
    accessToken,
    body: JSON.stringify(snakeize(body))
  });
  return response.data;
}

export async function deleteTask(accessToken: string, taskId: string): Promise<void> {
  await request<void>(`/tasks/${taskId}`, {
    method: "DELETE",
    accessToken
  });
}

export async function createTaskReflection(
  accessToken: string,
  taskId: string,
  body: {
    whatIDid: string;
    whatINoticed: string;
    whatIWantToTry?: string | null;
    overallFeeling?: string | null;
  }
): Promise<TaskReflectionData> {
  const response = await request<ApiEnvelope<TaskReflectionData>>(
    `/tasks/${taskId}/reflection`,
    {
      method: "POST",
      accessToken,
      body: JSON.stringify(snakeize(body))
    }
  );
  return response.data;
}

export async function listSessions(accessToken: string): Promise<SessionListData> {
  const response = await request<ApiEnvelope<SessionListData>>("/sessions?limit=30&offset=0", {
    accessToken
  });
  return response.data;
}

export async function getSession(accessToken: string, sessionId: string): Promise<SessionDetailData> {
  const response = await request<ApiEnvelope<SessionDetailData>>(`/sessions/${sessionId}`, {
    accessToken
  });
  return response.data;
}

export async function deleteSession(accessToken: string, sessionId: string): Promise<void> {
  await request<void>(`/sessions/${sessionId}`, {
    method: "DELETE",
    accessToken
  });
}

export async function sendCoachMessage(
  accessToken: string,
  body: { message: string; sessionId?: string | null; diaryContent?: string | null }
): Promise<CoachResponseData> {
  const response = await request<ApiEnvelope<CoachResponseData>>("/coach", {
    method: "POST",
    accessToken,
    body: JSON.stringify(snakeize({ ...body, context: null }))
  });
  return response.data;
}

export type CoachStreamEvent =
  | { type: "session"; sessionId: string }
  | { type: "chunk"; chunk: string }
  | { type: "error"; reason: string }
  | { type: "done" };

export async function sendCoachMessageStream(
  accessToken: string,
  body: { message: string; sessionId?: string | null; diaryContent?: string | null },
  onEvent: (event: CoachStreamEvent) => void
): Promise<void> {
  const response = await fetchWithAuthRetry("/coach/stream", {
    method: "POST",
    accessToken,
    body: JSON.stringify(snakeize({ ...body, context: null }))
  });
  if (!response.ok) {
    await parseResponse<never>(response);
  }
  if (!response.body) throw new ApiError("ストリームを開始できませんでした", 500);

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  const consumeBlock = (block: string) => {
    let eventName = "message";
    const dataLines: string[] = [];
    for (const line of block.split(/\r?\n/)) {
      if (line.startsWith("event:")) eventName = line.slice(6).trim();
      if (line.startsWith("data:")) dataLines.push(line.slice(5).trim());
    }
    if (dataLines.length === 0) return;
    const payload = JSON.parse(dataLines.join("\n")) as Record<string, unknown>;
    if (eventName === "session" && typeof payload.session_id === "string") {
      onEvent({ type: "session", sessionId: payload.session_id });
    } else if (eventName === "error") {
      onEvent({ type: "error", reason: String(payload.reason ?? "unknown") });
    } else if (eventName === "done") {
      onEvent({ type: "done" });
    } else if (typeof payload.chunk === "string") {
      onEvent({ type: "chunk", chunk: payload.chunk });
    }
  };

  while (true) {
    const { value, done } = await reader.read();
    buffer += decoder.decode(value, { stream: !done });
    const blocks = buffer.split(/\r?\n\r?\n/);
    buffer = blocks.pop() ?? "";
    blocks.forEach(consumeBlock);
    if (done) break;
  }
  if (buffer.trim()) consumeBlock(buffer);
}

export async function getMe(accessToken: string): Promise<UserData> {
  const response = await request<ApiEnvelope<UserData>>("/users/me", { accessToken });
  return response.data;
}

export async function deleteMe(accessToken: string): Promise<void> {
  await request<ApiEnvelope<{ ok: boolean }>>("/users/me", {
    method: "DELETE",
    accessToken
  });
}

export async function listPromptVersions(accessToken: string): Promise<PromptVersionListData> {
  const response = await request<ApiEnvelope<PromptVersionListData>>("/admin/prompts/versions", {
    accessToken,
    apiBaseUrl: ADMIN_API_BASE_URL
  });
  return response.data;
}

export async function checkAdminAccess(accessToken: string): Promise<boolean> {
  const response = await request<ApiEnvelope<{ isAdmin: boolean }>>("/admin/access", {
    accessToken,
    apiBaseUrl: ADMIN_API_BASE_URL
  });
  return response.data.isAdmin;
}

export async function createPromptVersion(
  accessToken: string,
  body: { title: string; prompt: string; config?: unknown; notes?: string | null }
): Promise<PromptVersionData> {
  const response = await request<ApiEnvelope<PromptVersionData>>("/admin/prompts/versions", {
    method: "POST",
    accessToken,
    apiBaseUrl: ADMIN_API_BASE_URL,
    body: JSON.stringify(snakeize(body))
  });
  return response.data;
}

export async function getPromptDeployment(accessToken: string): Promise<PromptDeploymentData> {
  const response = await request<ApiEnvelope<PromptDeploymentData>>("/admin/prompts/deployment", {
    accessToken,
    apiBaseUrl: ADMIN_API_BASE_URL
  });
  return response.data;
}

export async function deployPromptVersion(
  accessToken: string,
  versionId: string
): Promise<PromptDeploymentData> {
  const response = await request<ApiEnvelope<PromptDeploymentData>>("/admin/prompts/deployment", {
    method: "POST",
    accessToken,
    apiBaseUrl: ADMIN_API_BASE_URL,
    body: JSON.stringify(snakeize({ versionId }))
  });
  return response.data;
}

export async function getCurrentPrompt(accessToken: string): Promise<PromptCurrentData> {
  const response = await request<ApiEnvelope<PromptCurrentData>>("/admin/prompts/current", {
    accessToken,
    apiBaseUrl: ADMIN_API_BASE_URL
  });
  return response.data;
}

export async function testPrompt(
  accessToken: string,
  body: {
    message: string;
    versionId?: string | null;
    prompt?: string | null;
    config?: unknown;
    diaryContent?: string | null;
  }
): Promise<PromptTestData> {
  const response = await request<ApiEnvelope<PromptTestData>>("/admin/prompts/test", {
    method: "POST",
    accessToken,
    apiBaseUrl: ADMIN_API_BASE_URL,
    body: JSON.stringify(snakeize(body))
  });
  return response.data;
}

export { ADMIN_API_BASE_URL, ADMIN_AUTH_BYPASS, API_BASE_URL };
