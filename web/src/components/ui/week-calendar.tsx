"use client";

import { ChevronLeft, ChevronRight } from "lucide-react";
import { useMemo } from "react";
import { cn } from "@/lib/utils";

const WEEKDAY_LABELS = ["日", "月", "火", "水", "木", "金", "土"];

function startOfDay(date: Date): Date {
  const next = new Date(date);
  next.setHours(0, 0, 0, 0);
  return next;
}

function isSameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

function startOfWeek(date: Date): Date {
  const day = date.getDay();
  const next = startOfDay(date);
  next.setDate(next.getDate() - day);
  return next;
}

export function addDays(date: Date, days: number): Date {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

export interface WeekCalendarProps {
  selectedDate: Date;
  onSelect: (date: Date) => void;
  markedDates?: Set<string>;
}

export function toDateKey(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(
    date.getDate()
  ).padStart(2, "0")}`;
}

export function WeekCalendar({ selectedDate, onSelect, markedDates }: WeekCalendarProps) {
  const today = useMemo(() => startOfDay(new Date()), []);
  const weekStart = useMemo(() => startOfWeek(selectedDate), [selectedDate]);
  const days = useMemo(
    () => Array.from({ length: 7 }, (_, i) => addDays(weekStart, i)),
    [weekStart]
  );

  const monthLabel = useMemo(() => {
    const first = days[0];
    const last = days[6];
    if (first.getMonth() === last.getMonth()) {
      return new Intl.DateTimeFormat("ja-JP", { year: "numeric", month: "long" }).format(first);
    }
    return `${new Intl.DateTimeFormat("ja-JP", { month: "short" }).format(
      first
    )} – ${new Intl.DateTimeFormat("ja-JP", { month: "short", year: "numeric" }).format(last)}`;
  }, [days]);

  return (
    <div className="glass-surface rounded-2xl border border-border/60 p-4">
      <div className="mb-3 flex items-center justify-between">
        <button
          onClick={() => onSelect(addDays(selectedDate, -7))}
          className="grid h-8 w-8 place-items-center rounded-full text-muted-foreground transition-colors hover:bg-primary/10 hover:text-foreground"
          aria-label="前の週"
        >
          <ChevronLeft size={16} />
        </button>
        <div className="flex items-center gap-2">
          <span className="font-rounded text-[15px] font-semibold">{monthLabel}</span>
          {!isSameDay(selectedDate, today) && (
            <button
              onClick={() => onSelect(today)}
              className="rounded-full bg-primary/10 px-2.5 py-0.5 text-[11px] font-semibold text-primary-strong transition-colors hover:bg-primary/15"
            >
              今日
            </button>
          )}
        </div>
        <button
          onClick={() => onSelect(addDays(selectedDate, 7))}
          className="grid h-8 w-8 place-items-center rounded-full text-muted-foreground transition-colors hover:bg-primary/10 hover:text-foreground"
          aria-label="次の週"
        >
          <ChevronRight size={16} />
        </button>
      </div>

      <div className="grid grid-cols-7 gap-1">
        {days.map((date) => {
          const selected = isSameDay(date, selectedDate);
          const isToday = isSameDay(date, today);
          const weekday = WEEKDAY_LABELS[date.getDay()];
          const marked = markedDates?.has(toDateKey(date));
          return (
            <button
              key={date.toISOString()}
              onClick={() => onSelect(date)}
              className="group flex flex-col items-center gap-1.5 py-1 text-center transition-transform active:scale-95"
              aria-pressed={selected}
            >
              <span
                className={cn(
                  "text-[10px] font-semibold",
                  date.getDay() === 0 && "text-rose-500/80",
                  date.getDay() === 6 && "text-sky-500/80",
                  date.getDay() !== 0 && date.getDay() !== 6 && "text-muted-foreground"
                )}
              >
                {weekday}
              </span>
              <span
                className={cn(
                  "relative grid h-9 w-9 place-items-center rounded-full text-[15px] transition-all",
                  selected
                    ? "brand-gradient font-semibold text-primary-foreground shadow-soft"
                    : "text-foreground group-hover:bg-primary/10",
                  !selected && isToday && "ring-1 ring-inset ring-primary/50"
                )}
              >
                {date.getDate()}
                {marked && !selected && (
                  <span className="absolute -bottom-0.5 h-1 w-1 rounded-full bg-primary" />
                )}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
