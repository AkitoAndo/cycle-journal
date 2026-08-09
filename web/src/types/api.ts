export interface ApiEnvelope<T> {
  data: T;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface AuthResponse {
  userId: string;
  appleUserId?: string | null;
  googleUserId?: string | null;
  email?: string | null;
  isNewUser: boolean;
  createdAt: string;
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface RefreshResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface SessionSummary {
  sessionId: string;
  title?: string | null;
  cycleElement?: string | null;
  messageCount?: number | null;
  lastMessageAt?: string | null;
  createdAt: string;
}

export interface SessionListData {
  sessions: SessionSummary[];
  total: number;
  limit: number;
  offset: number;
}

export interface MessageData {
  messageId: string;
  role: "user" | "assistant" | string;
  content: string;
  createdAt: string;
  metadata?: {
    detectedEmotion?: string | null;
    responseType?: string | null;
  } | null;
}

export interface SessionDetailData {
  sessionId: string;
  title?: string | null;
  cycleElement?: string | null;
  hasDiaryContext?: boolean | null;
  messages: MessageData[];
  createdAt: string;
  updatedAt?: string | null;
}

export interface CoachResponseData {
  message: string;
  sessionId?: string | null;
  metadata?: {
    stage?: string | null;
    model?: string | null;
    cycleElement?: string | null;
    detectedEmotion?: string | null;
  } | null;
}

export interface TaskData {
  taskId: string;
  title: string;
  description?: string | null;
  status: "pending" | "completed" | string;
  sessionId?: string | null;
  cycleElement?: string | null;
  dueDate?: string | null;
  completedAt?: string | null;
  createdAt: string;
  updatedAt?: string | null;
}

export interface TaskListData {
  tasks: TaskData[];
  total: number;
  limit: number;
  offset: number;
}

export interface JournalEntry {
  id: string;
  text: string;
  tags: string[];
  date: string;
  deletedAt?: string | null;
}

export interface PromptVersionData {
  versionId: string;
  title: string;
  prompt: string;
  config: PromptConfig;
  notes?: string | null;
  status: string;
  createdBy: string;
  createdAt?: string | null;
}

export interface PromptVersionListData {
  versions: PromptVersionData[];
}

export interface PromptDeploymentData {
  environment: string;
  versionId?: string | null;
  deployedBy?: string | null;
  deployedAt?: string | null;
}

export interface PromptCurrentData {
  prompt: string;
  config: PromptConfig;
  versionId?: string | null;
  source: "internal" | "version" | string;
}

export interface PromptConfig {
  systemPrompt: string;
  useLanggraph: boolean;
  useGeminiFallback: boolean;
  claudeModelCoach: string;
  claudeModelQuick: string;
  geminiModelCoach: string;
  geminiModelQuick: string;
  temperature: number;
  maxTokens: number;
  outputMaxTokensCap: number;
  analyzeEmotionPrompt: string;
  determineCyclePrompt: string;
  analysisInjectionPrompt: string;
  safetyFilterPrompt: string;
  coachPhaseModules?: Record<string, string>;
  coachActionCoreChecklist?: string | null;
  coachLayer8CrisisPrompt?: string | null;
  coachProfessionalBoundaryPrompt?: string | null;
}

export interface PromptTestData {
  message: string;
  versionId?: string | null;
  logId: string;
}
