"use client";

import {
  Bell,
  BookHeart,
  Cloud,
  CalendarDays,
  Check,
  CheckCircle2,
  CheckSquare,
  Circle,
  Clock3,
  House,
  Leaf,
  LogOut,
  MessageCircle,
  PenLine,
  Pencil,
  Plus,
  RefreshCw,
  RotateCcw,
  Search,
  ShieldCheck,
  Sparkles,
  Sprout,
  Trash2,
  User,
  UserRound,
  Wind,
  WalletCards
} from "lucide-react";
import Image from "next/image";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  API_BASE_URL,
  createTask,
  createTaskReflection,
  deleteMe,
  deleteSession,
  deleteTask,
  getMe,
  getSession,
  listSessions,
  listTasks,
  logout,
  sendCoachMessageStream,
  syncJournals,
  updateTask,
  verifyGoogle
} from "@/lib/api";
import {
  clearLocalUserData,
  loadAuth,
  loadJournalDraft,
  loadJournalLastSync,
  loadJournals,
  loadPendingJournalDeletions,
  loadTaskDetails,
  loadTaskTemplates,
  loadWebPreferences,
  saveAuth,
  saveJournalDraft,
  saveJournalLastSync,
  saveJournals,
  savePendingJournalDeletions,
  saveTaskDetails,
  saveTaskTemplates,
  saveWebPreferences
} from "@/lib/storage";
import type {
  AuthTokens,
  JournalData,
  JournalEntry,
  MessageData,
  SessionSummary,
  TaskData,
  TaskLocalDetails,
  TaskTemplate,
  UserData,
  WebPreferences
} from "@/types/api";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Separator } from "@/components/ui/separator";
import { WeekCalendar, toDateKey } from "@/components/ui/week-calendar";
import { HomeView } from "@/features/home/home-view";
import { MindfulnessView } from "@/features/mindfulness/mindfulness-view";

type Tab = "home" | "journal" | "coach" | "tasks" | "settings";

const tabs: {
  id: Tab;
  label: string;
  icon?: React.ComponentType<{ size?: number; className?: string }>;
  isBrand?: boolean;
}[] = [
  { id: "home", label: "ホーム", icon: House },
  { id: "journal", label: "ジャーナル", icon: Leaf },
  { id: "coach", label: "セッション", isBrand: true },
  { id: "tasks", label: "タスクリスト", icon: CheckSquare },
  { id: "settings", label: "マイページ", icon: UserRound }
];

const PRIVACY_URL =
  "https://akitoando.github.io/cycle-journal/legal/PRIVACY_POLICY.html";
const TERMS_URL =
  "https://akitoando.github.io/cycle-journal/legal/TERMS_OF_SERVICE.html";

function useWebReminder(authenticated: boolean) {
  useEffect(() => {
    if (!authenticated || typeof Notification === "undefined") return;
    const checkReminder = () => {
      const preferences = loadWebPreferences();
      if (!preferences.notificationEnabled || Notification.permission !== "granted") return;
      const now = new Date();
      const currentTime = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
      if (currentTime !== preferences.reminderTime) return;
      const deliveryKey = `cycle.web.reminder.${toDateKey(now)}.${currentTime}`;
      if (window.sessionStorage.getItem(deliveryKey)) return;
      window.sessionStorage.setItem(deliveryKey, "sent");
      new Notification("Cycle", { body: "今日のふりかえりを書きましょう。" });
    };
    checkReminder();
    const timer = window.setInterval(checkReminder, 20_000);
    return () => window.clearInterval(timer);
  }, [authenticated]);
}

export default function Home() {
  const [tokens, setTokens] = useState<AuthTokens | null>(null);
  const [activeTab, setActiveTab] = useState<Tab>("home");
  useWebReminder(Boolean(tokens));
  const todayLabel = useMemo(
    () =>
      new Intl.DateTimeFormat("ja-JP", {
        month: "long",
        day: "numeric",
        weekday: "short"
      }).format(new Date()),
    []
  );

  useEffect(() => {
    setTokens(loadAuth());
  }, []);

  useEffect(() => {
    if (!tokens) return;
    window.scrollTo({ top: 0, behavior: "instant" });
  }, [activeTab, tokens]);

  const handleAuth = useCallback((next: AuthTokens | null) => {
    saveAuth(next);
    setTokens(next);
  }, []);

  if (!tokens) {
    return <SignInView onAuth={handleAuth} />;
  }

  return (
    <main className="relative mx-auto grid min-h-dvh max-w-[1220px] grid-rows-[auto_minmax(0,1fr)_auto]">
      <header className="app-topbar sticky top-0 z-10 flex items-center justify-between px-5 py-3 backdrop-blur-xl md:px-7">
        <div className="flex items-center gap-3">
          <Image
            src="/cycle-icon.png"
            alt=""
            width={44}
            height={44}
            priority
            className="h-11 w-11 rounded-full shadow-[0_9px_24px_-14px_rgba(89,71,56,0.7)]"
          />
          <div>
            <div className="font-rounded text-[17px] font-bold leading-tight tracking-[-0.02em]">Cycle</div>
            <div className="text-[11px] text-muted-foreground sm:text-[12px]">自分のリズムを、見つけていく。</div>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <span className="hidden text-[12px] font-medium text-muted-foreground md:inline">{todayLabel}</span>
          <Badge variant="outline" className="gap-1.5 bg-white/35 px-3 py-1">
            <ShieldCheck size={12} />
            <span className="hidden sm:inline">プライベート</span>
          </Badge>
        </div>
      </header>

      <section className="min-w-0 px-4 pb-28 pt-6 md:px-7 md:pt-8">
        <div key={activeTab} className="animate-fade-in-up">
          {activeTab === "home" && <HomeView accessToken={tokens.accessToken} />}
          {activeTab === "journal" && <JournalView accessToken={tokens.accessToken} />}
          {activeTab === "coach" && <CoachView accessToken={tokens.accessToken} />}
          {activeTab === "tasks" && <TasksView accessToken={tokens.accessToken} />}
          {activeTab === "settings" && <SettingsView tokens={tokens} onAuth={handleAuth} />}
        </div>
      </section>

      <nav className="pointer-events-none fixed inset-x-0 bottom-0 z-20 mx-auto flex max-w-[1220px] justify-center px-3 pb-[max(10px,env(safe-area-inset-bottom))]">
        <div className="bottom-dock pointer-events-auto grid w-full max-w-[720px] grid-cols-5 rounded-[24px] border border-white/70 px-1.5 py-1 ring-1 ring-inset ring-primary-strong/5">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const active = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={cn(
                  "relative isolate flex h-[62px] flex-col items-center justify-center gap-1 rounded-[18px] text-[10px] font-semibold outline-none transition-colors focus-visible:ring-2 focus-visible:ring-primary/45",
                  tab.isBrand && "cycle-tab-button",
                  active ? "text-primary-strong" : "text-muted-foreground hover:text-foreground",
                  active && !tab.isBrand && "tab-pill-active"
                )}
                aria-current={active ? "page" : undefined}
                aria-label={tab.label}
              >
                {tab.isBrand ? (
                  <Image
                    src="/cycle-icon.png"
                    alt=""
                    width={58}
                    height={58}
                    className="cycle-tab-logo -translate-y-1.5 rounded-full"
                  />
                ) : Icon ? (
                  <>
                    <Icon size={20} className={cn("transition-transform", active && "scale-110")} />
                    <span>{tab.label}</span>
                  </>
                ) : null}
              </button>
            );
          })}
        </div>
      </nav>
    </main>
  );
}

