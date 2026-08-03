"use client";

import {
  Check,
  CheckCircle2,
  CheckSquare,
  Circle,
  Leaf,
  LogOut,
  MessageCircle,
  Plus,
  RefreshCw,
  Search,
  Settings,
  Sparkles,
  Trash2,
  TreePine,
  User,
  WalletCards
} from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  API_BASE_URL,
  createTask,
  deleteTask,
  getSession,
  listSessions,
  listTasks,
  logout,
  sendCoachMessage,
  updateTask,
  verifyGoogle
} from "@/lib/api";
import { loadAuth, loadJournals, saveAuth, saveJournals } from "@/lib/storage";
import type { AuthTokens, JournalEntry, MessageData, SessionSummary, TaskData } from "@/types/api";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Separator } from "@/components/ui/separator";
import { WeekCalendar, toDateKey } from "@/components/ui/week-calendar";

type Tab = "journal" | "coach" | "tasks" | "settings";

const tabs: { id: Tab; label: string; icon: React.ComponentType<{ size?: number; className?: string }> }[] = [
  { id: "journal", label: "ジャーナル", icon: Leaf },
  { id: "coach", label: "セッション", icon: MessageCircle },
  { id: "tasks", label: "タスク", icon: CheckSquare },
  { id: "settings", label: "設定", icon: Settings }
];

