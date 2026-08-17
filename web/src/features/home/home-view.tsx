"use client";

import { CalendarDays, CheckSquare, Clock3, Leaf, Pencil, Plus, Trash2 } from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { toDateKey } from "@/components/ui/week-calendar";
import { listTasks } from "@/lib/api";
import {
  loadJournals,
  loadScheduleEvents,
  saveScheduleEvents
} from "@/lib/storage";
import type { ScheduleEvent, TaskData } from "@/types/api";

export function HomeView({ accessToken }: { accessToken: string }) {
  const [events, setEvents] = useState<ScheduleEvent[]>([]);
  const [tasks, setTasks] = useState<TaskData[]>([]);
  const [title, setTitle] = useState("");
  const [notes, setNotes] = useState("");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [isAllDay, setIsAllDay] = useState(false);
  const [selectedDate, setSelectedDate] = useState(() => toDateInput(new Date()));
  const [startTime, setStartTime] = useState("09:00");
  const [endTime, setEndTime] = useState("10:00");
  const [taskError, setTaskError] = useState<string | null>(null);
  const [eventError, setEventError] = useState<string | null>(null);

  const reloadTasks = useCallback(async () => {
    try {
      const response = await listTasks(accessToken, "pending");
      setTasks(response.tasks);
      setTaskError(null);
    } catch (cause) {
      setTaskError(cause instanceof Error ? cause.message : "タスクを取得できませんでした");
    }
  }, [accessToken]);

  useEffect(() => {
    setEvents(loadScheduleEvents());
    void reloadTasks();
  }, [reloadTasks]);

  const selectedEvents = useMemo(
    () =>
      events
        .filter((event) => toDateKey(new Date(event.startDate)) === selectedDate)
        .sort((a, b) => Date.parse(a.startDate) - Date.parse(b.startDate)),
    [events, selectedDate]
  );

  const journalCount = useMemo(
    () =>
      loadJournals().filter(
        (entry) => !entry.deletedAt && toDateKey(new Date(entry.date)) === selectedDate
      ).length,
    [selectedDate]
  );

  const addEvent = () => {
    if (!title.trim()) return;
    const startDate = new Date(`${selectedDate}T${isAllDay ? "00:00" : startTime}`);
    const endDate = new Date(`${selectedDate}T${isAllDay ? "23:59" : endTime}`);
    if (endDate < startDate) {
      setEventError("終了時刻は開始時刻より後にしてください");
      return;
    }
    const nextEvent: ScheduleEvent = {
      id: editingId ?? crypto.randomUUID(),
      title: title.trim(),
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString(),
      isAllDay,
      notes: notes.trim(),
      createdAt: events.find((event) => event.id === editingId)?.createdAt ?? new Date().toISOString()
    };
    const next = editingId
      ? events.map((event) => event.id === editingId ? nextEvent : event)
      : [...events, nextEvent];
    setEvents(next);
    saveScheduleEvents(next);
    setTitle("");
    setNotes("");
    setEditingId(null);
    setEventError(null);
  };

  const editEvent = (event: ScheduleEvent) => {
    const start = new Date(event.startDate);
    const end = new Date(event.endDate);
    setEditingId(event.id);
    setSelectedDate(toDateInput(start));
    setTitle(event.title);
    setNotes(event.notes);
    setIsAllDay(event.isAllDay);
    setStartTime(toTimeInput(start));
    setEndTime(toTimeInput(end));
    setEventError(null);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const cancelEdit = () => {
    setEditingId(null);
    setTitle("");
    setNotes("");
    setIsAllDay(false);
    setEventError(null);
  };

  const removeEvent = (id: string) => {
    const next = events.filter((event) => event.id !== id);
    setEvents(next);
    saveScheduleEvents(next);
    if (editingId === id) cancelEdit();
  };

  return (
    <>
      <header className="mb-6">
        <h1 className="font-rounded text-[28px] font-bold tracking-tight">ホーム</h1>
        <p className="mt-1.5 text-[14px] text-muted-foreground">
          今日の予定と、小さな一歩をひとつの場所で確認できます。
        </p>
      </header>

      <div className="mb-4 grid gap-4 sm:grid-cols-3">
        <SummaryCard icon={<CalendarDays size={17} />} label="今日の予定" value={selectedEvents.length} unit="件" />
        <SummaryCard icon={<CheckSquare size={17} />} label="未完了タスク" value={tasks.length} unit="件" />
        <SummaryCard icon={<Leaf size={17} />} label="今日の記録" value={journalCount} unit="件" />
      </div>
      {taskError && (
        <div className="mb-4 rounded-xl bg-destructive/10 px-3 py-2.5 text-[13px] font-medium text-destructive">
          タスクを読み込めませんでした: {taskError}
        </div>
      )}

      <div className="grid items-start gap-4 lg:grid-cols-[minmax(320px,0.7fr)_minmax(0,1.3fr)]">
        <Card>
          <CardHeader>
            <CardTitle>
              {editingId ? <Pencil size={16} className="text-primary" /> : <Plus size={16} className="text-primary" />}
              {editingId ? "予定を編集" : "予定を追加"}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <Field label="日付">
              <Input type="date" value={selectedDate} onChange={(event) => setSelectedDate(event.target.value)} />
            </Field>
            <Field label="タイトル">
              <Input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="予定の名前" />
            </Field>
            <label className="flex items-center gap-2 text-[13px] font-medium">
              <input type="checkbox" checked={isAllDay} onChange={(event) => setIsAllDay(event.target.checked)} />
              終日の予定
            </label>
            {!isAllDay && (
              <div className="grid grid-cols-2 gap-3">
                <Field label="開始">
                  <Input type="time" value={startTime} onChange={(event) => setStartTime(event.target.value)} />
                </Field>
                <Field label="終了">
                  <Input type="time" value={endTime} onChange={(event) => setEndTime(event.target.value)} />
                </Field>
              </div>
            )}
            <Field label="メモ">
              <Textarea value={notes} onChange={(event) => setNotes(event.target.value)} rows={3} />
            </Field>
            {eventError && <div className="text-[13px] font-medium text-destructive">{eventError}</div>}
            <Button className="w-full" onClick={addEvent} disabled={!title.trim()}>
              {editingId ? "変更を保存" : "予定に追加"}
            </Button>
            {editingId && <Button variant="ghost" className="w-full" onClick={cancelEdit}>編集をキャンセル</Button>}
          </CardContent>
        </Card>

        <Card className="min-h-[430px]">
          <CardHeader className="flex-wrap">
            <CardTitle>
              <Clock3 size={16} className="text-primary" />
              1日のタイムライン
            </CardTitle>
            <Input
              type="date"
              value={selectedDate}
              onChange={(event) => setSelectedDate(event.target.value)}
              className="w-[160px]"
            />
          </CardHeader>
          <CardContent className="space-y-3">
            {selectedEvents.length === 0 ? (
              <div className="grid min-h-[300px] place-items-center rounded-2xl border border-dashed border-border/70 text-center text-[13px] text-muted-foreground">
                この日の予定はありません
              </div>
            ) : (
              selectedEvents.map((event) => (
                <article key={event.id} className="group flex gap-4 rounded-2xl border border-border/55 bg-white/55 p-4">
                  <div className="w-[72px] shrink-0 text-[12px] font-semibold text-primary-strong">
                    {event.isAllDay ? "終日" : formatEventTime(event)}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-rounded text-[15px] font-semibold">{event.title}</div>
                    {event.notes && <p className="mt-1 whitespace-pre-wrap text-[13px] text-muted-foreground">{event.notes}</p>}
                  </div>
                  <button
                    onClick={() => editEvent(event)}
                    className="grid h-8 w-8 place-items-center rounded-lg text-muted-foreground opacity-60 hover:bg-primary/10 hover:text-primary md:opacity-0 md:group-hover:opacity-100"
                    aria-label="予定を編集"
                  >
                    <Pencil size={15} />
                  </button>
                  <button
                    onClick={() => removeEvent(event.id)}
                    className="grid h-8 w-8 place-items-center rounded-lg text-muted-foreground opacity-60 hover:bg-destructive/10 hover:text-destructive md:opacity-0 md:group-hover:opacity-100"
                    aria-label="予定を削除"
                  >
                    <Trash2 size={15} />
                  </button>
                </article>
              ))
            )}
          </CardContent>
        </Card>
      </div>
    </>
  );
}

function SummaryCard({ icon, label, value, unit }: { icon: React.ReactNode; label: string; value: number; unit: string }) {
  return (
    <Card className="flex items-center gap-4">
      <div className="grid h-11 w-11 place-items-center rounded-2xl bg-primary/10 text-primary">{icon}</div>
      <div>
        <div className="text-[12px] font-medium text-muted-foreground">{label}</div>
        <div className="mt-0.5 font-rounded text-[22px] font-bold">
          {value}<span className="ml-1 text-[11px] font-semibold text-muted-foreground">{unit}</span>
        </div>
      </div>
    </Card>
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

function toDateInput(date: Date): string {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

function toTimeInput(date: Date): string {
  return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}

function formatEventTime(event: ScheduleEvent): string {
  const formatter = new Intl.DateTimeFormat("ja-JP", { hour: "2-digit", minute: "2-digit" });
  return `${formatter.format(new Date(event.startDate))} – ${formatter.format(new Date(event.endDate))}`;
}