function SignInView({ onAuth }: { onAuth: (tokens: AuthTokens) => void }) {
  const [manualAccessToken, setManualAccessToken] = useState("");
  const [manualRefreshToken, setManualRefreshToken] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isAuthenticating, setIsAuthenticating] = useState(false);
  const googleClientId = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;
  const enableDeveloperLogin =
    process.env.NODE_ENV !== "production" &&
    process.env.NEXT_PUBLIC_ENABLE_DEV_LOGIN === "true";

  useEffect(() => {
    const controller = new AbortController();
    void fetch(`${API_BASE_URL}/health`, {
      cache: "no-store",
      signal: controller.signal
    }).catch(() => undefined);
    return () => controller.abort();
  }, []);

  useEffect(() => {
    if (!googleClientId) return;
    let active = true;
    const renderGoogleButton = () => {
      if (!active) return;
      const target = document.getElementById("google-signin");
      const google = (window as unknown as GoogleWindow).google;
      if (!target || !google) return;
      if (target.dataset.gsiReady === "true") return;
      target.dataset.gsiReady = "true";
      target.replaceChildren();
      google?.accounts.id.initialize({
        client_id: googleClientId,
        callback: async (response) => {
          setError(null);
          setIsAuthenticating(true);
          try {
            const auth = await verifyGoogle(response.credential);
            onAuth({ accessToken: auth.accessToken, refreshToken: auth.refreshToken });
          } catch (err) {
            setError(err instanceof Error ? err.message : "Googleログインに失敗しました");
          } finally {
            if (active) setIsAuthenticating(false);
          }
        }
      });
      google.accounts.id.renderButton(target, {
        theme: "outline",
        size: "large",
        width: 260,
        text: "signin_with"
      });
    };

    const existingScript = document.getElementById("google-identity-services") as HTMLScriptElement | null;
    const script = existingScript ?? document.createElement("script");
    if (!existingScript) {
      script.id = "google-identity-services";
      script.src = "https://accounts.google.com/gsi/client";
      script.async = true;
      script.defer = true;
      document.head.appendChild(script);
    }
    if ((window as unknown as GoogleWindow).google) renderGoogleButton();
    else script.addEventListener("load", renderGoogleButton);

    return () => {
      active = false;
      script.removeEventListener("load", renderGoogleButton);
    };
  }, [googleClientId, onAuth]);

  const submitManual = () => {
    if (!manualAccessToken.trim()) {
      setError("アクセストークンを入力してください");
      return;
    }
    onAuth({
      accessToken: manualAccessToken.trim(),
      refreshToken: manualRefreshToken.trim()
    });
  };

  return (
    <main className="grid min-h-dvh place-items-center px-4 py-10">
      <div className="w-full max-w-[440px]">
        <div className="mb-8 flex flex-col items-center text-center">
          <Image
            src="/cycle-icon.png"
            alt="Cycle"
            width={112}
            height={112}
            priority
            className="mb-5 h-28 w-28 rounded-full shadow-[0_20px_50px_-18px_rgba(89,71,56,0.55)]"
          />
          <div className="font-rounded text-2xl font-bold tracking-tight">Cycle</div>
          <div className="mt-1 text-sm text-muted-foreground">自分と向き合う日記アプリ</div>
        </div>

        <Card className="p-6">
          <h1 className="font-rounded text-[22px] font-semibold leading-snug">
            日記を書き、振り返り、
            <br />
            成長のサイクルを回そう
          </h1>
          <p className="mt-3 text-[14px] leading-relaxed text-muted-foreground">
            日々の気持ちや出来事を記録し、AIコーチとの対話で自分のペースを整えます。
          </p>

          <div className="mt-6">
            <div className="flex items-center gap-2 text-[13px] font-semibold text-muted-foreground">
              <User size={16} />
              サインイン
            </div>

            {googleClientId ? (
              <div id="google-signin" className="mt-4 min-h-[44px]" />
            ) : (
              <div className="mt-4 rounded-xl bg-amber-50 px-3 py-2.5 text-[13px] leading-relaxed text-amber-900">
                Web用Google Client ID が未設定です。<br />
                <code className="rounded bg-amber-100 px-1">.env.local</code> に{" "}
                <code className="rounded bg-amber-100 px-1">NEXT_PUBLIC_GOOGLE_CLIENT_ID</code>{" "}
                を設定してください。
              </div>
            )}

            {isAuthenticating && (
              <div
                role="status"
                aria-live="polite"
                className="mt-3 flex items-center gap-2 rounded-xl bg-primary/10 px-3 py-2.5 text-[13px] font-medium text-primary-strong"
              >
                <RefreshCw size={15} className="animate-spin" />
                ログインしています。初回は数秒かかることがあります…
              </div>
            )}

            {error && <ErrorBanner>{error}</ErrorBanner>}

            {enableDeveloperLogin && (
              <>
                <div className="my-5 flex items-center gap-3 text-[11px] font-semibold uppercase tracking-widest text-muted-foreground">
                  <Separator className="flex-1" />
                  開発用
                  <Separator className="flex-1" />
                </div>

                <Field label="Access token">
                  <Textarea
                    value={manualAccessToken}
                    onChange={(event) => setManualAccessToken(event.target.value)}
                    rows={4}
                    placeholder="Bearer なしで貼り付け"
                    className="font-mono text-[13px]"
                  />
                </Field>
                <Field label="Refresh token">
                  <Input
                    value={manualRefreshToken}
                    onChange={(event) => setManualRefreshToken(event.target.value)}
                    placeholder="任意"
                    className="font-mono text-[13px]"
                  />
                </Field>

                <Button className="mt-5 w-full" onClick={submitManual}>
                  開発用トークンで入る
                </Button>

                <div className="mt-5 flex items-center justify-center">
                  <Badge variant="muted" className="text-[11px] font-medium">
                    API: {API_BASE_URL}
                  </Badge>
                </div>
              </>
            )}
          </div>
        </Card>
        <p className="mt-4 text-center text-[11px] leading-relaxed text-muted-foreground">
          サインインを続けることで、
          <a className="underline underline-offset-2 hover:text-foreground" href={TERMS_URL} target="_blank" rel="noreferrer">
            利用規約
          </a>
          と
          <a className="underline underline-offset-2 hover:text-foreground" href={PRIVACY_URL} target="_blank" rel="noreferrer">
            プライバシーポリシー
          </a>
          に同意したものとみなされます。
        </p>
      </div>
    </main>
  );
}

const JOURNAL_PROMPTS = [
  "今日、心が少し動いたことは？",
  "いま手放したい気持ちは？",
  "明日の自分に残したいことは？"
];

