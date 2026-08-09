"""Mechanical lint for visible coach responses."""

from __future__ import annotations

import re
from typing import Any

from app.services import coach_phase_service

MAX_REGEN_ATTEMPTS = 1

PHASE_SENTENCE_LIMITS = {
    "acknowledge": 2,
    "triage": 2,
    "space": 2,
    "naming": 3,
    "reflection": 2,
}

FORBIDDEN_PATTERNS = {
    "praise_or_evaluation": (
        "すごい",
        "えらい",
        "よく頑張",
        "正しい",
        "間違い",
        "強いですね",
        "前向きですね",
    ),
    "advice_or_instruction": (
        "したほうがいい",
        "すべき",
        "してみて",
        "してみましょう",
        "しましょう",
        "まず",
        "大切です",
        "おすすめ",
    ),
    "diagnosis": (
        "診断",
        "うつ病",
        "トラウマ",
        "典型的",
        "症状",
    ),
    "guarantee_or_comfort": (
        "大丈夫",
        "安心してください",
        "きっとうまく",
        "頑張って",
    ),
    "interpretation": (
        "つまり",
        "要するに",
        "まとめると",
        "本当は",
        "その奥",
        "心理",
    ),
}

QUESTION_PATTERNS = re.compile(r"(ですか|ますか|でしょうか|だろうか)[。.!！]?", re.I)
SENTENCE_SPLIT_RE = re.compile(r"[^。！？!?\n]+[。！？!?]?")


def lint_visible_response(
    visible_text: str,
    *,
    raw_state: Any,
    control: dict[str, Any] | None,
) -> list[str]:
    """Return mechanical lint violations for a user-visible coach response."""
    if _is_layer8(control):
        return []

    state = coach_phase_service.normalize_state(raw_state)
    phase = coach_phase_service.normalize_phase(
        control.get("phase") if control else None
    ) or state["phase"]
    sentences = _split_sentences(visible_text)
    violations: list[str] = []

    sentence_limit = PHASE_SENTENCE_LIMITS[phase]
    if len(sentences) > sentence_limit:
        violations.append(
            f"sentence_count>{sentence_limit} ({len(sentences)} sentences)"
        )

    for index, sentence in enumerate(sentences, 1):
        if len(sentence) > 70:
            violations.append(f"sentence_{index}_too_long ({len(sentence)} chars)")

    question_count = _question_count(visible_text)
    question_limit = 0 if phase == "reflection" else 1
    if question_count > question_limit:
        violations.append(f"question_count>{question_limit} ({question_count})")

    for category, patterns in FORBIDDEN_PATTERNS.items():
        hit = next((pattern for pattern in patterns if pattern in visible_text), None)
        if hit:
            violations.append(f"forbidden_{category}:{hit}")

    return violations


def build_retry_context(violations: list[str]) -> str:
    joined = "\n".join(f"- {violation}" for violation in violations)
    return (
        "【前回応答の機械検証】\n"
        "前回の発話は返却前検証で止まりました。次の違反を直して、同じ入力へ再応答してください。\n"
        f"{joined}\n"
        "発話は現在フェーズの規則に合わせ、直後に<control>を一つだけ付けてください。"
    )


def _is_layer8(control: dict[str, Any] | None) -> bool:
    if not control:
        return False
    report = control.get("report") if isinstance(control.get("report"), dict) else {}
    route = coach_phase_service.normalize_route(control.get("route"))
    return bool(control.get("layer8") or report.get("layer8") or route == "layer8")


def _split_sentences(text: str) -> list[str]:
    sentences = [match.group(0).strip() for match in SENTENCE_SPLIT_RE.finditer(text)]
    return [sentence for sentence in sentences if sentence]


def _question_count(text: str) -> int:
    punctuation_questions = text.count("?") + text.count("？")
    phrase_questions = len(QUESTION_PATTERNS.findall(text))
    return max(punctuation_questions, phrase_questions)
