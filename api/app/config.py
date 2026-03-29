"""Application configuration via environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    environment: str = "dev"
    gcp_project_id: str = "cycle-journal"
    gcp_region: str = "asia-northeast1"
    apple_bundle_id: str = "com.akitoando.CycleJournal"
    google_client_id: str = ""  # iOS用Google OAuth Client ID

    # Vertex AI Claude
    claude_model: str = "claude-sonnet-4-20250514"
    claude_max_tokens: int = 500
    claude_temperature: float = 0.7

    # LangGraphフローを有効にする（感情分析・Cycle要素判定・安全フィルター）
    use_langgraph: bool = False

    model_config = {"env_prefix": "", "case_sensitive": False}


settings = Settings()
