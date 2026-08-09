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


def test_build_phase_context_contains_current_phase_and_control_contract():
    context = coach_phase_service.build_phase_context(
        {"coach_state": {"phase": "space"}}
    )

    assert "3_余" in context
    assert "<control>" in context
    assert "action_core" in context


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
