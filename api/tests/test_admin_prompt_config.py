"""Validation tests for editable Coach Studio prompt contracts."""

import pytest
from pydantic import ValidationError

from app.models.admin import EditablePromptConfig, PromptTestRequest
from app.services.prompt_service import default_config


def test_default_prompt_config_keeps_runtime_contracts():
    config = EditablePromptConfig(**default_config())

    assert config.coach_phase_modules["naming"].startswith(
        '<phase_module id="4_命名">'
    )


def test_prompt_config_rejects_unknown_template_variable():
    config = default_config()
    config["analyze_emotion_prompt"] += "\n{unknown_value}"

    with pytest.raises(ValidationError, match="unsupported variables"):
        EditablePromptConfig(**config)


def test_prompt_config_rejects_missing_required_template_variable():
    config = default_config()
    config["safety_filter_prompt"] = "safe または unsafe で答えてください。"

    with pytest.raises(ValidationError, match="missing required variables"):
        EditablePromptConfig(**config)


def test_prompt_config_rejects_editable_phase_id():
    config = default_config()
    config["coach_phase_modules"]["naming"] = config["coach_phase_modules"][
        "naming"
    ].replace('id="4_命名"', 'id="自由入力"')

    with pytest.raises(ValidationError, match="invalid fixed id"):
        EditablePromptConfig(**config)


def test_prompt_config_rejects_missing_phase_checklist_slot():
    config = default_config()
    config["coach_phase_modules"]["reflection"] = config[
        "coach_phase_modules"
    ]["reflection"].replace("{{核チェックリスト}}", "")

    with pytest.raises(ValidationError, match="exactly one checklist slot"):
        EditablePromptConfig(**config)


def test_prompt_config_rejects_tokens_above_runtime_cap():
    config = default_config()
    config["max_tokens"] = int(config["output_max_tokens_cap"]) + 1

    with pytest.raises(ValidationError, match="must not exceed"):
        EditablePromptConfig(**config)


def test_prompt_test_request_rejects_broken_system_contract():
    with pytest.raises(ValidationError, match="identity_core"):
        PromptTestRequest(message="hello", prompt="自由入力だけのプロンプト")
