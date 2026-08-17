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
  { key: "acknowledge", label: "Phase 1 Acknowledge" },
  { key: "triage", label: "Phase 2 Triage" },
  { key: "space", label: "Phase 3 Residue" },
  { key: "naming", label: "Phase 4 Naming" },
  { key: "reflection", label: "Phase 5 Reflection" }
] as const;
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
              <Textarea
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
                    Gemini fallback
                  </label>
                  <label className="flex items-center gap-2 text-[13px] font-semibold">
                    <input
                      type="checkbox"
                      checked={config.useLanggraph}
                      onChange={(event) =>
                        setConfig({ ...config, useLanggraph: event.target.checked })
                      }
                    />
                    LangGraph
                  </label>
                </div>
              )}
              {config && (
                <div className="space-y-3 rounded-md border border-border bg-card p-3">
                  <div className="text-[12px] font-semibold text-muted-foreground">
                    Coach runtime prompts
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
                    Vocabulary lint
                  </label>
                  <PromptArea
                    label="Action core checklist"
                    value={config.coachActionCoreChecklist ?? ""}
                    onChange={(value) =>
                      setConfig({ ...config, coachActionCoreChecklist: value })
                    }
                  />
                  <PromptArea
                    label="Layer8 crisis route"
                    value={config.coachLayer8CrisisPrompt ?? ""}
                    onChange={(value) =>
                      setConfig({ ...config, coachLayer8CrisisPrompt: value })
                    }
                  />
                  <PromptArea
                    label="Professional boundary route"
                    value={config.coachProfessionalBoundaryPrompt ?? ""}
                    onChange={(value) =>
                      setConfig({ ...config, coachProfessionalBoundaryPrompt: value })
                    }
                  />
                  {COACH_PHASE_FIELDS.map((phase) => (
                    <PromptArea
                      key={phase.key}
                      label={phase.label}
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
                <div className="space-y-3 rounded-md border border-border bg-card p-3">
                  <div className="text-[12px] font-semibold text-muted-foreground">
                    LangGraph prompts
                  </div>
                  <PromptArea
                    label="Emotion analysis"
                    value={config.analyzeEmotionPrompt}
                    onChange={(value) => setConfig({ ...config, analyzeEmotionPrompt: value })}
                  />
                  <PromptArea
                    label="Cycle classification"
                    value={config.determineCyclePrompt}
                    onChange={(value) => setConfig({ ...config, determineCyclePrompt: value })}
                  />
                  <PromptArea
                    label="Analysis injection"
                    value={config.analysisInjectionPrompt}
                    onChange={(value) => setConfig({ ...config, analysisInjectionPrompt: value })}
                  />
                  <PromptArea
                    label="Safety filter"
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
                  <Button onClick={saveVersion} disabled={loading || !title.trim() || !prompt.trim()}>
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
                <Button onClick={runTest} disabled={loading || !prompt.trim() || !message.trim()}>
                  <Play size={16} />
                  下書きを試す
                </Button>
                <Button
                  variant="outline"
                  onClick={runComparison}
                  disabled={loading || !prompt.trim() || !message.trim() || !baselinePrompt}
                >
                  <GitCompareArrows size={16} />
                  現行版と比較
                </Button>
              </div>
              {error && <div className="rounded-md bg-destructive/10 px-3 py-2 text-[13px] text-destructive">{error}</div>}
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
  value,
  onChange
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="block space-y-1">
      <div className="text-[11px] font-semibold text-muted-foreground">{label}</div>
      <Textarea
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="min-h-[92px] font-mono text-[12px] leading-relaxed"
      />
    </label>
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
