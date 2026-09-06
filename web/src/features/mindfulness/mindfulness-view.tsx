"use client";

import { CheckCircle2, Clock3, Play, Square, Trash2, Wind } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { loadMeditationLogs, saveMeditationLogs } from "@/lib/storage";
import type { MeditationLog } from "@/types/api";

const DURATIONS = [60, 180, 300];

export function MindfulnessView() {
  const [duration, setDuration] = useState(180);
  const [elapsed, setElapsed] = useState(0);
  const [running, setRunning] = useState(false);
  const [logs, setLogs] = useState<MeditationLog[]>([]);
  const startedAt = useRef<number | null>(null);
  const completed = useRef(false);

  useEffect(() => setLogs(loadMeditationLogs()), []);

  useEffect(() => {
    if (!running) return;
    const timer = window.setInterval(() => {
      if (startedAt.current === null) return;
      const next = Math.min(duration, Math.floor((Date.now() - startedAt.current) / 1000));
      setElapsed(next);
      if (next >= duration && !completed.current) {
        completed.current = true;
        setRunning(false);
        const log = { id: crypto.randomUUID(), date: new Date().toISOString(), duration };
        setLogs((current) => {
          const nextLogs = [log, ...current].slice(0, 30);
          saveMeditationLogs(nextLogs);
          return nextLogs;
        });
      }
    }, 250);
    return () => window.clearInterval(timer);
  }, [duration, running]);

  const phase = useMemo(() => breathingPhase(elapsed), [elapsed]);
  const remaining = Math.max(0, duration - elapsed);
  const progress = duration === 0 ? 0 : elapsed / duration;

  const start = () => {
    completed.current = false;
    setElapsed(0);
    startedAt.current = Date.now();
    setRunning(true);
  };

  const stop = () => {
    setRunning(false);
    startedAt.current = null;
    setElapsed(0);
    completed.current = false;
  };

  const removeLog = (id: string) => {
    const next = logs.filter((log) => log.id !== id);
    setLogs(next);
    saveMeditationLogs(next);
  };

  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,1.15fr)_minmax(280px,0.85fr)]">
      <Card className="overflow-hidden">
        <CardHeader>
          <CardTitle><Wind size={16} className="text-primary" />4-7-8 呼吸</CardTitle>
          <Badge variant="muted">{Math.round(progress * 100)}%</Badge>
        </CardHeader>
        <CardContent className="grid min-h-[430px] place-items-center text-center">
          <div>
            <div className="relative mx-auto grid h-56 w-56 place-items-center">
              <div
                className="absolute inset-6 rounded-full bg-primary/15 transition-transform duration-700 ease-in-out"
                style={{ transform: `scale(${phase.scale})` }}
              />
              <div className="relative grid h-40 w-40 place-items-center rounded-full border border-primary/25 bg-white/55 shadow-card">
                <div>
                  <div className="font-rounded text-[22px] font-bold text-primary-strong">{running ? phase.label : "準備ができたら"}</div>
                  <div className="mt-2 text-[13px] text-muted-foreground">残り {formatDuration(remaining)}</div>
                </div>
              </div>
            </div>

            <div className="mt-2 flex justify-center gap-2">
              {DURATIONS.map((value) => (
                <button
                  key={value}
                  onClick={() => !running && setDuration(value)}
                  disabled={running}
                  className={`rounded-full px-3 py-1.5 text-[12px] font-semibold ${duration === value ? "bg-primary text-white" : "bg-primary/8 text-primary-strong"}`}
                >
                  {formatDuration(value)}
                </button>
              ))}
            </div>

            <div className="mt-5 flex justify-center gap-2">
              {!running ? (
                <Button onClick={start}><Play size={16} />呼吸を始める</Button>
              ) : (
                <Button variant="outline" onClick={stop}><Square size={15} />終了</Button>
              )}
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle><Clock3 size={16} className="text-primary" />瞑想の記録</CardTitle>
          <Badge variant="muted">{logs.length} 回</Badge>
        </CardHeader>
        <CardContent className="space-y-2">
          {logs.length === 0 ? (
            <div className="grid min-h-[260px] place-items-center text-center text-[13px] text-muted-foreground">
              最初の呼吸セッションを始めましょう
            </div>
          ) : (
            logs.slice(0, 10).map((log) => (
              <div key={log.id} className="group flex items-center gap-3 rounded-xl border border-border/50 bg-white/45 p-3">
                <CheckCircle2 size={17} className="text-primary" />
                <div className="min-w-0 flex-1">
                  <div className="text-[13px] font-semibold">{formatDuration(log.duration)}</div>
                  <div className="text-[11px] text-muted-foreground">{formatLogDate(log.date)}</div>
                </div>
                <button
                  onClick={() => removeLog(log.id)}
                  className="grid h-8 w-8 place-items-center rounded-lg text-muted-foreground opacity-60 hover:bg-destructive/10 hover:text-destructive md:opacity-0 md:group-hover:opacity-100"
                  aria-label="瞑想記録を削除"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}

function breathingPhase(elapsed: number): { label: string; scale: number } {
  const position = elapsed % 19;
  if (position < 4) return { label: "息を吸う", scale: 0.82 + 0.36 * (position / 4) };
  if (position < 11) return { label: "そのまま", scale: 1.18 };
  return { label: "息を吐く", scale: 1.18 - 0.36 * ((position - 11) / 8) };
}

function formatDuration(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  if (minutes === 0) return `${rest}秒`;
  if (rest === 0) return `${minutes}分`;
  return `${minutes}分${rest}秒`;
}

function formatLogDate(value: string): string {
  return new Intl.DateTimeFormat("ja-JP", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}
