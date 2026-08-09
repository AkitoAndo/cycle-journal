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


def test_coach_creates_task_from_permitted_triage_report(
    auth_client,
    mock_firestore,
):
    task_doc = MagicMock()
    task_doc.set = AsyncMock()
    task_collection = MagicMock()
    task_collection.document.return_value = task_doc

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
        ),
        patch(
            "app.routers.coach.ai_usage_service.reserve_monthly_budget",
            new_callable=AsyncMock,
        ),
        patch(
            "app.routers.coach.prompt_service.get_active_config",
            new_callable=AsyncMock,
        ) as active_config,
        patch("app.routers.coach.tasks_ref", return_value=task_collection),
    ):
        mock_chat.return_value = (
            '請求書を置きました。\n\n<control>{"phase":"triage",'
            '"phase_complete":false,"route":null,'
            '"report":{"item":"請求書","placement":"片づく",'
            '"task_permission":true}}</control>'
        )
        build_context.return_value = None
        active_config.return_value = (
            {
                "system_prompt": "system prompt",
                "use_langgraph": False,
                "use_gemini_fallback": True,
            },
            "prompt-v1",
        )

        response = auth_client.post("/coach", json={"message": "請求書は片づく"})

    assert response.status_code == 200
    task_doc.set.assert_awaited_once()
    task_payload = task_doc.set.await_args.args[0]
    assert task_payload["title"] == "請求書"
    assert task_payload["status"] == "pending"
    assert task_payload["source"] == "coach_triage"
    assert task_payload["session_id"] == response.json()["data"]["session_id"]
    update_payload = mock_firestore._mock_doc.update.await_args.args[0]
    assert update_payload["coach_state"]["items"][0]["task_id"]


def test_coach_regenerates_once_when_response_lint_fails(
    auth_client,
    mock_firestore,
):
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
        mock_chat.side_effect = [
            (
                '大丈夫です。まず休みましょう。\n\n<control>{"phase":"triage",'
                '"phase_complete":false,"route":null,"report":{}}</control>'
            ),
            (
                '疲れが、あります。\n\n<control>{"phase":"triage",'
                '"phase_complete":false,"route":null,"report":{}}</control>'
            ),
        ]
        build_context.return_value = None
        active_config.return_value = (
            {
                "system_prompt": "system prompt",
                "use_langgraph": False,
                "use_gemini_fallback": True,
            },
            "prompt-v1",
        )

        response = auth_client.post("/coach", json={"message": "今日は疲れた"})

    assert response.status_code == 200
    assert response.json()["data"]["message"] == "疲れが、あります。"
    assert mock_chat.await_count == 2
    retry_context = mock_chat.await_args_list[1].kwargs["context_block"]
    assert "前回応答の機械検証" in retry_context
    assistant_write = mock_firestore._mock_subcollection.document.return_value.set
    assistant_payload = assistant_write.await_args_list[-1].args[0]
    assert assistant_payload["metadata"]["coach_lint_regenerated"] is True
    assert assistant_payload["metadata"]["coach_lint_violations"] == []


def test_coach_stream_filters_control_block(auth_client, mock_firestore):
    """SSE should not stream the hidden control block to the client."""

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
        mock_chat.return_value = (
            'そう感じたんだね。\n\n<control>{"phase":"acknowledge",'
            '"phase_complete":true,"route":"triage","report":{}}</control>'
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


def test_coach_stream_regenerates_before_streaming(auth_client, mock_firestore):
    """SSE buffers enough to lint before emitting the visible chunk."""

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
        mock_chat.side_effect = [
            (
                '大丈夫です。まず休みましょう。\n\n<control>{"phase":"triage",'
                '"phase_complete":false,"route":null,"report":{}}</control>'
            ),
            (
                '疲れが、あります。\n\n<control>{"phase":"triage",'
                '"phase_complete":false,"route":null,"report":{}}</control>'
            ),
        ]
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
    assert mock_chat.await_count == 2
    chunks = []
    for line in response.text.splitlines():
        if not line.startswith("data: "):
            continue
        data = json.loads(line.removeprefix("data: "))
        if "chunk" in data:
            chunks.append(data["chunk"])
    assert "".join(chunks) == "疲れが、あります。"
    assert "大丈夫です" not in response.text
    assistant_write = mock_firestore._mock_subcollection.document.return_value.set
    assistant_payload = assistant_write.await_args_list[-1].args[0]
    assert assistant_payload["metadata"]["coach_lint_regenerated"] is True
