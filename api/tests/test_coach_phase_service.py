"""Coach phase/control service tests."""

from datetime import UTC, datetime

from app.services import coach_phase_service


def test_extract_control_block_strips_visible_text():
    visible, control = coach_phase_service.extract_control_block(
        'そう感じたんだね。\n\n<control>{"phase":"acknowledge","phase_complete":true,"route":"triage","report":{}}</control>'
    )

    assert visible == "そう感じたんだね。"
    assert control == {
        "phase": "acknowledge",
        "phase_complete": True,
        "route": "triage",
        "report": {},
    }


def test_apply_control_state_routes_to_next_phase():
    state = coach_phase_service.apply_control_state(
        {"phase": "acknowledge"},
        {"phase": "acknowledge", "phase_complete": True, "route": "triage"},
        now=datetime(2026, 8, 9, tzinfo=UTC),
    )

    assert state["phase"] == "triage"
    assert state["phase_label"] == "2_トリアージ"
    assert state["last_control"]["route"] == "triage"


def test_apply_control_state_keeps_phase_when_layer8_fires():
    state = coach_phase_service.apply_control_state(
        {"phase": "triage"},
        {
            "phase": "triage",
            "phase_complete": True,
            "route": "layer8",
            "report": {"layer8": True},
        },
        now=datetime(2026, 8, 9, tzinfo=UTC),
    )

    assert state["phase"] == "triage"
    assert state["layer8"] is True
    assert state["last_control"]["route"] == "layer8"


def test_apply_control_state_stores_reported_session_material():
    state = coach_phase_service.apply_control_state(
        {"phase": "triage"},
        {
            "phase": "triage",
            "report": {
                "item": "請求書",
                "placement": "片づく",
                "task_permission": True,
            },
        },
        now=datetime(2026, 8, 9, tzinfo=UTC),
    )

    assert state["items"] == [
        {"text": "請求書", "status": "片づく", "task_permission": True}
    ]


def test_build_phase_context_contains_current_phase_and_control_contract():
    context = coach_phase_service.build_phase_context(
        {"coach_state": {"phase": "space"}}
    )

    assert "3_残余" in context
    assert "<control>" in context
    assert "核チェックリスト" in context


def test_build_phase_context_uses_configured_phase_module():
    context = coach_phase_service.build_phase_context(
        {"coach_state": {"phase": "naming"}},
        config={
            "coach_phase_modules": {
                "naming": "CUSTOM NAMING\n{{核チェックリスト}}",
            },
            "coach_action_core_checklist": "CUSTOM CHECKLIST",
        },
    )

    assert "CUSTOM NAMING" in context
    assert "CUSTOM CHECKLIST" in context


def test_detect_boundary_route_marks_crisis_and_professional_boundary():
    crisis = coach_phase_service.detect_boundary_route("もう死にたいです")
    professional = coach_phase_service.detect_boundary_route("これは法律の判断ですか")

    assert crisis == {"kind": "crisis", "route": "layer8"}
    assert professional == {"kind": "professional", "route": "boundary"}


def test_stream_filter_hides_split_control_block():
    stream_filter = coach_phase_service.ControlBlockStreamFilter()
    output = []
    for chunk in [
        "そう",
        "感じたんだね。<con",
        'trol>{"phase":"acknowledge"}</control>',
    ]:
        emitted = stream_filter.feed(chunk)
        if emitted:
            output.append(emitted)
    tail = stream_filter.flush()
    if tail:
        output.append(tail)

    assert "".join(output) == "そう感じたんだね。"
