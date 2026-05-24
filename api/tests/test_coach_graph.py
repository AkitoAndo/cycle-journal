"""LangGraph coach workflow tests (B-2: per-node model selection).

分類系3ノード(analyze_emotion / determine_cycle / safety_filter)は Haiku、
generate_response のみ Sonnet を使うことを確認する。
"""

from unittest.mock import MagicMock, patch

import pytest

from app.config import settings
from app.services.coach_graph import (
    CoachState,
    analyze_emotion,
    determine_cycle,
    generate_response,
    safety_filter,
)


def _mock_client_with_response(text: str) -> MagicMock:
    """anthropic.AnthropicVertex 風のモック."""
    client = MagicMock()
    content_block = MagicMock()
    content_block.text = text
    response = MagicMock()
    response.content = [content_block]
    client.messages.create.return_value = response
    return client


@pytest.fixture
def mock_quick_client():
    """quick(分類)用 Haiku を呼ぶことを期待するモック."""
    with patch("app.services.coach_graph._get_client") as mock_get:
        client = _mock_client_with_response("喜び")
        mock_get.return_value = client
        yield client


@pytest.fixture
def mock_coach_client():
    """coach(本体応答)用 Sonnet を呼ぶことを期待するモック."""
    with patch("app.services.coach_graph._get_client") as mock_get:
        client = _mock_client_with_response("そう感じたんだね。")
        mock_get.return_value = client
        yield client


def test_analyze_emotion_uses_quick_model(mock_quick_client):
    """B-2: analyze_emotion は claude_model_quick を使う."""
    state = CoachState(user_message="今日は嬉しい一日だった")
    analyze_emotion(state)

    call_kwargs = mock_quick_client.messages.create.call_args.kwargs
    assert call_kwargs["model"] == settings.claude_model_quick


def test_determine_cycle_uses_quick_model(mock_quick_client):
    """B-2: determine_cycle は claude_model_quick を使う."""
    mock_quick_client.messages.create.return_value.content[0].text = "Root"
    state = CoachState(user_message="価値観について悩んでいる", detected_emotion="迷い")
    determine_cycle(state)

    call_kwargs = mock_quick_client.messages.create.call_args.kwargs
    assert call_kwargs["model"] == settings.claude_model_quick


def test_safety_filter_uses_quick_model(mock_quick_client):
    """B-2: safety_filter は claude_model_quick を使う."""
    mock_quick_client.messages.create.return_value.content[0].text = "safe"
    state = CoachState(response="そう感じたんだね。")
    safety_filter(state)

    call_kwargs = mock_quick_client.messages.create.call_args.kwargs
    assert call_kwargs["model"] == settings.claude_model_quick


def test_generate_response_uses_coach_model(mock_coach_client):
    """B-2: generate_response は claude_model_coach を使う(本体応答は Sonnet)."""
    state = CoachState(
        user_message="今日は疲れた",
        detected_emotion="疲れ",
        cycle_element="Root",
    )
    generate_response(state)

    call_kwargs = mock_coach_client.messages.create.call_args.kwargs
    assert call_kwargs["model"] == settings.claude_model_coach


def test_generate_response_passes_cached_system(mock_coach_client):
    """B-3: generate_response は system を list で渡し cache_control を付ける."""
    state = CoachState(
        user_message="今日は疲れた",
        detected_emotion="疲れ",
        cycle_element="Root",
    )
    generate_response(state)

    call_kwargs = mock_coach_client.messages.create.call_args.kwargs
    system = call_kwargs["system"]
    assert isinstance(system, list), "system は list で渡されるべき"
    assert system[0]["type"] == "text"
    assert system[0]["cache_control"] == {"type": "ephemeral"}


def test_generate_response_keeps_system_prefix_stable(mock_coach_client):
    """B-3: 分析結果(動的部分)を system に注入すると caching 効かないので
    system は SYSTEM_PROMPT そのもので固定し、動的部分は user message 側に移す."""
    from app.services.coach_service import SYSTEM_PROMPT

    state = CoachState(
        user_message="今日は疲れた",
        detected_emotion="疲れ",
        cycle_element="Root",
    )
    generate_response(state)

    call_kwargs = mock_coach_client.messages.create.call_args.kwargs
    system_text = call_kwargs["system"][0]["text"]
    # system は SYSTEM_PROMPT 完全一致で固定 prefix を担保
    assert system_text == SYSTEM_PROMPT
    # 分析結果(detected_emotion / cycle_element)は user message 側に含まれる
    last_user = call_kwargs["messages"][-1]
    assert last_user["role"] == "user"
    assert "疲れ" in last_user["content"]
    assert "Root" in last_user["content"]