export default function Home() {
  const [tokens, setTokens] = useState<AuthTokens | null>(null);
  const [activeTab, setActiveTab] = useState<Tab>("journal");

  useEffect(() => {
    setTokens(loadAuth());
  }, []);

  const handleAuth = (next: AuthTokens | null) => {
    saveAuth(next);
    setTokens(next);
  };

  if (!tokens) {
    return <SignInView onAuth={handleAuth} />;
  }

  return (
    <main className="relative mx-auto grid min-h-dvh max-w-[1180px] grid-rows-[auto_minmax(0,1fr)_auto]">
      <header className="sticky top-0 z-10 flex items-center justify-between border-b border-border/60 bg-background/70 px-5 py-3 backdrop-blur-xl">
        <div className="flex items-center gap-3">
          <div className="brand-gradient grid h-10 w-10 place-items-center rounded-xl text-white shadow-soft">
            <TreePine size={20} />
          </div>
          <div>
            <div className="font-rounded text-[17px] font-semibold leading-tight">Cycle</div>
            <div className="text-[12px] text-muted-foreground">自分と向き合う日記アプリ</div>
          </div>
        </div>
        <Badge variant="outline" className="hidden sm:inline-flex">MVP</Badge>
      </header>

      <section className="min-w-0 px-4 pb-24 pt-4 md:px-6">
        <div key={activeTab} className="animate-fade-in-up">
          {activeTab === "journal" && <JournalView />}
          {activeTab === "coach" && <CoachView accessToken={tokens.accessToken} />}
          {activeTab === "tasks" && <TasksView accessToken={tokens.accessToken} />}
          {activeTab === "settings" && <SettingsView tokens={tokens} onAuth={handleAuth} />}
        </div>
      </section>

      <nav className="fixed inset-x-0 bottom-0 z-20 mx-auto max-w-[1180px] border-t border-border/60 bg-background/80 backdrop-blur-xl">
        <div className="mx-auto grid max-w-[680px] grid-cols-4">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const active = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={cn(
                  "relative flex h-[62px] flex-col items-center justify-center gap-1 text-[10px] font-semibold transition-colors",
                  active ? "text-primary-strong" : "text-muted-foreground hover:text-foreground",
                  active && "tab-pill-active"
                )}
                aria-current={active ? "page" : undefined}
              >
                <Icon size={20} className={cn("transition-transform", active && "scale-110")} />
                <span>{tab.label}</span>
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
  const googleClientId = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;

  useEffect(() => {
    if (!googleClientId) return;
    const script = document.createElement("script");
    script.src = "https://accounts.google.com/gsi/client";
    script.async = true;
    script.defer = true;
    script.onload = () => {
      const google = (window as unknown as GoogleWindow).google;
      google?.accounts.id.initialize({
        client_id: googleClientId,
        callback: async (response) => {
          try {
            const auth = await verifyGoogle(response.credential);
            onAuth({ accessToken: auth.accessToken, refreshToken: auth.refreshToken });
          } catch (err) {
            setError(err instanceof Error ? err.message : "Googleログインに失敗しました");
          }
        }
      });
      google?.accounts.id.renderButton(document.getElementById("google-signin"), {
        theme: "outline",
        size: "large",
        width: 260,
        text: "signin_with"
      });
    };
    document.head.appendChild(script);
    return () => {
      script.remove();
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
          <div className="brand-gradient mb-5 grid h-[104px] w-[104px] place-items-center rounded-full text-white shadow-[0_20px_50px_-12px_rgba(89,71,56,0.35)]">
            <TreePine size={48} />
          </div>
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

            {error && <ErrorBanner>{error}</ErrorBanner>}

            <Button className="mt-5 w-full" onClick={submitManual}>
              開発用トークンで入る
            </Button>

            <div className="mt-5 flex items-center justify-center">
              <Badge variant="muted" className="text-[11px] font-medium">
                API: {API_BASE_URL}
              </Badge>
            </div>
          </div>
        </Card>
      </div>
    </main>
  );
}

function JournalView() {
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  const [text, setText] = useState("");
  const [tagText, setTagText] = useState("");
  const [query, setQuery] = useState("");
  const [selectedDate, setSelectedDate] = useState<Date>(() => {
    const now = new Date();
    now.setHours(0, 0, 0, 0);
    return now;
  });

  useEffect(() => {
    setEntries(loadJournals());
  }, []);

  const markedDates = useMemo(() => {
    const keys = new Set<string>();
    for (const entry of entries) {
      if (entry.deletedAt) continue;
      keys.add(toDateKey(new Date(entry.date)));
    }
    return keys;
  }, [entries]);

  const selectedDateKey = toDateKey(selectedDate);

  const activeEntries = useMemo(() => {
    return entries
      .filter((entry) => !entry.deletedAt)
      .filter((entry) => toDateKey(new Date(entry.date)) === selectedDateKey)
      .filter((entry) => {
        if (!query.trim()) return true;
        const target = `${entry.text} ${entry.tags.join(" ")}`.toLowerCase();
        return target.includes(query.toLowerCase());
      })
      .sort((a, b) => Date.parse(b.date) - Date.parse(a.date));
  }, [entries, query, selectedDateKey]);

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
    const entryDate = new Date(selectedDate);
    entryDate.setHours(now.getHours(), now.getMinutes(), now.getSeconds());
    const next = [
      {
        id: crypto.randomUUID(),
        text: trimmed,
        tags: tagText
          .split(",")
          .map((tag) => tag.trim())
          .filter(Boolean),
        date: entryDate.toISOString()
      },
      ...entries
    ];
    setEntries(next);
    saveJournals(next);
    setText("");
    setTagText("");
  };

  const deleteEntry = (id: string) => {
    const next = entries.map((entry) =>
      entry.id === id ? { ...entry, deletedAt: new Date().toISOString() } : entry
    );
    setEntries(next);
    saveJournals(next);
  };

  return (
    <Screen title="ジャーナル" subtitle="Web MVP ではブラウザ内に保存します。同期は次フェーズです。">
      <div className="mb-4">
        <WeekCalendar selectedDate={selectedDate} onSelect={setSelectedDate} markedDates={markedDates} />
      </div>
      <div className="grid gap-4 lg:grid-cols-[minmax(320px,0.85fr)_minmax(0,1.15fr)]">
        <Card>
          <CardHeader>
            <CardTitle>
              <Plus size={16} className="text-primary" />
              新しい記録
            </CardTitle>
          </CardHeader>
          <CardContent className="mt-4 space-y-4">
            <Field label="本文">
              <Textarea
                value={text}
                onChange={(event) => setText(event.target.value)}
                rows={8}
                placeholder="今日の出来事、気づき、次に試したいこと"
              />
            </Field>
            <Field label="タグ">
              <Input
                value={tagText}
                onChange={(event) => setTagText(event.target.value)}
                placeholder="仕事, 内省, 体調"
              />
            </Field>
            <Button className="w-full" onClick={addEntry}>
              保存
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div className="flex items-center gap-3">
              <CardTitle>
                <Search size={16} className="text-primary" />
                {dateLabel}
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
              <EmptyState text={`${dateLabel} の記録はありません`} />
            ) : (
              activeEntries.map((entry) => (
                <article
                  key={entry.id}
                  className="group relative rounded-xl border border-border/60 bg-white/60 p-4 transition-shadow hover:shadow-card"
                >
                  <div className="text-[12px] font-medium text-muted-foreground">
                    {formatDate(entry.date)}
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
                  <button
                    onClick={() => deleteEntry(entry.id)}
                    className="absolute right-2 top-2 grid h-8 w-8 place-items-center rounded-lg text-muted-foreground opacity-0 transition-all hover:bg-destructive/10 hover:text-destructive group-hover:opacity-100"
                    aria-label="削除"
                  >
                    <Trash2 size={15} />
                  </button>
                </article>
              ))
            )}
          </CardContent>
        </Card>
      </div>
    </Screen>
  );
}

