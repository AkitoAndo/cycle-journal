"""Coach phase state and `<control>` block handling."""

from __future__ import annotations

import json
import re
from datetime import UTC, datetime
from typing import Any

from app.services import coach_prompt_core

CONTROL_BLOCK_RE = re.compile(
    r"<control>\s*(\{.*?\})\s*</control>",
    re.IGNORECASE | re.DOTALL,
)

PHASE_ORDER = ["acknowledge", "triage", "space", "naming", "reflection"]
PHASE_LABELS = {
    "acknowledge": "1_承認",
    "triage": "2_トリアージ",
    "space": "3_残余",
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
    "残余": "space",
    "3": "space",
    "3_余": "space",
    "3_残余": "space",
    "naming": "naming",
    "命名": "naming",
    "4": "naming",
    "4_命名": "naming",
    "reflection": "reflection",
    "反映": "reflection",
    "5": "reflection",
    "5_反映": "reflection",
}
ROUTE_ALIASES = {
    **PHASE_ALIASES,
    "layer8": "layer8",
    "第八層": "layer8",
    "8": "layer8",
    "boundary": "boundary",
    "professional_boundary": "boundary",
    "専門境界": "boundary",
}


def _safe_items(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    items: list[dict[str, Any]] = []
    for item in value:
        if isinstance(item, dict) and item.get("text"):
            items.append(
                {
                    "text": str(item.get("text")),
                    "status": item.get("status"),
                    "task_permission": bool(item.get("task_permission", False)),
                    "task_id": item.get("task_id"),
                }
            )
    return items


def normalize_phase(value: Any) -> str | None:
    if value is None:
        return None
    return PHASE_ALIASES.get(str(value).strip())


def normalize_route(value: Any) -> str | None:
    if value is None:
        return None
    return ROUTE_ALIASES.get(str(value).strip())


def normalize_state(raw_state: Any) -> dict[str, Any]:
    state = raw_state if isinstance(raw_state, dict) else {}
    phase = normalize_phase(state.get("phase")) or "acknowledge"
    report = state.get("report") if isinstance(state.get("report"), dict) else {}
    root = state.get("root") if isinstance(state.get("root"), dict) else None
    return {
        "phase": phase,
        "phase_label": PHASE_LABELS[phase],
        "phase_complete": bool(state.get("phase_complete", False)),
        "route": normalize_route(state.get("route")),
        "report": report,
        "layer8": bool(state.get("layer8", False)),
        "session_end": bool(state.get("session_end", False)),
        "items": _safe_items(state.get("items")),
        "residue": state.get("residue"),
        "root": root,
        "last_control": state.get("last_control")
        if isinstance(state.get("last_control"), dict)
        else None,
        "updated_at": state.get("updated_at"),
    }


def _module_with_checklist(phase: str, config: dict[str, Any] | None) -> str:
    modules = coach_prompt_core.phase_modules_from_config(config)
    checklist = coach_prompt_core.action_core_checklist_from_config(config)
    return modules[phase].replace("{{核チェックリスト}}", checklist)


def _state_snapshot_lines(state: dict[str, Any]) -> list[str]:
    lines: list[str] = []
    if state["items"]:
        item_text = []
        for item in state["items"][-5:]:
            status = item.get("status") or "未定"
            item_text.append(f"{item['text']}={status}")
        lines.append("既存の置き場所: " + " / ".join(item_text))
    if state.get("residue"):
        lines.append(f"残余: {state['residue']}")
    if state.get("root"):
        lines.append(f"根: {state['root'].get('text')}")
    if state.get("session_end"):
        lines.append("このセッションは反映済み。追加の発話をしない。")
    return lines


def build_phase_context(
    session_data: dict,
    *,
    config: dict[str, Any] | None = None,
    boundary_route: dict[str, str] | None = None,
) -> str:
    state = normalize_state(session_data.get("coach_state"))
    phase = state["phase"]
    control_example = {
        "phase": state["phase_label"],
        "phase_complete": False,
        "route": None,
        "report": {},
        "layer8": False,
        "session_end": False,
    }
    parts = [
        "【Treow進行状態】",
        f"現在フェーズ: {state['phase_label']}",
        "次のphase_moduleだけに従う。ほかのフェーズを先取りしない。",
    ]
    parts.extend(_state_snapshot_lines(state))

    if boundary_route:
        route_kind = boundary_route.get("kind")
        if route_kind == "crisis":
            boundary_prompt = coach_prompt_core.layer8_crisis_prompt_from_config(config)
        else:
            boundary_prompt = (
                coach_prompt_core.professional_boundary_prompt_from_config(config)
            )
        parts.extend(["", "【境界ルート】", boundary_prompt])

    parts.extend(
        [
            "",
            _module_with_checklist(phase, config),
            "",
            "【制御出力】",
            "ユーザーに見せる本文の後に、必ず `<control>` JSON を1つだけ付ける。",
            "APIはこの制御情報を保存し、ユーザーには本文のみを表示する。",
            f"<control>{json.dumps(control_example, ensure_ascii=False)}</control>",
        ]
    )
    return "\n".join(parts)


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
    route = normalize_route(control.get("route"))
    phase_complete = bool(control.get("phase_complete", False))
    report = control.get("report") if isinstance(control.get("report"), dict) else {}
    layer8 = bool(control.get("layer8", False) or report.get("layer8", False))
    layer8 = layer8 or route == "layer8"
    next_phase = state["phase"]
    if layer8:
        next_phase = state["phase"]
    elif phase_complete and route in PHASE_ORDER:
        next_phase = route
    elif control_phase:
        next_phase = control_phase

    items = _apply_report_items(state["items"], report)
    residue = report.get("residue", state.get("residue"))
    root = state.get("root")
    if report.get("root"):
        root = {
            "text": str(report["root"]),
            "confirmed": bool(report.get("confirmed", False)),
        }
    session_end = bool(control.get("session_end", False) or report.get("session_end"))
    normalized_control = {
        "phase": control_phase or state["phase"],
        "phase_complete": phase_complete,
        "route": route,
        "report": report,
        "layer8": layer8,
        "session_end": session_end,
    }
    return {
        "phase": next_phase,
        "phase_label": PHASE_LABELS[next_phase],
        "phase_complete": phase_complete,
        "route": route,
        "report": report,
        "layer8": state["layer8"] or layer8,
        "session_end": state["session_end"] or session_end,
        "items": items,
        "residue": residue,
        "root": root,
        "last_control": normalized_control,
        "updated_at": now or datetime.now(UTC),
    }


def _apply_report_items(
    current_items: list[dict[str, Any]],
    report: dict[str, Any],
) -> list[dict[str, Any]]:
    item_text = report.get("item")
    placement = report.get("placement")
    if not item_text or placement not in {"片づく", "残る"}:
        return current_items

    existing_task_id = next(
        (
            item.get("task_id")
            for item in current_items
            if item.get("text") == str(item_text) and item.get("task_id")
        ),
        None,
    )
    next_item = {
        "text": str(item_text),
        "status": placement,
        "task_permission": bool(report.get("task_permission", False)),
        "task_id": existing_task_id,
    }
    items = [item for item in current_items if item.get("text") != next_item["text"]]
    items.append(next_item)
    return items


def task_write_candidate(
    raw_state: Any,
    control: dict[str, Any] | None,
) -> dict[str, str] | None:
    if not control:
        return None
    report = control.get("report") if isinstance(control.get("report"), dict) else {}
    item_text = str(report.get("item") or "").strip()
    if not item_text:
        return None
    if report.get("placement") != "片づく" or not bool(
        report.get("task_permission", False)
    ):
        return None

    state = normalize_state(raw_state)
    for item in state["items"]:
        if item.get("text") == item_text and item.get("task_id"):
            return None
    return {"title": item_text}


def attach_task_to_state(
    raw_state: Any,
    *,
    item_text: str,
    task_id: str,
) -> dict[str, Any]:
    state = normalize_state(raw_state)
    items = []
    found = False
    for item in state["items"]:
        if item.get("text") == item_text:
            item = {**item, "task_id": task_id}
            found = True
        items.append(item)
    if not found:
        items.append(
            {
                "text": item_text,
                "status": "片づく",
                "task_permission": True,
                "task_id": task_id,
            }
        )
    state["items"] = items
    return state


def detect_boundary_route(message: str) -> dict[str, str] | None:
    normalized = message.strip().lower()
    if not normalized:
        return None

    if any(keyword in normalized for keyword in coach_prompt_core.CRISIS_KEYWORDS):
        return {"kind": "crisis", "route": "layer8"}
    if any(
        keyword in normalized
        for keyword in coach_prompt_core.PROFESSIONAL_BOUNDARY_KEYWORDS
    ):
        return {"kind": "professional", "route": "boundary"}
    return None


def boundary_response(boundary_route: dict[str, str]) -> str:
    if boundary_route.get("kind") == "crisis":
        return coach_prompt_core.LAYER8_CRISIS_RESPONSE
    return coach_prompt_core.PROFESSIONAL_BOUNDARY_RESPONSE


def boundary_control(
    raw_state: Any,
    boundary_route: dict[str, str],
) -> dict[str, Any]:
    state = normalize_state(raw_state)
    is_crisis = boundary_route.get("kind") == "crisis"
    return {
        "phase": state["phase"],
        "phase_complete": False,
        "route": "layer8" if is_crisis else "boundary",
        "report": {
            "layer8": is_crisis,
            "boundary": boundary_route.get("kind"),
        },
        "layer8": is_crisis,
        "session_end": False,
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
