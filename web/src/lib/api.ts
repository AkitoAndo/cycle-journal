import { camelize, snakeize } from "@/lib/case";
import type {
  ApiEnvelope,
  AuthResponse,
  CoachResponseData,
  PromptCurrentData,
  PromptDeploymentData,
  PromptTestData,
  PromptVersionData,
  PromptVersionListData,
  RefreshResponse,
  SessionDetailData,
  SessionListData,
  TaskData,
  TaskListData
} from "@/types/api";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ??
  "https://cycle-api-prod-1031235624127.asia-northeast1.run.app";

const ADMIN_API_BASE_URL =
  process.env.NEXT_PUBLIC_ADMIN_API_BASE_URL ??
  "https://cycle-api-dev-1031235624127.asia-northeast1.run.app";

const ADMIN_AUTH_BYPASS = process.env.NEXT_PUBLIC_ADMIN_AUTH_BYPASS === "true";

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

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
    const message =
      typeof json === "object" && json && "error" in json
        ? JSON.stringify((json as { error: unknown }).error)
        : `HTTP ${response.status}`;
    throw new ApiError(message, response.status);
  }
  return camelize<T>(json as never);
}

async function request<T>(
  path: string,
  options: RequestInit & { accessToken?: string; apiBaseUrl?: string } = {}
): Promise<T> {
  const headers = new Headers(options.headers);
  headers.set("Content-Type", "application/json");
  if (options.accessToken && options.accessToken !== "local-admin-bypass") {
    headers.set("Authorization", `Bearer ${options.accessToken}`);
  }
  const response = await fetch(`${options.apiBaseUrl ?? API_BASE_URL}${path}`, {
    ...options,
    headers
  });
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
  await request<ApiEnvelope<{ ok: boolean }>>("/auth/logout", {
    method: "POST",
    body: JSON.stringify(snakeize({ refreshToken }))
  });
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

export async function listPromptVersions(accessToken: string): Promise<PromptVersionListData> {
  const response = await request<ApiEnvelope<PromptVersionListData>>("/admin/prompts/versions", {
    accessToken,
    apiBaseUrl: ADMIN_API_BASE_URL
  });
  return response.data;
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
