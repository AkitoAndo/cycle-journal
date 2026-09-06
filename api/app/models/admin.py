"""Admin prompt management models."""

from string import Formatter

from pydantic import BaseModel, Field, model_validator

TEMPLATE_SPECS = {
    "analyze_emotion_prompt": ({"user_message"}, {"user_message"}),
    "determine_cycle_prompt": (
        {"elements", "user_message", "detected_emotion"},
        {"elements", "user_message", "detected_emotion"},
    ),
    "analysis_injection_prompt": (
        {"detected_emotion", "cycle_element"},
        {"detected_emotion", "cycle_element"},
    ),
    "safety_filter_prompt": ({"response"}, {"response"}),
}
PHASE_IDS = {
    "acknowledge": "1_承認",
    "triage": "2_トリアージ",
    "space": "3_残余",
    "naming": "4_命名",
    "reflection": "5_反映",
}
SYSTEM_PROMPT_SECTIONS = ("identity_core", "layer8", "output_spec", "action_core")


def _template_fields(value: str, field_name: str) -> set[str]:
    try:
        return {
            variable
            for _, variable, _, _ in Formatter().parse(value)
            if variable is not None
        }
    except ValueError as exc:
        raise ValueError(f"{field_name} has invalid braces: {exc}") from exc


def _validate_system_prompt(value: str) -> None:
    for section in SYSTEM_PROMPT_SECTIONS:
        if f"<{section}>" not in value or f"</{section}>" not in value:
            raise ValueError(f"system_prompt must keep the <{section}> section")
    if "<control>" not in value:
        raise ValueError("system_prompt must keep the <control> contract")


class PromptConfig(BaseModel):
    system_prompt: str = Field(..., min_length=1)
    use_langgraph: bool = False
    use_gemini_fallback: bool = True
    claude_model_coach: str
    claude_model_quick: str
    gemini_model_coach: str
    gemini_model_quick: str
    temperature: float = Field(..., ge=0, le=2)
    max_tokens: int = Field(..., ge=1)
    output_max_tokens_cap: int = Field(..., ge=1)
    analyze_emotion_prompt: str = Field(..., min_length=1)
    determine_cycle_prompt: str = Field(..., min_length=1)
    analysis_injection_prompt: str = Field(..., min_length=1)
    safety_filter_prompt: str = Field(..., min_length=1)
    coach_phase_modules: dict[str, str] = Field(default_factory=dict)
    coach_action_core_checklist: str | None = None
    coach_layer8_crisis_prompt: str | None = None
    coach_professional_boundary_prompt: str | None = None
    coach_vocabulary_lint_enabled: bool = True


class EditablePromptConfig(PromptConfig):
    @model_validator(mode="after")
    def validate_runtime_contract(self) -> "EditablePromptConfig":
        _validate_system_prompt(self.system_prompt)
        if self.max_tokens > self.output_max_tokens_cap:
            raise ValueError("max_tokens must not exceed output_max_tokens_cap")

        for field_name, (allowed, required) in TEMPLATE_SPECS.items():
            fields = _template_fields(str(getattr(self, field_name)), field_name)
            unknown = fields - allowed
            missing = required - fields
            if unknown:
                raise ValueError(
                    f"{field_name} has unsupported variables: {sorted(unknown)}"
                )
            if missing:
                raise ValueError(
                    f"{field_name} is missing required variables: {sorted(missing)}"
                )

        unknown_phases = set(self.coach_phase_modules) - set(PHASE_IDS)
        if unknown_phases:
            raise ValueError(
                f"coach_phase_modules has unsupported phases: {sorted(unknown_phases)}"
            )
        for phase, value in self.coach_phase_modules.items():
            if not value.strip():
                continue
            expected_opening = f'<phase_module id="{PHASE_IDS[phase]}">'
            if not value.lstrip().startswith(expected_opening):
                raise ValueError(f"coach_phase_modules.{phase} has an invalid fixed id")
            if not value.rstrip().endswith("</phase_module>"):
                raise ValueError(
                    f"coach_phase_modules.{phase} must keep its closing tag"
                )
            if value.count("{{核チェックリスト}}") != 1:
                raise ValueError(
                    f"coach_phase_modules.{phase} must contain exactly one "
                    "checklist slot"
                )

        return self


class PromptVersionCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)
    prompt: str = Field(..., min_length=1)
    config: EditablePromptConfig | None = None
    notes: str | None = None

    @model_validator(mode="after")
    def validate_prompt(self) -> "PromptVersionCreateRequest":
        _validate_system_prompt(self.prompt)
        return self


class PromptDeploymentRequest(BaseModel):
    version_id: str = Field(..., min_length=1)


class PromptTestRequest(BaseModel):
    message: str = Field(..., min_length=1)
    version_id: str | None = None
    prompt: str | None = None
    config: EditablePromptConfig | None = None
    diary_content: str | None = None
    history: list[dict] | None = None

    @model_validator(mode="after")
    def validate_prompt(self) -> "PromptTestRequest":
        if self.prompt is not None:
            _validate_system_prompt(self.prompt)
        return self


class PromptVersionData(BaseModel):
    version_id: str
    title: str
    prompt: str
    config: PromptConfig
    notes: str | None = None
    status: str
    created_by: str
    created_at: str | None = None


class PromptDeploymentData(BaseModel):
    environment: str
    version_id: str | None = None
    deployed_by: str | None = None
    deployed_at: str | None = None


class PromptCurrentData(BaseModel):
    prompt: str
    config: PromptConfig
    version_id: str | None = None
    source: str


class PromptTestData(BaseModel):
    message: str
    version_id: str | None = None
    log_id: str
