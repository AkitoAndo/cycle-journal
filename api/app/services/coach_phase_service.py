"""Coach phase state and `<control>` block handling."""

from __future__ import annotations

import json
import re
from datetime import UTC, datetime
from typing import Any

CONTROL_BLOCK_RE = re.compile(
    r"<control>\s*(\{.*?\})\s*</control>",
    re.IGNORECASE | re.DOTALL,
)

PHASE_ORDER = ["acknowledge", "triage", "space", "naming", "reflection"]
PHASE_LABELS = {
    "acknowledge": "1_承認",
    "triage": "2_トリアージ",
    "space": "3_余",
    "naming": "4_命名",
    "reflection": "5_反映",
}
PHASE_ALIASES = {
    "acknowledge": "acknowledge",
    "承認": "acknowledge",
    "1": "acknowledge",
    "1_承認": "acknowledge",
    "triage": "triage",
    "トリアージ": "triage",
    "2": "triage",
    "2_トリアージ": "triage",
    "space": "space",
    "余": "space",
    "3": "space",
    "3_余": "space",
    "naming": "naming",
    "命名": "naming",
    "4": "naming",
    "4_命名": "naming",
    "reflection": "reflection",
    "反映": "reflection",
    "5": "reflection",
    "5_反映": "reflection",
}

PHASE_INSTRUCTIONS = {
    "acknowledge": (
        "Phase 1 承認: 2文以内。ユーザーの言葉をそのまま受け、説明や安全宣言はしない。"
        "受け取れたら phase_complete=true とし、route は triage。"
    ),
    "triage": (
        "Phase 2 トリアージ: 2文以内、質問は1つまで。話題を1つだけ扱い、"
        "分類や優先順位はユーザーに決めてもらう。タスク化は明示許可がある時だけ。"
    ),
    "space": (
        "Phase 3 余: 2文以内。「なぜ」「いつから」で掘らない。"
        "残る感覚があれば naming、なければ reflection へ進む。"
    ),
    "naming": (
        "Phase 4 命名: 3文以内。ユーザーの言葉だけを使い、根や名前を静かに置く。"
        "診断や深読みはしない。"
    ),
    "reflection": (
        "Phase 5 反映: 2文以内、質問しない。今日の言葉を短く返して閉じる。"
        "必要なら session_end=true。"
    ),
}

ACTION_CORE_CHECKLIST = (
    "action_core: 返答は最大3文。質問は0または1つ。"
    "評価・助言・診断・安易な安心づけをしない。ユーザーの言葉を鏡のように扱い、"
    "こちらの解釈を足しすぎない。"
)


def normalize_phase(value: Any) -> str | None:
    if value is None:
        return None
    return PHASE_ALIASES.get(str(value).strip())


def normalize_state(raw_state: Any) -> dict[str, Any]:
    state = raw_state if isinstance(raw_state, dict) else {}
    phase = normalize_phase(state.get("phase")) or "acknowledge"
    report = state.get("report") if isinstance(state.get("report"), dict) else {}
    return {
        "phase": phase,
        "phase_label": PHASE_LABELS[phase],
        "phase_complete": bool(state.get("phase_complete", False)),
        "route": normalize_phase(state.get("route")),
        "report": report,
        "layer8": bool(state.get("layer8", False)),
        "session_end": bool(state.get("session_end", False)),
        "last_control": state.get("last_control")
        if isinstance(state.get("last_control"), dict)
        else None,
        "updated_at": state.get("updated_at"),
    }


def build_phase_context(session_data: dict) -> str:
    state = normalize_state(session_data.get("coach_state"))
    phase = state["phase"]
    control_example = {
        "phase": phase,
        "phase_complete": False,
        "route": None,
        "report": {},
        "layer8": False,
        "session_end": False,
    }
    return (
        "【Cycle進行状態】\n"
        f"現在フェーズ: {state['phase_label']}\n"
        f"{PHASE_INSTRUCTIONS[phase]}\n"
        f"{ACTION_CORE_CHECKLIST}\n\n"
        "【制御出力】\n"
        "ユーザーに見せる本文の後に、必ず `<control>` JSON を1つだけ付けてください。"
        "本文と `<control>` の間には空行を置いてください。APIはこの制御情報を保存し、"
        "ユーザーには本文のみを表示します。\n"
        f"<control>{json.dumps(control_example, ensure_ascii=False)}</control>"
    )


def extract_control_block(response_text: str) -> tuple[str, dict[str, Any] | None]:
    """Strip the control block from visible text and return parsed control JSON."""
    match = CONTROL_BLOCK_RE.search(response_text)
    control = None
    if match:
        try:
            parsed = json.loads(match.group(1))
            if isinstance(parsed, dict):
                control = parsed
        except json.JSONDecodeError:
            control = None

    visible_text = CONTROL_BLOCK_RE.sub("", response_text).strip()
    return visible_text, control


def apply_control_state(
    raw_state: Any,
    control: dict[str, Any] | None,
    *,
    now: datetime | None = None,
) -> dict[str, Any]:
    state = normalize_state(raw_state)
    if not control:
        state["updated_at"] = now or datetime.now(UTC)
        return state

    control_phase = normalize_phase(control.get("phase"))
    route = normalize_phase(control.get("route"))
    phase_complete = bool(control.get("phase_complete", False))
    next_phase = state["phase"]
    if phase_complete and route:
        next_phase = route
    elif control_phase:
        next_phase = control_phase

    report = control.get("report") if isinstance(control.get("report"), dict) else {}
    normalized_control = {
        "phase": control_phase or state["phase"],
        "phase_complete": phase_complete,
        "route": route,
        "report": report,
        "layer8": bool(control.get("layer8", False)),
        "session_end": bool(control.get("session_end", False)),
    }
    return {
        "phase": next_phase,
        "phase_label": PHASE_LABELS[next_phase],
        "phase_complete": phase_complete,
        "route": route,
        "report": report,
        "layer8": state["layer8"] or normalized_control["layer8"],
        "session_end": state["session_end"] or normalized_control["session_end"],
        "last_control": normalized_control,
        "updated_at": now or datetime.now(UTC),
    }


class ControlBlockStreamFilter:
    """Hide a trailing `<control>` block while preserving streamed visible text."""

    _tag = "<control"

    def __init__(self) -> None:
        self._buffer = ""
        self._in_control = False

    def feed(self, chunk: str) -> str:
        if self._in_control:
            return ""

        self._buffer += chunk
        marker = self._buffer.lower().find(self._tag)
        if marker >= 0:
            visible = self._buffer[:marker]
            self._buffer = ""
            self._in_control = True
            return visible

        keep = len(self._tag) - 1
        if len(self._buffer) <= keep:
            return ""

        visible = self._buffer[:-keep]
        self._buffer = self._buffer[-keep:]
        return visible

    def flush(self) -> str:
        if self._in_control:
            self._buffer = ""
            return ""
        visible = self._buffer
        self._buffer = ""
        return visible
