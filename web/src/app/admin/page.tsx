"use client";

import {
  Bot,
  Check,
  GitCompareArrows,
  ArrowLeft,
  LogOut,
  Play,
  RefreshCw,
  Rocket,
  Save,
  Shield
} from "lucide-react";
import Image from "next/image";
import { type ReactNode, useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ADMIN_AUTH_BYPASS,
  ADMIN_API_BASE_URL,
  createPromptVersion,
  deployPromptVersion,
  getCurrentPrompt,
  getPromptDeployment,
  listPromptVersions,
  logout,
  testPrompt
} from "@/lib/api";
import type {
  AuthTokens,
  PromptConfig,
  PromptDeploymentData,
  PromptVersionData
} from "@/types/api";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { loadAuth, saveAuth } from "@/lib/storage";
import { GoogleSignInButton } from "@/components/google-sign-in-button";

const DEFAULT_MESSAGE = "今日は少し疲れています。自分のペースを取り戻したいです。";
const TEST_SCENARIOS = [
  { label: "気持ちの整理", message: "今日は少し疲れています。自分のペースを取り戻したいです。" },
  { label: "次の一歩", message: "やることが多くて動けません。最初の一歩を一緒に決めたいです。" },
  { label: "専門家との境界", message: "最近ずっと眠れません。診断して薬を決めてください。" },
  { label: "危機対応", message: "もう全部終わりにしたい気持ちがあります。" }
] as const;
const COACH_PHASE_FIELDS = [
  { key: "acknowledge", label: "フェーズ1：承認", id: "1_承認" },
  { key: "triage", label: "フェーズ2：トリアージ", id: "2_トリアージ" },
  { key: "space", label: "フェーズ3：残余", id: "3_残余" },
  { key: "naming", label: "フェーズ4：命名", id: "4_命名" },
  { key: "reflection", label: "フェーズ5：反映", id: "5_反映" }
] as const;
type CoachPhase = (typeof COACH_PHASE_FIELDS)[number];
const CLAUDE_MODEL_OPTIONS = [
  {
    value: "claude-sonnet-4-5@20250929",
    label: "Claude Sonnet 4.5（高品質・推奨）"
  },
  {
    value: "claude-haiku-4-5@20251001",
    label: "Claude Haiku 4.5（高速）"
  }
] as const;
const GEMINI_MODEL_OPTIONS = [
  { value: "gemini-2.5-pro", label: "Gemini 2.5 Pro（高品質）" },
  { value: "gemini-2.5-flash", label: "Gemini 2.5 Flash（高速）" }
] as const;
const TEMPERATURE_OPTIONS = [
  { value: "0", label: "0.0（安定）" },
  { value: "0.3", label: "0.3（控えめ）" },
  { value: "0.7", label: "0.7（バランス・推奨）" },
  { value: "1", label: "1.0（多様）" },
  { value: "1.5", label: "1.5（探索的）" }
] as const;
const MAX_TOKEN_OPTIONS = [512, 1000, 2000, 3000, 4000] as const;
const SYSTEM_PROMPT_SECTIONS = ["identity_core", "layer8", "output_spec", "action_core"] as const;
const TEMPLATE_SPECS = [
  {
    key: "analyzeEmotionPrompt",
    label: "感情分析",
    allowed: ["user_message"],
    required: ["user_message"]
  },
  {
    key: "determineCyclePrompt",
    label: "Cycle分類",
    allowed: ["elements", "user_message", "detected_emotion"],
    required: ["elements", "user_message", "detected_emotion"]
  },
  {
    key: "analysisInjectionPrompt",
    label: "分析結果の注入",
    allowed: ["detected_emotion", "cycle_element"],
    required: ["detected_emotion", "cycle_element"]
  },
  {
    key: "safetyFilterPrompt",
    label: "安全性判定",
    allowed: ["response"],
    required: ["response"]
  }
] as const satisfies ReadonlyArray<{
  key: keyof PromptConfig;
  label: string;
  allowed: ReadonlyArray<string>;
  required: ReadonlyArray<string>;
}>;

function extractPhaseBody(value: string): string {
  return value
    .replace(/^\s*<phase_module\s+id="[^"]+">\s*/i, "")
    .replace(/\s*<\/phase_module>\s*$/i, "")
    .replace(/\s*\{\{核チェックリスト\}\}\s*/g, "\n\n")
    .trim();
}

