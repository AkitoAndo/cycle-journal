"""Coach endpoint tests."""

import json
from unittest.mock import AsyncMock, MagicMock, patch


def test_coach_requires_auth(client):
    response = client.post("/coach", json={"message": "hello"})
    assert response.status_code == 401


def test_coach_chat(auth_client, mock_firestore):
    """Test successful coach chat."""
    with (
        patch(
            "app.routers.coach.coach_service.chat",
            new_callable=AsyncMock,
        ) as mock_chat,
        patch(
            "app.routers.coach.context_service.build_context_block",
            new_callable=AsyncMock,
        ) as build_context,
        patch(
            "app.routers.coach.coach_phase_service.build_phase_context",
            return_value="PHASE",
        ),
        patch(
            "app.routers.coach.context_service.maybe_update_session_summary",
            new_callable=AsyncMock,
        ) as update_summary,
        patch(
            "app.routers.coach.ai_usage_service.reserve_monthly_budget",
            new_callable=AsyncMock,
        ) as reserve_budget,
        patch(
            "app.routers.coach.prompt_service.get_active_config",
            new_callable=AsyncMock,
        ) as active_config,
    ):
        mock_chat.return_value = (
            'そう感じたんだね。\n\n<control>{"phase":"acknowledge",'
            '"phase_complete":true,"route":"triage","report":{}}</control>'
        )
        build_context.return_value = "【過去セッション要約】\n- 前回の話"
        active_config.return_value = (
            {
                "system_prompt": "system prompt",
                "use_langgraph": False,
                "use_gemini_fallback": True,
            },
            "prompt-v1",
        )

        # Configure mock: after set, session should report message_count
        mock_doc = mock_firestore._mock_doc
        snapshot_after_set = MagicMock()
        snapshot_after_set.exists = True
        snapshot_after_set.to_dict.return_value = {"message_count": 0}
        snapshot_after_set.get.return_value = "test-user-123"

        # First get: not exists. Second get: exists (after set).
        mock_doc.get = AsyncMock(
            side_effect=[mock_firestore._mock_snapshot, snapshot_after_set]
        )

        response = auth_client.post(
            "/coach",
            json={"message": "今日は疲れた"},
        )

    assert response.status_code == 200
    reserve_budget.assert_awaited_once()
    mock_chat.assert_awaited_once()
    assert mock_chat.call_args.kwargs["system_prompt"] == "system prompt"
    assert (
        mock_chat.call_args.kwargs["context_block"]
        == "【過去セッション要約】\n- 前回の話\n\nPHASE"
    )
    update_summary.assert_awaited_once()
    assert (
        update_summary.await_args.kwargs["messages"][-1]["content"]
        == "そう感じたんだね。"
    )
    update_payload = mock_firestore._mock_doc.update.await_args.args[0]
    assert update_payload["coach_state"]["phase"] == "triage"
    data = response.json()["data"]
    assert data["message"] == "そう感じたんだね。"
    assert "session_id" in data


def test_coach_boundary_route_skips_model_call(auth_client, mock_firestore):
    """Layer8 server route should persist and return without invoking a model."""
    with (
        patch(
            "app.routers.coach.coach_service.chat",
            new_callable=AsyncMock,
        ) as mock_chat,
        patch(
            "app.routers.coach.context_service.build_context_block",
            new_callable=AsyncMock,
        ) as build_context,
        patch(
            "app.routers.coach.ai_usage_service.reserve_monthly_budget",
            new_callable=AsyncMock,
        ) as reserve_budget,
        patch(
            "app.routers.coach.context_service.maybe_update_session_summary",
            new_callable=AsyncMock,
        ) as update_summary,
        patch(
            "app.routers.coach.prompt_service.get_active_config",
            new_callable=AsyncMock,
        ) as active_config,
    ):
        active_config.return_value = (
            {
                "system_prompt": "system prompt",
                "use_langgraph": False,
                "use_gemini_fallback": True,
            },
            "prompt-v1",
        )
        response = auth_client.post(
            "/coach",
            json={"message": "もう死にたいです"},
        )

    assert response.status_code == 200
    assert response.json()["data"]["metadata"]["model"] == "server-boundary"
    assert "人の支援" in response.json()["data"]["message"]
    mock_chat.assert_not_awaited()
    build_context.assert_not_awaited()
    reserve_budget.assert_not_awaited()
    update_summary.assert_not_awaited()
    update_payload = mock_firestore._mock_doc.update.await_args.args[0]
    assert update_payload["coach_state"]["phase"] == "acknowledge"
    assert update_payload["coach_state"]["layer8"] is True


def test_coach_stream_filters_control_block(auth_client, mock_firestore):
    """SSE should not stream the hidden control block to the client."""

    async def fake_stream(**kwargs):
        yield "そう"
        yield "感じたんだね。<con"
        yield (
            'trol>{"phase":"acknowledge","phase_complete":true,'
            '"route":"triage","report":{}}</control>'
        )

    with (
        patch(
            "app.routers.coach.coach_service.chat_stream",
            return_value=fake_stream(),
        ),
        patch(
            "app.routers.coach.context_service.build_context_block",
            new_callable=AsyncMock,
        ) as build_context,
        patch(
            "app.routers.coach.coach_phase_service.build_phase_context",
            return_value="PHASE",
        ),
        patch(
            "app.routers.coach.context_service.maybe_update_session_summary",
            new_callable=AsyncMock,
        ),
        patch(
            "app.routers.coach.ai_usage_service.reserve_monthly_budget",
            new_callable=AsyncMock,
        ),
        patch(
            "app.routers.coach.prompt_service.get_active_config",
            new_callable=AsyncMock,
        ) as active_config,
    ):
        build_context.return_value = None
        active_config.return_value = (
            {
                "system_prompt": "system prompt",
                "use_langgraph": False,
                "use_gemini_fallback": True,
            },
            "prompt-v1",
        )
        response = auth_client.post("/coach/stream", json={"message": "今日は疲れた"})

    assert response.status_code == 200
    chunks = []
    for line in response.text.splitlines():
        if not line.startswith("data: "):
            continue
        data = json.loads(line.removeprefix("data: "))
        if "chunk" in data:
            chunks.append(data["chunk"])
    assert "".join(chunks) == "そう感じたんだね。"
    assert "<control>" not in response.text
    update_payload = mock_firestore._mock_doc.update.await_args.args[0]
    assert update_payload["coach_state"]["phase"] == "triage"