function JournalView({ accessToken }: { accessToken: string }) {
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  const [text, setText] = useState("");
  const [tagText, setTagText] = useState("");
  const [query, setQuery] = useState("");
  const [draftReady, setDraftReady] = useState(false);
  const [saveFeedback, setSaveFeedback] = useState("");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [showTrash, setShowTrash] = useState(false);
  const [syncState, setSyncState] = useState<"idle" | "syncing" | "synced" | "error">("idle");
  const [syncMessage, setSyncMessage] = useState("未同期");
  const composerRef = useRef<HTMLTextAreaElement>(null);
  const feedbackTimerRef = useRef<number | null>(null);
  const [selectedDate, setSelectedDate] = useState<Date>(() => {
    const now = new Date();
    now.setHours(0, 0, 0, 0);
    return now;
  });

  const synchronize = useCallback(async (sourceEntries: JournalEntry[]) => {
    setSyncState("syncing");
    setSyncMessage("同期中…");
    try {
      const pendingDeletionIds = loadPendingJournalDeletions();
      const response = await syncJournals(
        accessToken,
        sourceEntries,
        pendingDeletionIds,
        loadJournalLastSync()
      );
      const merged = mergeJournalEntries(sourceEntries, response.journals).filter(
        (entry) => !pendingDeletionIds.includes(entry.id)
      );
      setEntries(merged);
      saveJournals(merged);
      saveJournalLastSync(response.serverTime);
      savePendingJournalDeletions(
        loadPendingJournalDeletions().filter((id) => !pendingDeletionIds.includes(id))
      );
      setSyncState("synced");
      setSyncMessage(
        response.conflictCount > 0
          ? `${response.conflictCount}件の競合を新しい内容で解決`
          : "iOSと同期済み"
      );
    } catch (cause) {
      setSyncState("error");
      setSyncMessage(cause instanceof Error ? cause.message : "同期できませんでした");
    }
  }, [accessToken]);

  useEffect(() => {
    const localEntries = loadJournals().map(normalizeJournalEntry);
    setEntries(localEntries);
    setText(loadJournalDraft());
    setDraftReady(true);
    void synchronize(localEntries);
  }, [synchronize]);

  useEffect(() => {
    if (!draftReady) return;
    saveJournalDraft(text);
  }, [draftReady, text]);

  useEffect(
    () => () => {
      if (feedbackTimerRef.current) window.clearTimeout(feedbackTimerRef.current);
    },
    []
  );

  const availableEntries = useMemo(
    () => entries.filter((entry) => !entry.deletedAt),
    [entries]
  );
  const deletedEntries = useMemo(
    () => entries.filter((entry) => entry.deletedAt),
    [entries]
  );

  const markedDates = useMemo(() => {
    const keys = new Set<string>();
    for (const entry of availableEntries) keys.add(toDateKey(new Date(entry.date)));
    return keys;
  }, [availableEntries]);

  const selectedDateKey = toDateKey(selectedDate);

  const activeEntries = useMemo(() => {
    return availableEntries
      .filter((entry) => toDateKey(new Date(entry.date)) === selectedDateKey)
      .filter((entry) => {
        if (!query.trim()) return true;
        const target = `${entry.text} ${entry.tags.join(" ")}`.toLowerCase();
        return target.includes(query.toLowerCase());
      })
      .sort((a, b) => Date.parse(b.date) - Date.parse(a.date));
  }, [availableEntries, query, selectedDateKey]);

  const journalStats = useMemo(() => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const weekStart = new Date(today);
    weekStart.setDate(today.getDate() - today.getDay());
    const nextWeek = new Date(weekStart);
    nextWeek.setDate(weekStart.getDate() + 7);

    const thisWeek = availableEntries.filter((entry) => {
      const date = new Date(entry.date);
      return date >= weekStart && date < nextWeek;
    }).length;

    const recordedDays = new Set(availableEntries.map((entry) => toDateKey(new Date(entry.date))));
    const cursor = new Date(today);
    if (!recordedDays.has(toDateKey(cursor))) cursor.setDate(cursor.getDate() - 1);

    let streak = 0;
    while (recordedDays.has(toDateKey(cursor))) {
      streak += 1;
      cursor.setDate(cursor.getDate() - 1);
    }

    return { thisWeek, streak, total: availableEntries.length };
  }, [availableEntries]);

  const dateLabel = useMemo(
    () =>
      new Intl.DateTimeFormat("ja-JP", {
        month: "long",
        day: "numeric",
        weekday: "short"
      }).format(selectedDate),
    [selectedDate]
  );

  const addEntry = () => {
    const trimmed = text.trim();
    if (!trimmed) return;
    const now = new Date();
    const tags = tagText
      .split(/[,、]/)
      .map((tag) => tag.trim())
      .filter(Boolean);
    let next: JournalEntry[];
    if (editingId) {
      next = entries.map((entry) =>
        entry.id === editingId
          ? { ...entry, text: trimmed, tags, updatedAt: now.toISOString() }
          : entry
      );
    } else {
      const entryDate = new Date(selectedDate);
      entryDate.setHours(now.getHours(), now.getMinutes(), now.getSeconds());
      next = [
        {
          id: crypto.randomUUID(),
          text: trimmed,
          tags,
          date: entryDate.toISOString(),
          createdAt: now.toISOString(),
          updatedAt: now.toISOString()
        },
        ...entries
      ];
    }
    setEntries(next);
    saveJournals(next);
    void synchronize(next);
    setText("");
    setTagText("");
    setEditingId(null);
    setSaveFeedback(editingId ? "更新しました" : "記録しました");
    if (feedbackTimerRef.current) window.clearTimeout(feedbackTimerRef.current);
    feedbackTimerRef.current = window.setTimeout(() => setSaveFeedback(""), 2400);
    window.requestAnimationFrame(() => composerRef.current?.focus());
  };

  const deleteEntry = (id: string) => {
    const now = new Date().toISOString();
    const next = entries.map((entry) =>
      entry.id === id ? { ...entry, deletedAt: now, updatedAt: now } : entry
    );
    setEntries(next);
    saveJournals(next);
    void synchronize(next);
  };

  const editEntry = (entry: JournalEntry) => {
    setEditingId(entry.id);
    setText(entry.text);
    setTagText(entry.tags.join("、"));
    setSelectedDate(new Date(entry.date));
    window.requestAnimationFrame(() => composerRef.current?.focus());
  };

  const restoreEntry = (id: string) => {
    const now = new Date().toISOString();
    const next = entries.map((entry) =>
      entry.id === id ? { ...entry, deletedAt: null, updatedAt: now } : entry
    );
    setEntries(next);
    saveJournals(next);
    void synchronize(next);
  };

  const permanentlyDeleteEntry = (id: string) => {
    if (!window.confirm("この記録を完全に削除しますか？この操作は取り消せません。")) return;
    const next = entries.filter((entry) => entry.id !== id);
    savePendingJournalDeletions([...loadPendingJournalDeletions(), id]);
    setEntries(next);
    saveJournals(next);
    void synchronize(next);
  };

  const usePrompt = (prompt: string) => {
    setText((current) => (current.trim() ? `${current}\n\n${prompt}` : prompt));
    window.requestAnimationFrame(() => composerRef.current?.focus());
  };

  return (
    <Screen title="ジャーナル" subtitle="言葉にしてみると、自分のペースが少しずつ見えてきます。">
      <div className="mb-4 grid gap-4 lg:grid-cols-[minmax(0,1.45fr)_minmax(310px,0.55fr)]">
        <WeekCalendar selectedDate={selectedDate} onSelect={setSelectedDate} markedDates={markedDates} />
        <section className="journal-glow relative overflow-hidden rounded-[22px] p-5 text-white shadow-card">
          <Sprout className="absolute -bottom-5 -right-3 text-white/10" size={112} strokeWidth={1.2} />
          <div className="relative">
            <div className="flex items-center gap-2 text-[12px] font-semibold text-white/70">
              <BookHeart size={15} />
              今週のリズム
            </div>
            <div className="mt-5 grid grid-cols-3 divide-x divide-white/15">
              <JournalStat value={journalStats.thisWeek} unit="件" label="今週" />
              <JournalStat value={journalStats.streak} unit="日" label="連続" />
              <JournalStat value={journalStats.total} unit="件" label="すべて" />
            </div>
          </div>
        </section>
      </div>

      <div className="mb-4 flex flex-wrap items-center justify-end gap-2">
        <span className={cn(
          "mr-auto text-[12px] font-medium",
          syncState === "error" ? "text-destructive" : "text-muted-foreground"
        )}>
          {syncMessage}
        </span>
        <Button variant="outline" size="sm" onClick={() => void synchronize(entries)} disabled={syncState === "syncing"}>
          <Cloud size={14} />
          {syncState === "syncing" ? "同期中" : "iOSと同期"}
        </Button>
        <Button variant="ghost" size="sm" onClick={() => setShowTrash((current) => !current)}>
          <Trash2 size={14} />
          ゴミ箱 {deletedEntries.length > 0 && `(${deletedEntries.length})`}
        </Button>
      </div>

      <div className="grid items-start gap-4 lg:grid-cols-[minmax(340px,0.82fr)_minmax(0,1.18fr)]">
        <Card className="lg:sticky lg:top-[84px]">
          <CardHeader className="items-start">
            <div>
              <CardTitle>
                <PenLine size={16} className="text-primary" />
                {dateLabel} の記録
              </CardTitle>
              <p className="mt-1.5 text-[12px] leading-relaxed text-muted-foreground">
                まとまっていなくても、そのままで大丈夫です。
              </p>
            </div>
            <Badge variant="muted" className="shrink-0 gap-1">
              <ShieldCheck size={11} />
              自動保存
            </Badge>
          </CardHeader>
          <CardContent className="mt-5 space-y-4">
            <div className="flex flex-wrap gap-2">
              {JOURNAL_PROMPTS.map((prompt) => (
                <button key={prompt} type="button" onClick={() => usePrompt(prompt)} className="prompt-chip">
                  {prompt}
                </button>
              ))}
            </div>
            <Field label="本文">
              <Textarea
                ref={composerRef}
                value={text}
                onChange={(event) => {
                  setText(event.target.value);
                  setSaveFeedback("");
                }}
                rows={9}
                placeholder="いま感じていることから、ゆっくり書いてみる…"
                className="min-h-[210px] text-[15px] leading-[1.85]"
              />
              <div className="mt-1.5 flex items-center justify-between px-0.5 text-[11px] text-muted-foreground">
                <span aria-live="polite" className={cn(saveFeedback && "font-semibold text-primary")}>
                  {saveFeedback || (text ? "下書きを保存しました" : "書いた内容はこの端末に保存されます")}
                </span>
                <span>{text.length} 文字</span>
              </div>
            </Field>
            <Field label="タグ（任意）">
              <Input
                value={tagText}
                onChange={(event) => setTagText(event.target.value)}
                placeholder="仕事、内省、体調"
              />
            </Field>
            <Button className="w-full" onClick={addEntry} disabled={!text.trim()}>
              <PenLine size={16} />
              {editingId ? "変更を保存" : "この日の記録に残す"}
            </Button>
            {editingId && (
              <Button
                variant="ghost"
                className="w-full"
                onClick={() => {
                  setEditingId(null);
                  setText("");
                  setTagText("");
                }}
              >
                編集をキャンセル
              </Button>
            )}
          </CardContent>
        </Card>

        <Card className="min-h-[420px]">
          <CardHeader className="flex-wrap">
            <div className="flex items-center gap-3">
              <CardTitle>
                <CalendarDays size={16} className="text-primary" />
                この日の記録
              </CardTitle>
              <Badge variant="muted">{activeEntries.length} 件</Badge>
            </div>
            <div className="relative w-full max-w-[200px]">
              <Search
                size={14}
                className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
              />
              <Input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="この日を検索"
                className="h-9 pl-8 text-[13px]"
              />
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {activeEntries.length === 0 ? (
              <div className="grid min-h-[300px] place-items-center rounded-2xl border border-dashed border-primary/20 bg-primary/[0.025] px-6 text-center">
                <div>
                  <div className="mx-auto grid h-12 w-12 place-items-center rounded-2xl bg-primary/10 text-primary">
                    <Leaf size={21} />
                  </div>
                  <div className="mt-4 font-rounded text-[15px] font-semibold">
                    {query ? "条件に合う記録がありません" : `${dateLabel} は、まだまっさらです`}
                  </div>
                  <p className="mx-auto mt-1.5 max-w-[300px] text-[13px] leading-relaxed text-muted-foreground">
                    {query
                      ? "検索する言葉を変えてみてください。"
                      : "短いひとことでも、あとから振り返る大切な手がかりになります。"}
                  </p>
                  {!query && (
                    <Button
                      variant="secondary"
                      size="sm"
                      className="mt-4"
                      onClick={() => composerRef.current?.focus()}
                    >
                      <PenLine size={14} />
                      書きはじめる
                    </Button>
                  )}
                </div>
              </div>
            ) : (
              activeEntries.map((entry) => (
                <article
                  key={entry.id}
                  className="group relative rounded-2xl border border-border/55 bg-white/55 p-4 transition-all hover:-translate-y-0.5 hover:bg-white/75 hover:shadow-card"
                >
                  <div className="flex items-center gap-1.5 text-[12px] font-medium text-muted-foreground">
                    <Clock3 size={12} className="text-primary/70" />
                    {formatTime(entry.date)}
                  </div>
                  <p className="mt-1.5 whitespace-pre-wrap text-[15px] leading-relaxed">
                    {entry.text}
                  </p>
                  {entry.tags.length > 0 && (
                    <div className="mt-3 flex flex-wrap gap-1.5">
                      {entry.tags.map((tag) => (
                        <Badge key={tag}>{tag}</Badge>
                      ))}
                    </div>
                  )}
                  <div className="absolute right-2 top-2 flex opacity-70 transition-all md:opacity-0 md:group-hover:opacity-100">
                    <button
                      onClick={() => editEntry(entry)}
                      className="grid h-8 w-8 place-items-center rounded-lg text-muted-foreground hover:bg-primary/10 hover:text-primary"
                      aria-label="編集"
                    >
                      <Pencil size={14} />
                    </button>
                    <button
                      onClick={() => deleteEntry(entry.id)}
                      className="grid h-8 w-8 place-items-center rounded-lg text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                      aria-label="削除"
                    >
                      <Trash2 size={15} />
                    </button>
                  </div>
                </article>
              ))
            )}
          </CardContent>
        </Card>
      </div>

      {showTrash && (
        <Card className="mt-4">
          <CardHeader>
            <CardTitle><Trash2 size={16} className="text-primary" />ジャーナルのゴミ箱</CardTitle>
            <Badge variant="muted">{deletedEntries.length} 件</Badge>
          </CardHeader>
          <CardContent className="space-y-2">
            {deletedEntries.length === 0 ? (
              <EmptyState text="削除した記録はありません" />
            ) : (
              deletedEntries.map((entry) => (
                <div key={entry.id} className="flex items-start gap-3 rounded-xl border border-border/50 bg-white/45 p-3">
                  <div className="min-w-0 flex-1">
                    <div className="line-clamp-2 text-[14px]">{entry.text || "削除済みの記録"}</div>
                    <div className="mt-1 text-[11px] text-muted-foreground">{formatDate(entry.date)}</div>
                  </div>
                  <Button variant="ghost" size="sm" onClick={() => restoreEntry(entry.id)}>
                    <RotateCcw size={14} />復元
                  </Button>
                  <Button variant="destructive-ghost" size="sm" onClick={() => permanentlyDeleteEntry(entry.id)}>
                    完全削除
                  </Button>
                </div>
              ))
            )}
          </CardContent>
        </Card>
      )}
    </Screen>
  );
}