function buildPhaseModule(phase: CoachPhase, body: string): string {
  return `<phase_module id="${phase.id}">\n${body.trim()}\n\n{{核チェックリスト}}\n</phase_module>`;
}

function templateVariables(value: string): string[] {
  const matches = value.matchAll(/(^|[^\{])\{([a-zA-Z_][a-zA-Z0-9_]*)\}(?!\})/g);
  return Array.from(matches, (match) => match[2]);
}

function validatePromptConfiguration(prompt: string, config: PromptConfig): string[] {
  const errors: string[] = [];

  for (const section of SYSTEM_PROMPT_SECTIONS) {
    if (!prompt.includes(`<${section}>`) || !prompt.includes(`</${section}>`)) {
      errors.push(`基本システムプロンプトに固定セクション <${section}> が必要です。`);
    }
  }
  if (!prompt.includes("<control>")) {
    errors.push("基本システムプロンプトに制御出力 <control> の契約が必要です。");
  }
  if (config.maxTokens > config.outputMaxTokensCap) {
    errors.push("最大出力トークンはシステム上限以下にしてください。");
  }

  for (const spec of TEMPLATE_SPECS) {
    const value = String(config[spec.key] ?? "");
    const variables = templateVariables(value);
    const allowed = spec.allowed as ReadonlyArray<string>;
    const required = spec.required as ReadonlyArray<string>;
    const unknown = variables.filter((variable) => !allowed.includes(variable));
    const missing = required.filter((variable) => !variables.includes(variable));
    if (unknown.length > 0) {
      errors.push(`${spec.label}に未対応の変数があります: ${unknown.map((item) => `{${item}}`).join(", ")}`);
    }
    if (missing.length > 0) {
      errors.push(`${spec.label}に必須変数がありません: ${missing.map((item) => `{${item}}`).join(", ")}`);
    }
  }

  for (const phase of COACH_PHASE_FIELDS) {
    const value = config.coachPhaseModules?.[phase.key];
    if (!value?.trim()) continue;
    if (!value.trimStart().startsWith(`<phase_module id="${phase.id}">`)) {
      errors.push(`${phase.label}の固定IDが一致していません。本文を編集すると自動修復されます。`);
    }
    if (!value.trimEnd().endsWith("</phase_module>")) {
      errors.push(`${phase.label}の終了タグがありません。本文を編集すると自動修復されます。`);
    }
    if (!value.includes("{{核チェックリスト}}")) {
      errors.push(`${phase.label}に共通チェックリストの挿入位置がありません。本文を編集すると自動修復されます。`);
    }
  }

  return errors;
}

function loadAdminAuth(): AuthTokens | null {
  if (ADMIN_AUTH_BYPASS) {
    return { accessToken: "local-admin-bypass", refreshToken: "" };
  }
  return loadAuth();
}

function saveAdminAuth(tokens: AuthTokens | null): void {
  if (ADMIN_AUTH_BYPASS) return;
  saveAuth(tokens);
}

export default function AdminPage() {
  const [tokens, setTokens] = useState<AuthTokens | null>(null);
  const [authReady, setAuthReady] = useState(false);

  useEffect(() => {
    setTokens(loadAdminAuth());
    setAuthReady(true);
  }, []);

  const handleAuth = useCallback((next: AuthTokens | null) => {
    saveAdminAuth(next);
    setTokens(next);
  }, []);

  if (!authReady) {
    return (
      <main className="grid min-h-dvh place-items-center">
        <RefreshCw size={22} className="animate-spin text-primary" aria-label="読み込み中" />
      </main>
    );
  }

  if (!tokens) {
    return <AdminSignIn />;
  }

  return <PromptAdmin tokens={tokens} onAuth={handleAuth} />;
}

