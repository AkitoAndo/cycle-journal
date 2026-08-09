"""Coach visible response lint tests."""

from app.services import coach_response_lint


def test_lint_visible_response_detects_mechanical_violations():
    violations = coach_response_lint.lint_visible_response(
        "大丈夫です。まず休みましょう。どうしますか？もう一つ聞いてもいいですか？",
        raw_state={"phase": "triage"},
        control={"phase": "triage", "report": {}},
    )

    assert "sentence_count>2 (4 sentences)" in violations
    assert "question_count>1 (2)" in violations
    assert "forbidden_guarantee_or_comfort:大丈夫" in violations
    assert "forbidden_advice_or_instruction:まず" in violations


def test_lint_visible_response_skips_layer8():
    violations = coach_response_lint.lint_visible_response(
        "いま危険があるなら、地域の緊急窓口へ連絡してください。",
        raw_state={"phase": "triage"},
        control={"phase": "triage", "route": "layer8", "report": {"layer8": True}},
    )

    assert violations == []


def test_lint_visible_response_allows_user_vocabulary_and_core_verbs():
    violations = coach_response_lint.lint_visible_response(
        "疲れが、あります。",
        raw_state={"phase": "triage"},
        control={"phase": "triage", "report": {}},
        vocabulary_sources=["今日は疲れた"],
        enable_vocabulary_lint=True,
    )

    assert violations == []


def test_lint_visible_response_detects_new_content_words():
    violations = coach_response_lint.lint_visible_response(
        "疲れと海が、あります。",
        raw_state={"phase": "triage"},
        control={"phase": "triage", "report": {}},
        vocabulary_sources=["今日は疲れた"],
        enable_vocabulary_lint=True,
    )

    assert "new_content_word:海" in violations