function CoachView({ accessToken }: { accessToken: string }) {
  const [sessions, setSessions] = useState<SessionSummary[]>([]);
  const [selectedSessionId, setSelectedSessionId] = useState<string | null>(null);
  const [messages, setMessages] = useState<MessageData[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
    const detail = await getSession(accessToken, sessionId);
    setMessages(detail.messages);
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
      const response = await sendCoachMessage(accessToken, {
        message,
        sessionId: selectedSessionId
      });
      setSelectedSessionId(response.sessionId ?? selectedSessionId);
      setMessages((current) => [
        ...current,
        {
          messageId: crypto.randomUUID(),
          role: "assistant",
          content: response.message,
          createdAt: new Date().toISOString()
        }
      ]);
      await reloadSessions();
    } catch (err) {
      setError(err instanceof Error ? err.message : "送信に失敗しました");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Screen title="セッション" subtitle="既存の /coach と /sessions API に接続しています。">
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
                      <button
                        key={session.sessionId}
                        onClick={() => void openSession(session.sessionId)}
                        className={cn(
                          "flex w-full flex-col gap-0.5 rounded-xl px-3 py-2.5 text-left transition-colors",
                          active
                            ? "bg-primary/10 text-primary-strong"
                            : "text-foreground hover:bg-primary/5"
                        )}
                      >
                        <span className="line-clamp-1 text-[14px] font-semibold">
                          {session.title || "無題のセッション"}
                        </span>
                        <span className="text-[11px] text-muted-foreground">
                          {session.messageCount ?? 0} messages
                        </span>
                      </button>
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
    </Screen>
  );
}

function TasksView({ accessToken }: { accessToken: string }) {
  const [tasks, setTasks] = useState<TaskData[]>([]);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
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
    void reload();
  }, [reload]);

  const addTask = async () => {
    if (!title.trim()) return;
    const task = await createTask(accessToken, {
      title: title.trim(),
      description: description.trim() || undefined
    });
    setTasks((current) => [task, ...current]);
    setTitle("");
    setDescription("");
  };

  const toggleTask = async (task: TaskData) => {
    const status = task.status === "completed" ? "pending" : "completed";
    const updated = await updateTask(accessToken, task.taskId, { status });
    setTasks((current) => current.map((item) => (item.taskId === task.taskId ? updated : item)));
  };

  const removeTask = async (taskId: string) => {
    await deleteTask(accessToken, taskId);
    setTasks((current) => current.filter((task) => task.taskId !== taskId));
  };

  const pendingTasks = useMemo(
    () => tasks.filter((t) => t.status !== "completed"),
    [tasks]
  );
  const completedTasks = useMemo(
    () => tasks.filter((t) => t.status === "completed"),
    [tasks]
  );
  const pendingCount = pendingTasks.length;
  const doneCount = completedTasks.length;

  const renderTaskRow = (task: TaskData) => {
    const done = task.status === "completed";
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
          <div className="mt-2 text-[11px] text-muted-foreground">
            {formatDate(task.createdAt)}
          </div>
        </div>
        <button
          onClick={() => void removeTask(task.taskId)}
          className="grid h-8 w-8 shrink-0 place-items-center rounded-lg text-muted-foreground opacity-0 transition-all hover:bg-destructive/10 hover:text-destructive group-hover:opacity-100"
          aria-label="削除"
        >
          <Trash2 size={15} />
        </button>
      </article>
    );
  };

  return (
    <Screen title="タスク" subtitle="既存の /tasks API に接続しています。">
      <div className="grid gap-4 lg:grid-cols-[minmax(280px,0.55fr)_minmax(0,1.45fr)]">
        <Card>
          <CardHeader>
            <CardTitle>
              <Plus size={16} className="text-primary" />
              タスク作成
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
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
            <Button className="w-full" onClick={addTask}>
              追加
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>
              <CheckSquare size={16} className="text-primary" />
              タスク一覧
            </CardTitle>
            <Button variant="ghost" size="icon" onClick={reload} aria-label="再読み込み">
              <RefreshCw size={16} />
            </Button>
          </CardHeader>
          <CardContent className="space-y-5">
            {error && <ErrorBanner>{error}</ErrorBanner>}
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
                  <TaskSection title="完了" count={doneCount} muted>
                    <div className="space-y-2">{completedTasks.map(renderTaskRow)}</div>
                  </TaskSection>
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
  const signOut = async () => {
    if (tokens.refreshToken) {
      await logout(tokens.refreshToken).catch(() => undefined);
    }
    onAuth(null);
  };

  return (
    <Screen title="設定" subtitle="Web MVP の接続状態とサインアウト。">
      <div className="max-w-[720px] space-y-4">
        <Card className="p-0">
          <SettingsRow
            icon={<WalletCards size={18} />}
            title="Premium"
            description="MVP 期間中は無料で利用できます。"
            trailing={<Badge variant="success">Free MVP</Badge>}
          />
          <Separator />
          <SettingsRow
            icon={<Sparkles size={18} />}
            title="API"
            description={API_BASE_URL}
            trailing={<Badge variant="success"><Check size={11} className="mr-1" />Connected</Badge>}
          />
        </Card>

        <Card>
          <Button variant="destructive-ghost" className="w-full justify-center" onClick={signOut}>
            <LogOut size={16} />
            サインアウト
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
      <header className="mb-6">
        <h1 className="font-rounded text-[28px] font-bold tracking-tight">{title}</h1>
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

function formatDate(value: string): string {
  return new Intl.DateTimeFormat("ja-JP", {
    month: "short",
    day: "numeric",
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