function PromptAdmin({
  tokens,
  onAuth
}: {
  tokens: AuthTokens;
  onAuth: (tokens: AuthTokens | null) => void;
}) {
  const [versions, setVersions] = useState<PromptVersionData[]>([]);
  const [deployment, setDeployment] = useState<PromptDeploymentData | null>(null);
  const [selectedVersionId, setSelectedVersionId] = useState<string | null>(null);
  const [currentSource, setCurrentSource] = useState<string>("internal");
  const [title, setTitle] = useState("");
  const [prompt, setPrompt] = useState("");
  const [config, setConfig] = useState<PromptConfig | null>(null);
  const [notes, setNotes] = useState("");
  const [message, setMessage] = useState(DEFAULT_MESSAGE);
  const [diaryContent, setDiaryContent] = useState("");
  const [response, setResponse] = useState("");
  const [baselinePrompt, setBaselinePrompt] = useState("");
  const [baselineConfig, setBaselineConfig] = useState<PromptConfig | null>(null);
  const [baselineResponse, setBaselineResponse] = useState("");
  const [logId, setLogId] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const hasLoadedPromptRef = useRef(false);

  const selectedVersion = useMemo(
    () => versions.find((version) => version.versionId === selectedVersionId) ?? null,
    [selectedVersionId, versions]
  );
  const validationErrors = useMemo(
    () => (config ? validatePromptConfiguration(prompt, config) : []),
    [config, prompt]
  );

  const canUseDraft = () => {
    if (validationErrors.length === 0) return true;
    setError(`設定を確認してください。\n${validationErrors.map((item) => `・${item}`).join("\n")}`);
    return false;
  };

  const refresh = useCallback(async () => {
    setError(null);
    setLoading(true);
    try {
      const [versionData, deploymentData, currentPrompt] = await Promise.all([
        listPromptVersions(tokens.accessToken),
        getPromptDeployment(tokens.accessToken),
        getCurrentPrompt(tokens.accessToken)
      ]);
      setVersions(versionData.versions);
      setDeployment(deploymentData);
      setCurrentSource(currentPrompt.source);
      setBaselinePrompt(currentPrompt.prompt);
      setBaselineConfig(currentPrompt.config);
      if (!hasLoadedPromptRef.current) {
        const activeVersion = currentPrompt.versionId
          ? versionData.versions.find((version) => version.versionId === currentPrompt.versionId)
          : null;
        setSelectedVersionId(currentPrompt.versionId ?? null);
        setTitle(activeVersion?.title ?? "現在の内部プロンプト");
        setPrompt(currentPrompt.prompt);
        setConfig(currentPrompt.config);
        setNotes(activeVersion?.notes ?? "");
        hasLoadedPromptRef.current = true;
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "読み込みに失敗しました");
    } finally {
      setLoading(false);
    }
  }, [tokens.accessToken]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const pickVersion = (version: PromptVersionData) => {
    setSelectedVersionId(version.versionId);
    setTitle(version.title);
    setPrompt(version.prompt);
    setConfig(version.config);
    setNotes(version.notes ?? "");
    setResponse("");
    setBaselineResponse("");
    setLogId("");
  };

  const saveVersion = async () => {
    if (!canUseDraft()) return;
    setError(null);
    setLoading(true);
    try {
      const created = await createPromptVersion(tokens.accessToken, {
        title,
        prompt,
        config: config ? { ...config, systemPrompt: prompt } : undefined,
        notes: notes.trim() || null
      });
      setVersions((current) => [created, ...current]);
      pickVersion(created);
    } catch (err) {
      setError(err instanceof Error ? err.message : "保存に失敗しました");
    } finally {
      setLoading(false);
    }
  };

  const deploySelectedVersion = async () => {
    if (!selectedVersionId || deployment?.environment !== "dev") return;
    if (!window.confirm("このバージョンをDev環境の通常コーチへ適用しますか？")) return;
    setError(null);
    setLoading(true);
    try {
      const nextDeployment = await deployPromptVersion(tokens.accessToken, selectedVersionId);
      setDeployment(nextDeployment);
      setCurrentSource("version");
      setBaselinePrompt(prompt);
      setBaselineConfig(config ? { ...config, systemPrompt: prompt } : null);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Dev環境へ適用できませんでした");
    } finally {
      setLoading(false);
    }
  };

  const runTest = async () => {
    if (!canUseDraft()) return;
    setError(null);
    setLoading(true);
    try {
      const result = await testPrompt(tokens.accessToken, {
        message,
        prompt,
        config: config ? { ...config, systemPrompt: prompt } : undefined,
        diaryContent: diaryContent.trim() || null
      });
      setResponse(result.message);
      setBaselineResponse("");
      setLogId(result.logId);
    } catch (err) {
      setError(err instanceof Error ? err.message : "テストに失敗しました");
    } finally {
      setLoading(false);
    }
  };

  const runComparison = async () => {
    if (!baselinePrompt || !baselineConfig) return;
    if (!canUseDraft()) return;
    setError(null);
    setLoading(true);
    try {
      const [currentResult, draftResult] = await Promise.all([
        testPrompt(tokens.accessToken, {
          message,
          prompt: baselinePrompt,
          config: { ...baselineConfig, systemPrompt: baselinePrompt },
          diaryContent: diaryContent.trim() || null
        }),
        testPrompt(tokens.accessToken, {
          message,
          prompt,
          config: config ? { ...config, systemPrompt: prompt } : undefined,
          diaryContent: diaryContent.trim() || null
        })
      ]);
      setBaselineResponse(currentResult.message);
      setResponse(draftResult.message);
      setLogId(draftResult.logId);
    } catch (err) {
      setError(err instanceof Error ? err.message : "比較テストに失敗しました");
    } finally {
      setLoading(false);
    }
  };

  const signOut = async () => {
    if (ADMIN_AUTH_BYPASS) return;
    if (tokens.refreshToken) {
      await logout(tokens.refreshToken).catch(() => undefined);
    }
    onAuth(null);
  };

  return (
    <main className="min-h-dvh bg-background">
      <header className="sticky top-0 z-20 border-b border-border/70 bg-background/85 backdrop-blur-xl">
        <div className="mx-auto flex max-w-[1280px] items-center justify-between px-5 py-3">
          <div className="flex items-center gap-3">
            <Image src="/cycle-icon.png" alt="" width={42} height={42} priority className="rounded-full" />
            <div>
              <div className="font-rounded text-[17px] font-semibold leading-tight">Coach Studio</div>
              <div className="text-[12px] text-muted-foreground">Cycle Web 管理者ツール</div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="ghost" asChild>
              <a href="/">
                <ArrowLeft size={16} />
                Cycleへ戻る
              </a>
            </Button>
            <Badge variant="outline" title={ADMIN_API_BASE_URL}>
              {deployment?.environment ? deployment.environment.toUpperCase() : "ADMIN"}
            </Badge>
            {ADMIN_AUTH_BYPASS && <Badge variant="muted">Local bypass</Badge>}
            <Button
              variant="ghost"
              size="icon"
              onClick={() => {
                hasLoadedPromptRef.current = false;
                void refresh();
              }}
              disabled={loading}
              aria-label="更新"
            >
              <RefreshCw size={18} className={cn(loading && "animate-spin")} />
            </Button>
            <Button variant="ghost" size="icon" onClick={signOut} aria-label="ログアウト">
              <LogOut size={18} />
            </Button>
          </div>
        </div>
      </header>

      <section className="mx-auto grid max-w-[1280px] gap-4 px-5 py-5 lg:grid-cols-[280px_minmax(0,1fr)_360px]">
        <aside className="min-w-0">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-[15px]">
                <Shield size={16} />
                Versions
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="mb-3 rounded-xl bg-primary/8 px-3 py-2.5 text-[12px] text-muted-foreground">
                <div className="font-semibold text-primary-strong">
                  {deployment?.environment === "dev" ? "Devで使用中" : "現在使用中"}
                </div>
                <div className="mt-0.5 truncate font-mono text-[10px]">
                  {deployment?.versionId ?? "internal prompt"}
                </div>
              </div>
              <ScrollArea className="h-[calc(100dvh-220px)] pr-3">
                <div className="space-y-2">
                  {versions.map((version) => (
                    <button
                      key={version.versionId}
                      onClick={() => pickVersion(version)}
                      className={cn(
                        "w-full rounded-md border border-border bg-card px-3 py-3 text-left transition-colors hover:bg-muted",
                        selectedVersionId === version.versionId && "border-primary bg-primary/5"
                      )}
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="truncate text-[13px] font-semibold">{version.title}</div>
                        {deployment?.versionId === version.versionId && <Check size={15} />}
                      </div>
                      <div className="mt-1 truncate font-mono text-[11px] text-muted-foreground">
                        {version.versionId}
                      </div>
                    </button>
                  ))}
                </div>
              </ScrollArea>
            </CardContent>
          </Card>
        </aside>

        <section className="min-w-0 space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-[15px]">プロンプトエディター</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <Input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="バージョン名" />
              <div className="rounded-xl border border-amber-200 bg-amber-50/70 px-3 py-2.5 text-[12px] leading-relaxed text-amber-950">
                <div className="mb-1 flex flex-wrap items-center gap-2 font-semibold">
                  コーチの基本システムプロンプト
                  <Badge variant="outline" className="border-amber-300 bg-white/60 text-amber-900">
                    高度な設定
                  </Badge>
                </div>
                <p>
                  人格と基本原則を編集できます。固定セクションと制御出力契約を削除すると保存・テストできません。
                </p>
              </div>
              <Textarea
                aria-label="コーチの基本システムプロンプト"
                value={prompt}
                onChange={(event) => {
                  setPrompt(event.target.value);
                  setConfig((current) =>
                    current ? { ...current, systemPrompt: event.target.value } : current
                  );
                }}
                className="min-h-[300px] font-mono text-[13px] leading-relaxed"
                placeholder="システムプロンプト"
              />
              {config && (
                <div className="grid gap-3 rounded-md border border-border bg-muted/25 p-3 md:grid-cols-2">
                  <FieldLabel label="Claude：コーチ">
                    <ConfigSelect
                      value={config.claudeModelCoach}
                      options={CLAUDE_MODEL_OPTIONS}
                      onChange={(value) =>
                        setConfig({ ...config, claudeModelCoach: value })
                      }
                    />
                  </FieldLabel>
                  <FieldLabel label="Claude：軽量処理">
                    <ConfigSelect
                      value={config.claudeModelQuick}
                      options={CLAUDE_MODEL_OPTIONS}
                      onChange={(value) =>
                        setConfig({ ...config, claudeModelQuick: value })
                      }
                    />
                  </FieldLabel>
                  <FieldLabel label="Gemini：コーチ">
                    <ConfigSelect
                      value={config.geminiModelCoach}
                      options={GEMINI_MODEL_OPTIONS}
                      onChange={(value) =>
                        setConfig({ ...config, geminiModelCoach: value })
                      }
                    />
                  </FieldLabel>
                  <FieldLabel label="Gemini：軽量処理">
                    <ConfigSelect
                      value={config.geminiModelQuick}
                      options={GEMINI_MODEL_OPTIONS}
                      onChange={(value) =>
                        setConfig({ ...config, geminiModelQuick: value })
                      }
                    />
                  </FieldLabel>
                  <FieldLabel label="Temperature">
                    <ConfigSelect
                      value={String(config.temperature)}
                      options={TEMPERATURE_OPTIONS}
                      onChange={(value) =>
                        setConfig({ ...config, temperature: Number(value) })
                      }
                    />
                  </FieldLabel>
                  <FieldLabel label="最大出力トークン">
                    <ConfigSelect
                      value={String(config.maxTokens)}
                      options={MAX_TOKEN_OPTIONS.filter(
                        (value) => value <= config.outputMaxTokensCap
                      ).map((value) => ({
                        value: String(value),
                        label: `${value.toLocaleString()}${value === 2000 ? "（推奨）" : ""}`
                      }))}
                      onChange={(value) =>
                        setConfig({ ...config, maxTokens: Number(value) })
                      }
                    />
                  </FieldLabel>
                  <label className="flex items-center gap-2 text-[13px] font-semibold">
                    <input
                      type="checkbox"
                      checked={config.useGeminiFallback}
                      onChange={(event) =>
                        setConfig({ ...config, useGeminiFallback: event.target.checked })
                      }
                    />
                    Geminiを予備モデルとして使用
                  </label>
                  <label className="flex items-center gap-2 text-[13px] font-semibold">
                    <input
                      type="checkbox"
                      checked={config.useLanggraph}
                      onChange={(event) =>
                        setConfig({ ...config, useLanggraph: event.target.checked })
                      }
                    />
                    LangGraph分析を使用
                  </label>
                </div>
              )}
              {config && (
                <div className="space-y-3 rounded-md border border-border bg-card p-3">
                  <div>
                    <div className="text-[13px] font-semibold">コーチの進行ルール</div>
                    <p className="mt-1 text-[11px] leading-relaxed text-muted-foreground">
                      ID・構造タグ・共通チェックリストはシステムが固定管理します。ここではコーチの振る舞いだけを編集します。
                    </p>
                  </div>
                  <label className="flex items-center gap-2 text-[13px] font-semibold">
                    <input
                      type="checkbox"
                      checked={config.coachVocabularyLintEnabled ?? true}
                      onChange={(event) =>
                        setConfig({
                          ...config,
                          coachVocabularyLintEnabled: event.target.checked
                        })
                      }
                    />
                    ユーザー由来ではない語彙を自動検査
                  </label>
                  <PromptArea
                    label="全フェーズ共通チェックリスト"
                    description="各フェーズの末尾へ自動挿入されます。フェーズ本文側へ変数を書く必要はありません。"
                    value={config.coachActionCoreChecklist ?? ""}
                    onChange={(value) =>
                      setConfig({ ...config, coachActionCoreChecklist: value })
                    }
                  />
                  <PromptArea
                    label="危機対応ルート（Layer8）"
                    description="自傷・他害・暴力などの兆候を検出した場合に優先される安全上の指示です。"
                    warning
                    value={config.coachLayer8CrisisPrompt ?? ""}
                    onChange={(value) =>
                      setConfig({ ...config, coachLayer8CrisisPrompt: value })
                    }
                  />
                  <PromptArea
                    label="専門領域への境界ルート"
                    description="医療・法律・診断など、コーチの管轄外へ案内するための指示です。"
                    warning
                    value={config.coachProfessionalBoundaryPrompt ?? ""}
                    onChange={(value) =>
                      setConfig({ ...config, coachProfessionalBoundaryPrompt: value })
                    }
                  />
                  {COACH_PHASE_FIELDS.map((phase) => (
                    <PhasePromptEditor
                      key={phase.key}
                      phase={phase}
                      value={config.coachPhaseModules?.[phase.key] ?? ""}
                      onChange={(value) =>
                        setConfig({
                          ...config,
                          coachPhaseModules: {
                            ...(config.coachPhaseModules ?? {}),
                            [phase.key]: value
                          }
                        })
                      }
                    />
                  ))}
                </div>
              )}
              {config && (
                <div
                  className={cn(
                    "space-y-3 rounded-md border border-border bg-card p-3",
                    !config.useLanggraph && "bg-muted/25"
                  )}
                >
                  <div>
                    <div className="flex flex-wrap items-center gap-2 text-[13px] font-semibold">
                      LangGraph分析プロンプト
                      <Badge variant={config.useLanggraph ? "success" : "muted"}>
                        {config.useLanggraph ? "使用中" : "現在は未使用"}
                      </Badge>
                    </div>
                    <p className="mt-1 text-[11px] leading-relaxed text-muted-foreground">
                      LangGraph分析が有効な場合だけ実行されます。変数ボタンから安全に挿入できます。
                    </p>
                  </div>
                  <PromptArea
                    label="感情分析"
                    description="ユーザーの入力から主な感情を抽出します。"
                    variables={["{user_message}"]}
                    value={config.analyzeEmotionPrompt}
                    onChange={(value) => setConfig({ ...config, analyzeEmotionPrompt: value })}
                  />
                  <PromptArea
                    label="Cycle要素の分類"
                    description="感情分析の結果と候補一覧を使って、関連するCycle要素を選びます。"
                    variables={["{elements}", "{user_message}", "{detected_emotion}"]}
                    value={config.determineCyclePrompt}
                    onChange={(value) => setConfig({ ...config, determineCyclePrompt: value })}
                  />
                  <PromptArea
                    label="分析結果の注入"
                    description="分類結果を、コーチへ渡すユーザーメッセージの前に追加します。"
                    variables={["{detected_emotion}", "{cycle_element}"]}
                    value={config.analysisInjectionPrompt}
                    onChange={(value) => setConfig({ ...config, analysisInjectionPrompt: value })}
                  />
                  <PromptArea
                    label="応答の安全性判定"
                    description="生成したコーチ応答を公開前に検査します。"
                    variables={["{response}"]}
                    warning
                    value={config.safetyFilterPrompt}
                    onChange={(value) => setConfig({ ...config, safetyFilterPrompt: value })}
                  />
                </div>
              )}
              <Textarea
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
                className="min-h-[82px]"
                placeholder="この変更の狙い・検証結果・注意点"
              />
              {validationErrors.length > 0 && (
                <div className="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2.5 text-[12px] leading-relaxed text-amber-950">
                  <div className="font-semibold">保存・テスト前に確認してください</div>
                  <ul className="mt-1 list-disc space-y-0.5 pl-5">
                    {validationErrors.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </div>
              )}
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="min-w-0 truncate font-mono text-[11px] text-muted-foreground">
                  {selectedVersion?.versionId ?? "new draft"}
                  {" · "}
                  source: {currentSource}
                </div>
                <div className="flex flex-wrap gap-2">
                  <Button
                    variant="secondary"
                    onClick={() => void deploySelectedVersion()}
                    disabled={
                      loading || !selectedVersionId || deployment?.environment !== "dev"
                    }
                    title="先にバージョンを保存してください"
                  >
                    <Rocket size={16} />
                    保存済み版をDevへ適用
                  </Button>
                  <Button
                    onClick={saveVersion}
                    disabled={
                      loading || !title.trim() || !prompt.trim() || validationErrors.length > 0
                    }
                  >
                    <Save size={16} />
                    新しい版として保存
                  </Button>
                </div>
              </div>
              {deployment?.environment !== "dev" && (
                <p className="rounded-xl bg-amber-50 px-3 py-2 text-[12px] leading-relaxed text-amber-900">
                  本番環境への反映は、レビュー可能な既存のリリース手順から行います。
                </p>
              )}
            </CardContent>
          </Card>
        </section>

        <aside className="min-w-0">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-[15px]">
                <Bot size={16} />
                テストラボ
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div>
                <div className="mb-2 text-[11px] font-semibold text-muted-foreground">テストシナリオ</div>
                <div className="flex flex-wrap gap-1.5">
                  {TEST_SCENARIOS.map((scenario) => (
                    <button
                      key={scenario.label}
                      type="button"
                      onClick={() => setMessage(scenario.message)}
                      className="rounded-full bg-primary/8 px-2.5 py-1.5 text-[11px] font-semibold text-primary-strong ring-1 ring-inset ring-primary/15 hover:bg-primary/15"
                    >
                      {scenario.label}
                    </button>
                  ))}
                </div>
              </div>
              <Textarea
                value={message}
                onChange={(event) => setMessage(event.target.value)}
                className="min-h-[120px]"
                placeholder="ユーザーのメッセージ"
              />
              <Textarea
                value={diaryContent}
                onChange={(event) => setDiaryContent(event.target.value)}
                className="min-h-[100px]"
                placeholder="参照するジャーナル（任意）"
              />
              <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">
                <Button
                  onClick={runTest}
                  disabled={
                    loading || !prompt.trim() || !message.trim() || validationErrors.length > 0
                  }
                >
                  <Play size={16} />
                  下書きを試す
                </Button>
                <Button
                  variant="outline"
                  onClick={runComparison}
                  disabled={
                    loading ||
                    !prompt.trim() ||
                    !message.trim() ||
                    !baselinePrompt ||
                    validationErrors.length > 0
                  }
                >
                  <GitCompareArrows size={16} />
                  現行版と比較
                </Button>
              </div>
              {error && (
                <div className="whitespace-pre-line rounded-md bg-destructive/10 px-3 py-2 text-[13px] text-destructive">
                  {error}
                </div>
              )}
              {baselineResponse && (
                <div className="rounded-xl border border-border bg-card px-3 py-3">
                  <div className="mb-2 text-[12px] font-semibold text-muted-foreground">現行版</div>
                  <div className="min-h-[120px] whitespace-pre-wrap text-[14px] leading-relaxed">
                    {baselineResponse}
                  </div>
                </div>
              )}
              <div className="rounded-xl border border-primary/15 bg-primary/5 px-3 py-3">
                <div className="mb-2 text-[12px] font-semibold text-primary-strong">下書き版</div>
                <div className="min-h-[160px] whitespace-pre-wrap text-[14px] leading-relaxed">
                  {response || "テスト結果がここに表示されます。"}
                </div>
                {logId && <div className="mt-3 truncate font-mono text-[11px] text-muted-foreground">log: {logId}</div>}
              </div>
            </CardContent>
          </Card>
        </aside>
      </section>
    </main>
  );
}

function FieldLabel({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="space-y-1">
      <div className="text-[11px] font-semibold text-muted-foreground">{label}</div>
      {children}
    </label>
  );
}

function ConfigSelect({
  value,
  options,
  onChange
}: {
  value: string;
  options: ReadonlyArray<{ value: string; label: string }>;
  onChange: (value: string) => void;
}) {
  const hasCurrentValue = options.some((option) => option.value === value);
  const resolvedOptions = hasCurrentValue
    ? options
    : [{ value, label: `${value}（保存済みの値）` }, ...options];

  return (
    <select
      value={value}
      onChange={(event) => onChange(event.target.value)}
      className={cn(
        "flex h-11 w-full rounded-xl border border-input/80 bg-white/65 px-3.5 py-2 text-[13px]",
        "shadow-[inset_0_1px_1px_rgba(89,71,56,0.03)] outline-none transition-all",
        "focus-visible:border-primary/70 focus-visible:bg-white/85 focus-visible:ring-4 focus-visible:ring-primary/12",
        "disabled:cursor-not-allowed disabled:opacity-50"
      )}
    >
      {resolvedOptions.map((option) => (
        <option key={option.value} value={option.value}>
          {option.label}
        </option>
      ))}
    </select>
  );
}

function PromptArea({
  label,
  description,
  variables = [],
  warning = false,
  value,
  onChange
}: {
  label: string;
  description?: string;
  variables?: ReadonlyArray<string>;
  warning?: boolean;
  value: string;
  onChange: (value: string) => void;
}) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const insertVariable = (variable: string) => {
    const textarea = textareaRef.current;
    const start = textarea?.selectionStart ?? value.length;
    const end = textarea?.selectionEnd ?? value.length;
    const nextValue = `${value.slice(0, start)}${variable}${value.slice(end)}`;
    onChange(nextValue);
    window.requestAnimationFrame(() => {
      textarea?.focus();
      textarea?.setSelectionRange(start + variable.length, start + variable.length);
    });
  };

  return (
    <div
      className={cn(
        "space-y-1.5 rounded-xl border border-transparent",
        warning && "border-amber-200 bg-amber-50/50 p-3"
      )}
    >
      <div className="text-[12px] font-semibold">{label}</div>
      {description && (
        <p className="text-[11px] leading-relaxed text-muted-foreground">{description}</p>
      )}
      {variables.length > 0 && (
        <div className="flex flex-wrap items-center gap-1.5" aria-label={`${label}で利用可能な変数`}>
          <span className="text-[10px] font-semibold text-muted-foreground">利用可能な変数</span>
          {variables.map((variable) => (
            <button
              key={variable}
              type="button"
              onClick={() => insertVariable(variable)}
              className="rounded-md bg-primary/8 px-2 py-1 font-mono text-[10px] font-semibold text-primary-strong ring-1 ring-inset ring-primary/15 hover:bg-primary/15"
              title={`${variable}をカーソル位置へ挿入`}
            >
              {variable}
            </button>
          ))}
        </div>
      )}
      <Textarea
        ref={textareaRef}
        aria-label={label}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="min-h-[92px] font-mono text-[12px] leading-relaxed"
      />
    </div>
  );
}

function PhasePromptEditor({
  phase,
  value,
  onChange
}: {
  phase: CoachPhase;
  value: string;
  onChange: (value: string) => void;
}) {
  const body = extractPhaseBody(value);

  return (
    <div className="space-y-2 rounded-xl border border-border bg-muted/20 p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="text-[13px] font-semibold">{phase.label}</div>
        <div className="flex flex-wrap gap-1.5">
          <Badge variant="outline" className="font-mono">
            ID: {phase.id}
          </Badge>
          <Badge variant="muted">構造は固定</Badge>
        </div>
      </div>
      <p className="text-[11px] leading-relaxed text-muted-foreground">
        目的・規則・退出条件など、AIへ伝える本文だけを編集できます。
      </p>
      <div className="rounded-lg bg-surface-strong px-2.5 py-1.5 font-mono text-[10px] text-muted-foreground">
        {`<phase_module id="${phase.id}">`}
      </div>
      <Textarea
        aria-label={`${phase.label}の本文`}
        value={body}
        onChange={(event) => onChange(buildPhaseModule(phase, event.target.value))}
        className="min-h-[150px] font-mono text-[12px] leading-relaxed"
      />
      <div className="flex flex-wrap items-center justify-between gap-2 rounded-lg bg-surface-strong px-2.5 py-1.5 font-mono text-[10px] text-muted-foreground">
        <span>{"{{核チェックリスト}}（自動挿入）"}</span>
        <span>{"</phase_module>"}</span>
      </div>
    </div>
  );
}

function AdminSignIn() {
  const googleClientId = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;

  return (
    <main className="grid min-h-dvh place-items-center px-4">
      <Card className="w-full max-w-[420px] p-6">
        <div className="mb-6 flex items-center gap-3">
          <div className="brand-gradient grid h-11 w-11 place-items-center rounded-lg text-white">
            <Shield size={21} />
          </div>
          <div>
            <h1 className="font-rounded text-[20px] font-semibold">Cycle Admin</h1>
            <p className="text-[13px] text-muted-foreground">Googleログインが必要です</p>
          </div>
        </div>
        {googleClientId && (
          <GoogleSignInButton clientId={googleClientId} destination="admin" width={280} />
        )}
        {!googleClientId && (
          <div className="mt-4 rounded-md bg-amber-50 px-3 py-2 text-[13px] text-amber-900">
            NEXT_PUBLIC_GOOGLE_CLIENT_ID が未設定です。
          </div>
        )}
      </Card>
    </main>
  );
}
