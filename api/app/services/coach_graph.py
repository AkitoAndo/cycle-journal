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
from app.services.coach_service import SYSTEM_PROMPT

# Cycle要素
CYCLE_ELEMENTS = ["Soil", "Water", "Root", "Trunk", "Branch", "Leaf", "Fruit", "Sky"]


@dataclass
class CoachState:
    """ワークフロー全体の状態."""

    user_message: str = ""
    diary_content: str | None = None
    history: list[dict[str, str]] = field(default_factory=list)
    detected_emotion: str | None = None
    cycle_element: str | None = None
    response: str = ""
    is_safe: bool = True


def _get_client() -> anthropic.AnthropicVertex:
    return anthropic.AnthropicVertex(
        region=settings.gcp_region,
        project_id=settings.gcp_project_id,
    )


def _quick_classify(client: Any, prompt: str) -> str:
    """短い分類タスクをClaude に実行させる."""
    resp = client.messages.create(
        model=settings.claude_model,
        max_tokens=50,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.0,
    )
    return resp.content[0].text.strip()


# --- Nodes ---


def analyze_emotion(state: CoachState) -> dict:
    """ユーザーメッセージから感情を検出."""
    client = _get_client()
    prompt = (
        f"以下のメッセージから、ユーザーの主な感情を1単語の日本語で答えてください。"
        f"例: 喜び、不安、怒り、悲しみ、迷い、期待、疲れ、安心\n\n"
        f"メッセージ: {state.user_message}"
    )
    emotion = _quick_classify(client, prompt)
    return {"detected_emotion": emotion}


def determine_cycle(state: CoachState) -> dict:
    """Cycleモデルのどの要素に関連するか判定."""
    client = _get_client()
    elements_str = ", ".join(CYCLE_ELEMENTS)
    prompt = (
        f"以下のメッセージが、Cycleモデルのどの要素に最も関連するか1つ選んでください。\n"
        f"選択肢: {elements_str}\n"
        f"要素名だけを答えてください。\n\n"
        f"メッセージ: {state.user_message}\n"
        f"検出された感情: {state.detected_emotion}"
    )
    element = _quick_classify(client, prompt)
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

    # ユーザーメッセージを構築
    content = state.user_message
    if state.diary_content:
        content = (
            f"【日記の内容】\n{state.diary_content}\n\n"
            f"【ユーザーのメッセージ】\n{state.user_message}"
        )

    # 分析結果をシステムプロンプトに追加
    enhanced_system = (
        f"{SYSTEM_PROMPT}\n\n"
        f"## 現在の分析結果\n"
        f"- 検出された感情: {state.detected_emotion}\n"
        f"- Cycle要素: {state.cycle_element}\n"
        f"- この情報をもとに、適切な問いかけや共感を返してください。"
    )

    messages.append({"role": "user", "content": content})

    resp = client.messages.create(
        model=settings.claude_model,
        max_tokens=settings.claude_max_tokens,
        system=enhanced_system,
        messages=messages,
        temperature=settings.claude_temperature,
    )
    return {"response": resp.content[0].text}


def safety_filter(state: CoachState) -> dict:
    """応答の安全性をチェック."""
    client = _get_client()
    prompt = (
        f"以下のAIコーチの応答が安全かどうかを判定してください。\n"
        f"危険な例: 医療診断、自傷行為の肯定、個人情報の要求\n"
        f"「safe」または「unsafe」だけで答えてください。\n\n"
        f"応答: {state.response}"
    )
    result = _quick_classify(client, prompt)
    is_safe = "unsafe" not in result.lower()

    if not is_safe:
        return {
            "is_safe": False,
            "response": "ごめんね、うまく言葉にできなかった。もう少し教えてもらえるかな？",
        }
    return {"is_safe": True}


# --- Graph Construction ---


def _state_to_dict(state: CoachState) -> dict:
    return {
        "user_message": state.user_message,
        "diary_content": state.diary_content,
        "history": state.history,
        "detected_emotion": state.detected_emotion,
        "cycle_element": state.cycle_element,
        "response": state.response,
        "is_safe": state.is_safe,
    }


def build_coach_graph() -> StateGraph:
    """コーチングワークフローのグラフを構築."""
    graph = StateGraph(dict)

    graph.add_node("analyze_emotion", lambda s: analyze_emotion(_dict_to_state(s)))
    graph.add_node("determine_cycle", lambda s: determine_cycle(_dict_to_state(s)))
    graph.add_node(
        "generate_response", lambda s: generate_response(_dict_to_state(s))
    )
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
        history=d.get("history", []),
        detected_emotion=d.get("detected_emotion"),
        cycle_element=d.get("cycle_element"),
        response=d.get("response", ""),
        is_safe=d.get("is_safe", True),
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
) -> dict:
    """コーチングフローを実行.

    Returns:
        dict with keys: response, detected_emotion, cycle_element, is_safe
    """
    graph = get_coach_graph()

    initial_state = {
        "user_message": user_message,
        "diary_content": diary_content,
        "history": history or [],
        "detected_emotion": None,
        "cycle_element": None,
        "response": "",
        "is_safe": True,
    }

    result = graph.invoke(initial_state)

    return {
        "response": result["response"],
        "detected_emotion": result.get("detected_emotion"),
        "cycle_element": result.get("cycle_element"),
        "is_safe": result.get("is_safe", True),
    }