function JournalStat({ value, unit, label }: { value: number; unit: string; label: string }) {
  return (
    <div className="px-2 text-center first:pl-0 last:pr-0">
      <div className="font-rounded text-[25px] font-bold tracking-[-0.04em]">
        {value}
        <span className="ml-0.5 text-[11px] font-semibold text-white/60">{unit}</span>
      </div>
      <div className="mt-0.5 text-[10px] font-semibold tracking-wide text-white/55">{label}</div>
    </div>
  );
}

function CoachView({ accessToken }: { accessToken: string }) {
  const [mode, setMode] = useState<"chat" | "mindfulness">("chat");
  const [sessions, setSessions] = useState<SessionSummary[]>([]);
  const [selectedSessionId, setSelectedSessionId] = useState<string | null>(null);
  const [selectedDiaryId, setSelectedDiaryId] = useState("");
  const [messages, setMessages] = useState<MessageData[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const diaryEntries = useMemo(
    () =>
      loadJournals()
        .filter((entry) => !entry.deletedAt && entry.text.trim())
        .sort((a, b) => Date.parse(b.date) - Date.parse(a.date)),
    []
  );
  const selectedDiary = diaryEntries.find((entry) => entry.id === selectedDiaryId);

  const reloadSessions = useCallback(async () => {
    try {
      const data = await listSessions(accessToken);
      setSessions(data.sessions);
    } catch (err) {
      setError(err instanceof Error ? err.message : "セッション取得に失敗しました");
    }
  }, [accessToken]);

  useEffect(() => {
    void reloadSessions();
  }, [reloadSessions]);

  const openSession = async (sessionId: string) => {
    setSelectedSessionId(sessionId);
    setError(null);
    try {
      const detail = await getSession(accessToken, sessionId);
      setMessages(detail.messages);
    } catch (err) {
      setError(err instanceof Error ? err.message : "セッションを開けませんでした");
    }
  };

  const removeSession = async (session: SessionSummary) => {
    if (!window.confirm(`「${session.title || "無題のセッション"}」を削除しますか？`)) return;
    try {
      await deleteSession(accessToken, session.sessionId);
      setSessions((current) => current.filter((item) => item.sessionId !== session.sessionId));
      if (selectedSessionId === session.sessionId) {
        setSelectedSessionId(null);
        setMessages([]);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "セッションを削除できませんでした");
    }
  };

  const send = async () => {
    const message = input.trim();
    if (!message) return;
    setLoading(true);
    setError(null);
    setInput("");
    const optimistic: MessageData = {
      messageId: crypto.randomUUID(),
      role: "user",
      content: message,
      createdAt: new Date().toISOString()
    };
    setMessages((current) => [...current, optimistic]);
    try {
      const assistantId = crypto.randomUUID();
      let assistantStarted = false;
      let streamError: string | null = null;
      await sendCoachMessageStream(
        accessToken,
        {
          message,
          sessionId: selectedSessionId,
          diaryContent: selectedDiary?.text ?? null
        },
        (event) => {
          if (event.type === "session") {
            setSelectedSessionId(event.sessionId);
          } else if (event.type === "chunk") {
            if (!assistantStarted) {
              assistantStarted = true;
              setMessages((current) => [
                ...current,
                {
                  messageId: assistantId,
                  role: "assistant",
                  content: event.chunk,
                  createdAt: new Date().toISOString()
                }
              ]);
            } else {
              setMessages((current) => current.map((item) =>
                item.messageId === assistantId
                  ? { ...item, content: `${item.content}${event.chunk}` }
                  : item
              ));
            }
          } else if (event.type === "error") {
            streamError = event.reason === "timeout"
              ? "応答がタイムアウトしました。もう一度お試しください"
              : "応答の生成中にエラーが発生しました";
          }
        }
      );
      if (streamError) throw new Error(streamError);
      await reloadSessions();
    } catch (err) {
      setError(err instanceof Error ? err.message : "送信に失敗しました");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Screen title="セッション" subtitle="考えをほどきながら、次の一歩を一緒に見つけます。">
      <div className="mb-4 inline-flex rounded-2xl border border-border/60 bg-white/45 p-1">
        <button
          onClick={() => setMode("chat")}
          className={cn(
            "flex items-center gap-2 rounded-xl px-4 py-2 text-[13px] font-semibold transition-colors",
            mode === "chat" ? "bg-primary text-white shadow-sm" : "text-muted-foreground hover:text-foreground"
          )}
        >
          <MessageCircle size={15} />対話
        </button>
        <button
          onClick={() => setMode("mindfulness")}
          className={cn(
            "flex items-center gap-2 rounded-xl px-4 py-2 text-[13px] font-semibold transition-colors",
            mode === "mindfulness" ? "bg-primary text-white shadow-sm" : "text-muted-foreground hover:text-foreground"
          )}
        >
          <Wind size={15} />呼吸・瞑想
        </button>
      </div>

      {mode === "mindfulness" ? <MindfulnessView /> : (
      <div className="grid gap-4 lg:grid-cols-[300px_minmax(0,1fr)]">
        <Card className="lg:sticky lg:top-24 lg:self-start">
          <CardHeader>
            <CardTitle>
              <MessageCircle size={16} className="text-primary" />
              履歴
            </CardTitle>
            <Button variant="ghost" size="icon" onClick={reloadSessions} aria-label="再読み込み">
              <RefreshCw size={16} />
            </Button>
          </CardHeader>
          <CardContent className="space-y-3">
            <Button
              variant="secondary"
              className="w-full"
              onClick={() => {
                setSelectedSessionId(null);
                setMessages([]);
              }}
            >
              <Plus size={16} />
              新しいセッション
            </Button>
            <ScrollArea className="max-h-[440px]">
              <div className="space-y-1 pr-1">
                {sessions.length === 0 ? (
                  <div className="py-6 text-center text-[13px] text-muted-foreground">
                    まだ履歴はありません
                  </div>
                ) : (
                  sessions.map((session) => {
                    const active = selectedSessionId === session.sessionId;
                    return (
                      <div
                        key={session.sessionId}
                        className={cn(
                          "group flex items-center rounded-xl transition-colors",
                          active
                            ? "bg-primary/10 text-primary-strong"
                            : "text-foreground hover:bg-primary/5"
                        )}
                      >
                        <button
                          onClick={() => void openSession(session.sessionId)}
                          className="min-w-0 flex-1 px-3 py-2.5 text-left"
                        >
                          <span className="block truncate text-[14px] font-semibold">
                            {session.title || "無題のセッション"}
                          </span>
                          <span className="block text-[11px] text-muted-foreground">
                            {session.messageCount ?? 0} 件のメッセージ
                          </span>
                        </button>
                        <button
                          onClick={() => void removeSession(session)}
                          className="mr-1 grid h-8 w-8 shrink-0 place-items-center rounded-lg text-muted-foreground opacity-50 hover:bg-destructive/10 hover:text-destructive md:opacity-0 md:group-hover:opacity-100"
                          aria-label="セッションを削除"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    );
                  })
                )}
              </div>
            </ScrollArea>
          </CardContent>
        </Card>

        <Card className="flex flex-col">
          <CardHeader>
            <CardTitle>
              <Sparkles size={16} className="text-primary" />
              {selectedSessionId ? "会話を続ける" : "新しい対話を始めよう"}
            </CardTitle>
          </CardHeader>
          <div className="mt-3 flex min-h-[420px] flex-1 flex-col">
            <div className="mb-3 rounded-xl border border-border/55 bg-primary/5 p-3">
              <label className="text-[12px] font-semibold text-muted-foreground" htmlFor="coach-diary">
                ジャーナルを会話の参考にする（任意）
              </label>
              <select
                id="coach-diary"
                value={selectedDiaryId}
                onChange={(event) => setSelectedDiaryId(event.target.value)}
                disabled={loading}
                className="mt-1.5 h-10 w-full rounded-xl border border-input bg-white/70 px-3 text-[13px] outline-none focus:ring-2 focus:ring-ring"
              >
                <option value="">参照しない</option>
                {diaryEntries.map((entry) => (
                  <option key={entry.id} value={entry.id}>
                    {new Intl.DateTimeFormat("ja-JP", { month: "short", day: "numeric" }).format(new Date(entry.date))}
                    {" — "}{entry.text.slice(0, 42)}
                  </option>
                ))}
              </select>
            </div>
            <ScrollArea className="scrollbar-thin flex-1">
              <div className="flex flex-col gap-3 pr-1">
                {messages.length === 0 ? (
                  <ConversationStarters
                    onPick={(prompt) => setInput(prompt)}
                    disabled={loading}
                  />
                ) : (
                  messages.map((message) => (
                    <div
                      key={message.messageId}
                      className={cn(
                        "max-w-[78%] px-4 py-3 text-[15px] leading-relaxed",
                        message.role === "user"
                          ? "chat-bubble-user self-end"
                          : "chat-bubble-assistant self-start"
                      )}
                    >
                      <div
                        className={cn(
                          "mb-1 text-[11px] font-bold uppercase tracking-widest",
                          message.role === "user"
                            ? "text-primary-foreground/70"
                            : "text-muted-foreground"
                        )}
                      >
                        {message.role === "user" ? "You" : "Cycle"}
                      </div>
                      <div className="whitespace-pre-wrap">{message.content}</div>
                    </div>
                  ))
                )}
                {loading && <TypingIndicator />}
              </div>
            </ScrollArea>

            {error && <ErrorBanner className="mt-3">{error}</ErrorBanner>}

            <div className="mt-3 flex flex-col gap-2 sm:flex-row sm:items-end">
              <Textarea
                value={input}
                onChange={(event) => setInput(event.target.value)}
                placeholder="いま考えていることを書く"
                rows={3}
                className="flex-1"
                onKeyDown={(event) => {
                  if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
                    event.preventDefault();
                    void send();
                  }
                }}
              />
              <Button onClick={send} disabled={loading} className="sm:w-28">
                {loading ? "送信中" : "送信"}
              </Button>
            </div>
          </div>
        </Card>
      </div>
      )}
    </Screen>
  );
}

function TasksView({ accessToken }: { accessToken: string }) {
  const [tasks, setTasks] = useState<TaskData[]>([]);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [intent, setIntent] = useState("");
  const [achievementVision, setAchievementVision] = useState("");
  const [notes, setNotes] = useState("");
  const [dueDate, setDueDate] = useState("");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [templates, setTemplates] = useState<TaskTemplate[]>([]);
  const [taskDetails, setTaskDetails] = useState<TaskLocalDetails[]>([]);
  const [query, setQuery] = useState("");
  const [showCompleted, setShowCompleted] = useState(true);
  const [reflectionTaskId, setReflectionTaskId] = useState<string | null>(null);
  const [reflectionFact, setReflectionFact] = useState("");
  const [reflectionInsight, setReflectionInsight] = useState("");
  const [reflectionNext, setReflectionNext] = useState("");
  const [reflectionFeedback, setReflectionFeedback] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await listTasks(accessToken);
      setTasks(data.tasks);
    } catch (err) {
      setError(err instanceof Error ? err.message : "タスク取得に失敗しました");
    } finally {
      setLoading(false);
    }
  }, [accessToken]);

  useEffect(() => {
    setTemplates(loadTaskTemplates());
    setTaskDetails(loadTaskDetails());
    void reload();
  }, [reload]);

  const resetComposer = () => {
    setTitle("");
    setDescription("");
    setIntent("");
    setAchievementVision("");
    setNotes("");
    setDueDate("");
    setEditingId(null);
  };

  const saveTask = async () => {
    if (!title.trim()) return;
    setError(null);
    try {
      const payload = {
        title: title.trim(),
        description: description.trim() || (editingId ? "" : undefined),
        dueDate: dueDate ? new Date(`${dueDate}T23:59:00`).toISOString() : null
      };
      if (editingId) {
        const task = await updateTask(accessToken, editingId, payload);
        setTasks((current) => current.map((item) => (item.taskId === editingId ? task : item)));
        saveLocalTaskDetails(editingId);
      } else {
        const task = await createTask(accessToken, payload);
        setTasks((current) => [task, ...current]);
        saveLocalTaskDetails(task.taskId);
      }
      resetComposer();
    } catch (err) {
      setError(err instanceof Error ? err.message : "タスクを保存できませんでした");
    }
  };

  const saveLocalTaskDetails = (taskId: string) => {
    const nextDetail: TaskLocalDetails = {
      taskId,
      intent: intent.trim(),
      achievementVision: achievementVision.trim(),
      notes: notes.trim(),
      updatedAt: new Date().toISOString()
    };
    const next = [nextDetail, ...taskDetails.filter((detail) => detail.taskId !== taskId)];
    setTaskDetails(next);
    saveTaskDetails(next);
  };

  const editTask = (task: TaskData) => {
    setEditingId(task.taskId);
    setTitle(task.title);
    setDescription(task.description ?? "");
    const detail = taskDetails.find((item) => item.taskId === task.taskId);
    setIntent(detail?.intent ?? "");
    setAchievementVision(detail?.achievementVision ?? "");
    setNotes(detail?.notes ?? "");
    setDueDate(task.dueDate ? toDateInputValue(new Date(task.dueDate)) : "");
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const saveAsTemplate = () => {
    if (!title.trim()) return;
    const next = [
      {
        id: crypto.randomUUID(),
        title: title.trim(),
        description: description.trim(),
        intent: intent.trim(),
        achievementVision: achievementVision.trim(),
        notes: notes.trim(),
        createdAt: new Date().toISOString()
      },
      ...templates
    ];
    setTemplates(next);
    saveTaskTemplates(next);
  };

  const applyTemplate = (template: TaskTemplate) => {
    setEditingId(null);
    setTitle(template.title);
    setDescription(template.description);
    setIntent(template.intent);
    setAchievementVision(template.achievementVision);
    setNotes(template.notes);
  };

  const removeTemplate = (templateId: string) => {
    const next = templates.filter((template) => template.id !== templateId);
    setTemplates(next);
    saveTaskTemplates(next);
  };

  const toggleTask = async (task: TaskData) => {
    const status = task.status === "completed" ? "pending" : "completed";
    try {
      const updated = await updateTask(accessToken, task.taskId, { status });
      setTasks((current) => current.map((item) => (item.taskId === task.taskId ? updated : item)));
      if (status === "completed") setReflectionTaskId(task.taskId);
      else if (reflectionTaskId === task.taskId) setReflectionTaskId(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "タスクを更新できませんでした");
    }
  };

  const removeTask = async (taskId: string) => {
    if (!window.confirm("このタスクを削除しますか？")) return;
    try {
      await deleteTask(accessToken, taskId);
      setTasks((current) => current.filter((task) => task.taskId !== taskId));
      const nextDetails = taskDetails.filter((detail) => detail.taskId !== taskId);
      setTaskDetails(nextDetails);
      saveTaskDetails(nextDetails);
    } catch (err) {
      setError(err instanceof Error ? err.message : "タスクを削除できませんでした");
    }
  };

  const saveReflection = async (taskId: string) => {
    if (!reflectionFact.trim() || !reflectionInsight.trim()) return;
    try {
      await createTaskReflection(accessToken, taskId, {
        whatIDid: reflectionFact.trim(),
        whatINoticed: reflectionInsight.trim(),
        whatIWantToTry: reflectionNext.trim() || null
      });
      setReflectionTaskId(null);
      setReflectionFact("");
      setReflectionInsight("");
      setReflectionNext("");
      setReflectionFeedback("振り返りを保存しました");
    } catch (err) {
      setError(err instanceof Error ? err.message : "振り返りを保存できませんでした");
    }
  };

  const filteredTasks = useMemo(() => {
    const needle = query.trim().toLowerCase();
    if (!needle) return tasks;
    return tasks.filter((task) => {
      const detail = taskDetails.find((item) => item.taskId === task.taskId);
      return `${task.title} ${task.description ?? ""} ${detail?.intent ?? ""} ${detail?.achievementVision ?? ""} ${detail?.notes ?? ""}`
        .toLowerCase()
        .includes(needle);
    });
  }, [query, taskDetails, tasks]);

  const pendingTasks = useMemo(
    () => filteredTasks.filter((t) => t.status !== "completed"),
    [filteredTasks]
  );
  const completedTasks = useMemo(
    () => filteredTasks.filter((t) => t.status === "completed"),
    [filteredTasks]
  );
  const pendingCount = pendingTasks.length;
  const doneCount = completedTasks.length;

  const renderTaskRow = (task: TaskData) => {
    const done = task.status === "completed";
    const detail = taskDetails.find((item) => item.taskId === task.taskId);
    return (
      <article
        key={task.taskId}
        className={cn(
          "group flex items-start gap-3 rounded-xl border border-border/50 bg-white/50 p-3.5 transition-all hover:shadow-card",
          done && "opacity-70"
        )}
      >
        <button
          onClick={() => void toggleTask(task)}
          className="mt-0.5 shrink-0 text-primary transition-transform active:scale-90"
          aria-label={done ? "未完了に戻す" : "完了にする"}
        >
          {done ? (
            <CheckCircle2 size={22} className="fill-primary/15 text-primary" />
          ) : (
            <Circle size={22} className="text-muted-foreground" />
          )}
        </button>
        <div className="min-w-0 flex-1">
          <div
            className={cn(
              "font-semibold text-[15px]",
              done && "line-through text-muted-foreground"
            )}
          >
            {task.title}
          </div>
          {task.description && (
            <p className="mt-1 whitespace-pre-wrap text-[13px] leading-relaxed text-muted-foreground">
              {task.description}
            </p>
          )}
          {detail && (detail.intent || detail.achievementVision || detail.notes) && (
            <div className="mt-2 grid gap-1 rounded-xl bg-primary/5 px-3 py-2 text-[12px] leading-relaxed text-muted-foreground">
              {detail.intent && <div><span className="font-semibold text-primary-strong">意図:</span> {detail.intent}</div>}
              {detail.achievementVision && <div><span className="font-semibold text-primary-strong">完了イメージ:</span> {detail.achievementVision}</div>}
              {detail.notes && <div><span className="font-semibold text-primary-strong">注意点:</span> {detail.notes}</div>}
            </div>
          )}
          <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-[11px] text-muted-foreground">
            <span>{formatDate(task.createdAt)}</span>
            {task.dueDate && (
              <span className="inline-flex items-center gap-1 font-medium text-primary-strong">
                <Clock3 size={11} />期限 {formatDay(task.dueDate)}
              </span>
            )}
          </div>
          {done && reflectionTaskId === task.taskId && (
            <div className="mt-3 space-y-2 rounded-xl border border-primary/20 bg-primary/5 p-3">
              <div className="text-[12px] font-semibold text-primary-strong">完了後の振り返り</div>
              <Textarea
                value={reflectionFact}
                onChange={(event) => setReflectionFact(event.target.value)}
                rows={2}
                placeholder="実際にやったこと"
              />
              <Textarea
                value={reflectionInsight}
                onChange={(event) => setReflectionInsight(event.target.value)}
                rows={2}
                placeholder="気づいたこと"
              />
              <Textarea
                value={reflectionNext}
                onChange={(event) => setReflectionNext(event.target.value)}
                rows={2}
                placeholder="次に試したいこと（任意）"
              />
              <div className="flex justify-end gap-2">
                <Button variant="ghost" size="sm" onClick={() => setReflectionTaskId(null)}>キャンセル</Button>
                <Button
                  size="sm"
                  onClick={() => void saveReflection(task.taskId)}
                  disabled={!reflectionFact.trim() || !reflectionInsight.trim()}
                >
                  保存
                </Button>
              </div>
            </div>
          )}
        </div>
        <div className="flex shrink-0 gap-1 opacity-60 transition-opacity md:opacity-0 md:group-hover:opacity-100">
          {done && (
            <button
              onClick={() => setReflectionTaskId((current) => current === task.taskId ? null : task.taskId)}
              className="grid h-8 w-8 place-items-center rounded-lg text-muted-foreground hover:bg-primary/10 hover:text-primary"
              aria-label="振り返りを書く"
            >
              <BookHeart size={15} />
            </button>
          )}
          <button
            onClick={() => editTask(task)}
            className="grid h-8 w-8 place-items-center rounded-lg text-muted-foreground hover:bg-primary/10 hover:text-primary"
            aria-label="編集"
          >
            <Pencil size={15} />
          </button>
          <button
            onClick={() => void removeTask(task.taskId)}
            className="grid h-8 w-8 place-items-center rounded-lg text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
            aria-label="削除"
          >
            <Trash2 size={15} />
          </button>
        </div>
      </article>
    );
  };

  return (
    <Screen title="タスクリスト" subtitle="やることを小さく整えて、今日の一歩に集中しましょう。">
      <div className="grid gap-4 lg:grid-cols-[minmax(280px,0.55fr)_minmax(0,1.45fr)]">
        <Card>
          <CardHeader>
            <CardTitle>
              {editingId ? <Pencil size={16} className="text-primary" /> : <Plus size={16} className="text-primary" />}
              {editingId ? "タスク編集" : "タスク作成"}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {templates.length > 0 && !editingId && (
              <div>
                <div className="mb-2 text-[12px] font-semibold text-muted-foreground">テンプレート</div>
                <div className="flex flex-wrap gap-2">
                  {templates.map((template) => (
                    <div key={template.id} className="group/template inline-flex overflow-hidden rounded-full bg-primary/8 ring-1 ring-inset ring-primary/20">
                      <button
                        type="button"
                        onClick={() => applyTemplate(template)}
                        className="px-3 py-1.5 text-[12px] font-semibold text-primary-strong hover:bg-primary/10"
                      >
                        {template.title}
                      </button>
                      <button
                        type="button"
                        onClick={() => removeTemplate(template.id)}
                        className="px-2 text-primary/60 hover:bg-destructive/10 hover:text-destructive"
                        aria-label={`${template.title}のテンプレートを削除`}
                      >
                        ×
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}
            <Field label="タイトル">
              <Input value={title} onChange={(event) => setTitle(event.target.value)} />
            </Field>
            <Field label="メモ">
              <Textarea
                value={description}
                onChange={(event) => setDescription(event.target.value)}
                rows={5}
              />
            </Field>
            <div className="rounded-2xl border border-border/55 bg-primary/5 p-3.5">
              <div className="mb-3 text-[12px] font-semibold text-primary-strong">実行前に整える（任意）</div>
              <div className="space-y-3">
                <Field label="意図">
                  <Textarea
                    value={intent}
                    onChange={(event) => setIntent(event.target.value)}
                    rows={2}
                    placeholder="なぜ取り組むのか"
                  />
                </Field>
                <Field label="完了イメージ">
                  <Textarea
                    value={achievementVision}
                    onChange={(event) => setAchievementVision(event.target.value)}
                    rows={2}
                    placeholder="どんな状態になれば完了か"
                  />
                </Field>
                <Field label="注意点">
                  <Textarea
                    value={notes}
                    onChange={(event) => setNotes(event.target.value)}
                    rows={2}
                    placeholder="気をつけたいこと"
                  />
                </Field>
              </div>
            </div>
            <Field label="期限（任意）">
              <Input type="date" value={dueDate} onChange={(event) => setDueDate(event.target.value)} />
            </Field>
            <Button className="w-full" onClick={saveTask} disabled={!title.trim()}>
              {editingId ? "変更を保存" : "追加"}
            </Button>
            <div className="grid grid-cols-2 gap-2">
              <Button variant="outline" onClick={saveAsTemplate} disabled={!title.trim()}>
                テンプレート保存
              </Button>
              <Button variant="ghost" onClick={resetComposer} disabled={!editingId && !title && !description && !intent && !achievementVision && !notes && !dueDate}>
                {editingId ? "編集を中止" : "クリア"}
              </Button>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>
              <CheckSquare size={16} className="text-primary" />
              タスク一覧
            </CardTitle>
            <div className="flex items-center gap-2">
              <div className="relative w-[170px]">
                <Search size={13} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
                <Input
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  placeholder="タスクを検索"
                  className="pl-8"
                />
              </div>
              <Button variant="ghost" size="icon" onClick={reload} aria-label="再読み込み">
                <RefreshCw size={16} />
              </Button>
            </div>
          </CardHeader>
          <CardContent className="space-y-5">
            {error && <ErrorBanner>{error}</ErrorBanner>}
            {reflectionFeedback && (
              <div className="rounded-xl bg-primary/10 px-3 py-2.5 text-[13px] font-medium text-primary-strong">
                {reflectionFeedback}
              </div>
            )}
            {loading && tasks.length === 0 ? (
              <EmptyState text="読み込み中" />
            ) : tasks.length === 0 ? (
              <EmptyState text="まだタスクはありません" />
            ) : (
              <>
                <TaskSection title="未完了" count={pendingCount}>
                  {pendingTasks.length === 0 ? (
                    <div className="rounded-xl border border-dashed border-border/70 px-4 py-6 text-center text-[13px] text-muted-foreground">
                      すべて完了しています
                    </div>
                  ) : (
                    <div className="space-y-2">{pendingTasks.map(renderTaskRow)}</div>
                  )}
                </TaskSection>
                {completedTasks.length > 0 && (
                  <section>
                    <button
                      type="button"
                      onClick={() => setShowCompleted((current) => !current)}
                      className="mb-2 flex items-center gap-2 px-0.5"
                    >
                      <span className="font-rounded text-[13px] font-bold uppercase tracking-widest text-muted-foreground">
                        完了
                      </span>
                      <Badge variant="muted">{doneCount}</Badge>
                      <span className="text-[11px] text-muted-foreground">{showCompleted ? "閉じる" : "開く"}</span>
                    </button>
                    {showCompleted && <div className="space-y-2">{completedTasks.map(renderTaskRow)}</div>}
                  </section>
                )}
              </>
            )}
          </CardContent>
        </Card>
      </div>
    </Screen>
  );
}

const CONVERSATION_STARTERS = [
  "最近の気持ちを整理したい",
  "今日うまくいったことを振り返る",
  "行き詰まっていることを話す",
  "次の一歩を一緒に決めたい"
];

function ConversationStarters({
  onPick,
  disabled
}: {
  onPick: (prompt: string) => void;
  disabled?: boolean;
}) {
  return (
    <div className="grid place-items-center gap-5 py-8 text-center">
      <Image
        src="/cycle-icon.png"
        alt=""
        width={112}
        height={112}
        className="h-28 w-28 rounded-full shadow-[0_20px_46px_-22px_rgba(89,71,56,0.65)]"
      />
      <div>
        <div className="font-rounded text-[17px] font-semibold">今日はどんな話をしますか？</div>
        <p className="mt-1 text-[13px] text-muted-foreground">
          気になっていることをそのまま書いても、下のヒントから始めても大丈夫です。
        </p>
      </div>
      <div className="flex flex-wrap justify-center gap-2">
        {CONVERSATION_STARTERS.map((prompt) => (
          <button
            key={prompt}
            onClick={() => onPick(prompt)}
            disabled={disabled}
            className="rounded-full bg-primary/8 px-4 py-2 text-[13px] font-medium text-primary-strong ring-1 ring-inset ring-primary/25 transition-all hover:bg-primary/15 active:scale-95 disabled:opacity-50"
          >
            {prompt}
          </button>
        ))}
      </div>
    </div>
  );
}

function TypingIndicator() {
  return (
    <div className="chat-bubble-assistant flex max-w-[78%] items-center gap-1.5 self-start px-4 py-3.5">
      <span className="typing-dot" style={{ animationDelay: "0ms" }} />
      <span className="typing-dot" style={{ animationDelay: "150ms" }} />
      <span className="typing-dot" style={{ animationDelay: "300ms" }} />
    </div>
  );
}

function TaskSection({
  title,
  count,
  muted,
  children
}: {
  title: string;
  count: number;
  muted?: boolean;
  children: React.ReactNode;
}) {
  return (
    <section>
      <div className="mb-2 flex items-center gap-2 px-0.5">
        <h2
          className={cn(
            "font-rounded text-[13px] font-bold uppercase tracking-widest",
            muted ? "text-muted-foreground" : "text-foreground"
          )}
        >
          {title}
        </h2>
        <Badge variant={muted ? "muted" : "default"}>{count}</Badge>
      </div>
      {children}
    </section>
  );
}

function SettingsView({
  tokens,
  onAuth
}: {
  tokens: AuthTokens;
  onAuth: (tokens: AuthTokens | null) => void;
}) {
  const [profile, setProfile] = useState<UserData | null>(null);
  const [preferences, setPreferences] = useState<WebPreferences>(() => loadWebPreferences());
  const [notificationPermission, setNotificationPermission] = useState<NotificationPermission | "unsupported">("default");
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (typeof Notification === "undefined") setNotificationPermission("unsupported");
    else setNotificationPermission(Notification.permission);
    void getMe(tokens.accessToken)
      .then(setProfile)
      .catch((cause) => setError(cause instanceof Error ? cause.message : "プロフィールを取得できませんでした"));
  }, [tokens.accessToken]);

  const signOut = async () => {
    if (tokens.refreshToken) {
      await logout(tokens.refreshToken).catch(() => undefined);
    }
    clearLocalUserData();
    onAuth(null);
  };

  const toggleNotifications = async () => {
    if (typeof Notification === "undefined") {
      setError("このブラウザは通知に対応していません");
      return;
    }
    if (preferences.notificationEnabled) {
      const next = { ...preferences, notificationEnabled: false };
      setPreferences(next);
      saveWebPreferences(next);
      return;
    }

    const permission = await Notification.requestPermission();
    setNotificationPermission(permission);
    if (permission !== "granted") {
      setError("ブラウザの設定で通知を許可してください");
      return;
    }
    const next = { ...preferences, notificationEnabled: true };
    setPreferences(next);
    saveWebPreferences(next);
    new Notification("Cycle", { body: "毎日の振り返りをお知らせします。" });
  };

  const changeReminderTime = (reminderTime: string) => {
    const next = { ...preferences, reminderTime };
    setPreferences(next);
    saveWebPreferences(next);
  };

  const removeAccount = async () => {
    const confirmed = window.confirm(
      "Cycleのアカウントと、サーバー上のジャーナル・セッション・タスクを完全に削除します。この操作は取り消せません。"
    );
    if (!confirmed) return;
    setDeleting(true);
    setError(null);
    try {
      await deleteMe(tokens.accessToken);
      clearLocalUserData();
      onAuth(null);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "アカウントを削除できませんでした");
      setDeleting(false);
    }
  };

  return (
    <Screen title="マイページ" subtitle="Cycle をあなたらしく使うための設定です。">
      <div className="max-w-[720px] space-y-4">
        {error && <ErrorBanner>{error}</ErrorBanner>}
        <Card className="p-0">
          <SettingsRow
            icon={<User size={18} />}
            title={profile?.displayName || "プロフィール"}
            description={profile?.email || (profile ? `利用開始 ${formatDay(profile.createdAt)}` : "読み込み中…")}
            trailing={profile && <Badge variant="muted">ログイン中</Badge>}
          />
          <Separator />
          <SettingsRow
            icon={<WalletCards size={18} />}
            title="ベーシックプラン"
            description="現在の機能を無料で利用できます。"
            trailing={<Badge variant="success">Free</Badge>}
          />
          <Separator />
          <SettingsRow
            icon={<Sparkles size={18} />}
            title="接続状態"
            description={profile ? "Cycle のサービスに接続されています。" : error ? "接続を確認できませんでした。" : "接続を確認しています。"}
            trailing={
              <Badge variant={profile ? "success" : "muted"}>
                {profile && <Check size={11} className="mr-1" />}
                {profile ? "接続済み" : error ? "未確認" : "確認中"}
              </Badge>
            }
          />
        </Card>

        <Card>
          <div className="flex items-start gap-4">
            <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-primary/10 text-primary">
              <Bell size={18} />
            </div>
            <div className="min-w-0 flex-1">
              <div className="font-rounded text-[15px] font-semibold">毎日のリマインダー</div>
              <p className="mt-1 text-[13px] leading-relaxed text-muted-foreground">
                Webアプリを開いている間、指定時刻に振り返りをお知らせします。
              </p>
              <div className="mt-4 flex flex-wrap items-center gap-3">
                <Button
                  variant={preferences.notificationEnabled ? "secondary" : "outline"}
                  onClick={() => void toggleNotifications()}
                  disabled={notificationPermission === "unsupported"}
                >
                  {preferences.notificationEnabled ? "通知をオフにする" : "通知をオンにする"}
                </Button>
                <Input
                  type="time"
                  value={preferences.reminderTime}
                  onChange={(event) => changeReminderTime(event.target.value)}
                  disabled={!preferences.notificationEnabled}
                  className="w-[130px]"
                  aria-label="リマインダー時刻"
                />
                <Badge variant={notificationPermission === "granted" ? "success" : "muted"}>
                  {notificationPermission === "granted" ? "許可済み" : notificationPermission === "unsupported" ? "非対応" : "未許可"}
                </Badge>
              </div>
            </div>
          </div>
        </Card>

        <Card>
          <div className="mb-5 flex flex-wrap items-center justify-center gap-x-5 gap-y-2 text-[13px] text-muted-foreground">
            <a className="hover:text-foreground hover:underline" href={PRIVACY_URL} target="_blank" rel="noreferrer">
              プライバシーポリシー
            </a>
            <a className="hover:text-foreground hover:underline" href={TERMS_URL} target="_blank" rel="noreferrer">
              利用規約
            </a>
          </div>
          <Button variant="destructive-ghost" className="w-full justify-center" onClick={signOut}>
            <LogOut size={16} />
            サインアウト
          </Button>
        </Card>

        <Card className="border-destructive/20">
          <div className="font-rounded text-[15px] font-semibold text-destructive">アカウントの削除</div>
          <p className="mt-1 text-[13px] leading-relaxed text-muted-foreground">
            サーバーとこのブラウザに保存されたCycleのデータを完全に削除します。
          </p>
          <Button
            variant="destructive-ghost"
            className="mt-4 w-full justify-center"
            onClick={() => void removeAccount()}
            disabled={deleting}
          >
            <Trash2 size={16} />
            {deleting ? "削除中…" : "アカウントを削除"}
          </Button>
        </Card>
      </div>
    </Screen>
  );
}

function SettingsRow({
  icon,
  title,
  description,
  trailing
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
  trailing?: React.ReactNode;
}) {
  return (
    <div className="flex items-center gap-4 p-5">
      <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-primary/10 text-primary">
        {icon}
      </div>
      <div className="min-w-0 flex-1">
        <div className="font-rounded text-[15px] font-semibold">{title}</div>
        <div className="mt-0.5 truncate text-[13px] text-muted-foreground">{description}</div>
      </div>
      {trailing}
    </div>
  );
}

function Screen({
  title,
  subtitle,
  children
}: {
  title: string;
  subtitle: string;
  children: React.ReactNode;
}) {
  return (
    <>
      <header className="mb-7">
        <h1 className="font-rounded text-[32px] font-bold tracking-[-0.035em] md:text-[34px]">{title}</h1>
        <p className="mt-1.5 text-[14px] text-muted-foreground">{subtitle}</p>
      </header>
      {children}
    </>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-[12px] font-semibold text-muted-foreground">{label}</span>
      {children}
    </label>
  );
}

function EmptyState({ text, tall }: { text: string; tall?: boolean }) {
  return (
    <div
      className={cn(
        "grid place-items-center rounded-xl border border-dashed border-border/70 text-[13px] text-muted-foreground",
        tall ? "min-h-[280px]" : "min-h-[160px]"
      )}
    >
      {text}
    </div>
  );
}

function ErrorBanner({
  children,
  className
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "rounded-xl bg-destructive/10 px-3 py-2.5 text-[13px] font-medium text-destructive",
        className
      )}
    >
      {children}
    </div>
  );
}

