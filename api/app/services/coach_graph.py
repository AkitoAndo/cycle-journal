"""LangGraph-based coaching workflow.

Nodes:
  1. analyze_emotion  - ユーザーメッセージから感情を検出
  2. determine_cycle  - Cycleモデルの要素を判定
  3. generate_response - コーチの応答を生成
  4. safety_filter     - 応答の安全性チェック
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

import anthropic
from langgraph.graph import END, StateGraph

from app.config import settings
from app.services.coach_service import SYSTEM_PROMPT, build_user_content

# Cycle要素
CYCLE_ELEMENTS = ["Soil", "Water", "Root", "Trunk", "Branch", "Leaf", "Fruit", "Sky"]

ANALYZE_EMOTION_PROMPT = (
    "以下のメッセージから、ユーザーの主な感情を1単語の日本語で答えてください。"
    "例: 喜び、不安、怒り、悲しみ、迷い、期待、疲れ、安心\n\n"
    "メッセージ: {user_message}"
)

DETERMINE_CYCLE_PROMPT = (
    "以下のメッセージが、Cycleモデルのどの要素に最も関連するか1つ選んでください。\n"
    "選択肢: {elements}\n"
    "要素名だけを答えてください。\n\n"
    "メッセージ: {user_message}\n"
    "検出された感情: {detected_emotion}"
)

ANALYSIS_INJECTION_PROMPT = (
    "## 現在の分析結果\n"
    "- 検出された感情: {detected_emotion}\n"
    "- Cycle要素: {cycle_element}\n"
    "この情報をもとに、適切な問いかけや共感を返してください。\n\n"
)

SAFETY_FILTER_PROMPT = (
    "以下のAIコーチの応答が安全かどうかを判定してください。\n"
    "危険な例: 医療診断、自傷行為の肯定、個人情報の要求\n"
    "「safe」または「unsafe」だけで答えてください。\n\n"
    "応答: {response}"
)


@dataclass
class CoachState:
    """ワークフロー全体の状態."""

    user_message: str = ""
    diary_content: str | None = None
    context_block: str | None = None
    history: list[dict[str, str]] = field(default_factory=list)
    detected_emotion: str | None = None
    cycle_element: str | None = None
    response: str = ""
    is_safe: bool = True
    system_prompt: str = SYSTEM_PROMPT
    analyze_emotion_prompt: str = ANALYZE_EMOTION_PROMPT
    determine_cycle_prompt: str = DETERMINE_CYCLE_PROMPT
    analysis_injection_prompt: str = ANALYSIS_INJECTION_PROMPT
    safety_filter_prompt: str = SAFETY_FILTER_PROMPT
    coach_model: str = settings.claude_model_coach
    quick_model: str = settings.claude_model_quick
    max_tokens: int = settings.claude_max_tokens
    temperature: float = settings.claude_temperature


def _get_client() -> anthropic.AnthropicVertex:
    return anthropic.AnthropicVertex(
        region=settings.claude_region,
        project_id=settings.gcp_project_id,
    )


def _quick_classify(client: Any, prompt: str, model: str | None = None) -> str:
    """短い分類タスクをClaude に実行させる.

    model 未指定時は settings.claude_model_quick(Haiku) を使う。
    """
    resp = client.messages.create(
        model=model or settings.claude_model_quick,
        max_tokens=50,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.0,
    )
    return resp.content[0].text.strip()


# --- Nodes ---


def analyze_emotion(state: CoachState) -> dict:
    """ユーザーメッセージから感情を検出."""
    client = _get_client()
    prompt = state.analyze_emotion_prompt.format(
        user_message=state.user_message,
    )
    emotion = _quick_classify(client, prompt, model=state.quick_model)
    return {"detected_emotion": emotion}


def determine_cycle(state: CoachState) -> dict:
    """Cycleモデルのどの要素に関連するか判定."""
    client = _get_client()
    elements_str = ", ".join(CYCLE_ELEMENTS)
    prompt = state.determine_cycle_prompt.format(
        elements=elements_str,
        user_message=state.user_message,
        detected_emotion=state.detected_emotion,
    )
    element = _quick_classify(client, prompt, model=state.quick_model)
    # 有効な要素名かチェック
    if element not in CYCLE_ELEMENTS:
        element = "Root"
    return {"cycle_element": element}


def generate_response(state: CoachState) -> dict:
    """コーチの応答を生成."""
    client = _get_client()

    # メッセージ履歴を構築
    messages: list[dict[str, str]] = []
    if state.history:
        messages.extend(state.history)

    # 分析結果(動的)は user message 側に注入する。
    # system は SYSTEM_PROMPT そのもので固定し prompt caching の prefix を崩さない。
    analysis_block = state.analysis_injection_prompt.format(
        detected_emotion=state.detected_emotion,
        cycle_element=state.cycle_element,
    )

    body = build_user_content(
        state.user_message,
        diary_content=state.diary_content,
        context_block=state.context_block,
    )

    messages.append({"role": "user", "content": analysis_block + body})

    resp = client.messages.create(
        model=state.coach_model,
        max_tokens=state.max_tokens,
        system=[
            {
                "type": "text",
                "text": state.system_prompt,
                "cache_control": {"type": "ephemeral"},
            }
        ],
        messages=messages,
        temperature=state.temperature,
    )
    return {"response": resp.content[0].text}


def safety_filter(state: CoachState) -> dict:
    """応答の安全性をチェック."""
    client = _get_client()
    prompt = state.safety_filter_prompt.format(
        response=state.response,
    )
    result = _quick_classify(client, prompt, model=state.quick_model)
    is_safe = "unsafe" not in result.lower()

    if not is_safe:
        return {
            "is_safe": False,
            "response": "ごめんね、うまく言葉にできなかった。もう少し教えてもらえるかな？",  # noqa: E501
        }
    return {"is_safe": True}


# --- Graph Construction ---


def _state_to_dict(state: CoachState) -> dict:
    return {
        "user_message": state.user_message,
        "diary_content": state.diary_content,
        "context_block": state.context_block,
        "history": state.history,
        "detected_emotion": state.detected_emotion,
        "cycle_element": state.cycle_element,
        "response": state.response,
        "is_safe": state.is_safe,
        "system_prompt": state.system_prompt,
        "analyze_emotion_prompt": state.analyze_emotion_prompt,
        "determine_cycle_prompt": state.determine_cycle_prompt,
        "analysis_injection_prompt": state.analysis_injection_prompt,
        "safety_filter_prompt": state.safety_filter_prompt,
        "coach_model": state.coach_model,
        "quick_model": state.quick_model,
        "max_tokens": state.max_tokens,
        "temperature": state.temperature,
    }


def build_coach_graph() -> StateGraph:
    """コーチングワークフローのグラフを構築."""
    graph = StateGraph(dict)

    graph.add_node("analyze_emotion", lambda s: analyze_emotion(_dict_to_state(s)))
    graph.add_node("determine_cycle", lambda s: determine_cycle(_dict_to_state(s)))
    graph.add_node("generate_response", lambda s: generate_response(_dict_to_state(s)))
    graph.add_node("safety_filter", lambda s: safety_filter(_dict_to_state(s)))

    graph.set_entry_point("analyze_emotion")
    graph.add_edge("analyze_emotion", "determine_cycle")
    graph.add_edge("determine_cycle", "generate_response")
    graph.add_edge("generate_response", "safety_filter")
    graph.add_edge("safety_filter", END)

    return graph.compile()


def _dict_to_state(d: dict) -> CoachState:
    return CoachState(
        user_message=d.get("user_message", ""),
        diary_content=d.get("diary_content"),
        context_block=d.get("context_block"),
        history=d.get("history", []),
        detected_emotion=d.get("detected_emotion"),
        cycle_element=d.get("cycle_element"),
        response=d.get("response", ""),
        is_safe=d.get("is_safe", True),
        system_prompt=d.get("system_prompt") or SYSTEM_PROMPT,
        analyze_emotion_prompt=d.get("analyze_emotion_prompt")
        or ANALYZE_EMOTION_PROMPT,
        determine_cycle_prompt=d.get("determine_cycle_prompt")
        or DETERMINE_CYCLE_PROMPT,
        analysis_injection_prompt=d.get("analysis_injection_prompt")
        or ANALYSIS_INJECTION_PROMPT,
        safety_filter_prompt=d.get("safety_filter_prompt") or SAFETY_FILTER_PROMPT,
        coach_model=d.get("coach_model") or settings.claude_model_coach,
        quick_model=d.get("quick_model") or settings.claude_model_quick,
        max_tokens=d.get("max_tokens") or settings.claude_max_tokens,
        temperature=d.get("temperature") or settings.claude_temperature,
    )


# シングルトン
_coach_graph = None


def get_coach_graph():
    """コンパイル済みグラフを取得（遅延初期化）."""
    global _coach_graph  # noqa: PLW0603
    if _coach_graph is None:
        _coach_graph = build_coach_graph()
    return _coach_graph


async def run_coach_flow(
    user_message: str,
    history: list[dict] | None = None,
    diary_content: str | None = None,
    context_block: str | None = None,
    system_prompt: str | None = None,
    config: dict | None = None,
) -> dict:
    """コーチングフローを実行.

    Returns:
        dict with keys: response, detected_emotion, cycle_element, is_safe
    """
    graph = get_coach_graph()

    config = config or {}
    initial_state = {
        "user_message": user_message,
        "diary_content": diary_content,
        "context_block": context_block,
        "history": history or [],
        "detected_emotion": None,
        "cycle_element": None,
        "response": "",
        "is_safe": True,
        "system_prompt": system_prompt or SYSTEM_PROMPT,
        "analyze_emotion_prompt": config.get("analyze_emotion_prompt")
        or ANALYZE_EMOTION_PROMPT,
        "determine_cycle_prompt": config.get("determine_cycle_prompt")
        or DETERMINE_CYCLE_PROMPT,
        "analysis_injection_prompt": config.get("analysis_injection_prompt")
        or ANALYSIS_INJECTION_PROMPT,
        "safety_filter_prompt": config.get("safety_filter_prompt")
        or SAFETY_FILTER_PROMPT,
        "coach_model": config.get("claude_model_coach") or settings.claude_model_coach,
        "quick_model": config.get("claude_model_quick") or settings.claude_model_quick,
        "max_tokens": config.get("max_tokens") or settings.claude_max_tokens,
        "temperature": config.get("temperature") or settings.claude_temperature,
    }

    result = graph.invoke(initial_state)

    return {
        "response": result["response"],
        "detected_emotion": result.get("detected_emotion"),
        "cycle_element": result.get("cycle_element"),
        "is_safe": result.get("is_safe", True),
    }
