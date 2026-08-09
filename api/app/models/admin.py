"""Admin prompt management models."""

from pydantic import BaseModel, Field


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


class PromptVersionCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)
    prompt: str = Field(..., min_length=1)
    config: PromptConfig | None = None
    notes: str | None = None


class PromptTestRequest(BaseModel):
    message: str = Field(..., min_length=1)
    version_id: str | None = None
    prompt: str | None = None
    config: PromptConfig | None = None
    diary_content: str | None = None
    history: list[dict] | None = None


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