function normalizeJournalEntry(entry: JournalEntry): JournalEntry {
  const createdAt = entry.createdAt ?? entry.date;
  return {
    ...entry,
    tags: entry.tags ?? [],
    createdAt,
    updatedAt: entry.updatedAt ?? entry.deletedAt ?? createdAt
  };
}

function mergeJournalEntries(local: JournalEntry[], remote: JournalData[]): JournalEntry[] {
  const merged = new Map(
    local.map((entry) => {
      const normalized = normalizeJournalEntry(entry);
      return [normalized.id, normalized] as const;
    })
  );

  for (const journal of remote) {
    const incoming: JournalEntry = {
      id: journal.journalId,
      text: journal.text,
      tags: journal.tags ?? [],
      date: journal.entryDate,
      deletedAt: journal.deletedAt ?? null,
      createdAt: journal.createdAt,
      updatedAt: journal.updatedAt
    };
    const current = merged.get(incoming.id);
    if (!current || journalTimestamp(incoming) >= journalTimestamp(current)) {
      merged.set(incoming.id, incoming);
    }
  }

  return [...merged.values()].sort((a, b) => Date.parse(b.date) - Date.parse(a.date));
}

function journalTimestamp(entry: JournalEntry): number {
  const value = entry.updatedAt ?? entry.deletedAt ?? entry.createdAt ?? entry.date;
  const timestamp = Date.parse(value);
  return Number.isNaN(timestamp) ? 0 : timestamp;
}

function formatDate(value: string): string {
  return new Intl.DateTimeFormat("ja-JP", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

function formatDay(value: string): string {
  return new Intl.DateTimeFormat("ja-JP", {
    year: "numeric",
    month: "short",
    day: "numeric"
  }).format(new Date(value));
}

function toDateInputValue(date: Date): string {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

function formatTime(value: string): string {
  return new Intl.DateTimeFormat("ja-JP", {
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

interface GoogleCredentialResponse {
  credential: string;
}

interface GoogleWindow {
  google?: {
    accounts: {
      id: {
        initialize(options: {
          client_id: string;
          callback: (response: GoogleCredentialResponse) => void;
        }): void;
        renderButton(
          element: HTMLElement | null,
          options: { theme: string; size: string; width: number; text: string }
        ): void;
      };
    };
  };
}
