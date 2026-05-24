"""Application configuration via environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    environment: str = "dev"
    gcp_project_id: str = "cycle-journal"
    gcp_region: str = "asia-northeast1"
    apple_bundle_id: str = "com.akitoando.CycleJournal"
    google_client_id: str = ""  # iOS用Google OAuth Client ID

    # Sign in with Apple - revoke / token exchange 用
    # 未設定の場合は revoke / code 交換は no-op になる（ローカル開発フォールバック）
    apple_team_id: str = ""
    apple_key_id: str = ""
    apple_private_key: str = ""  # .p8 ファイルの中身（PEM）

    # JWT (サーバー発行トークン)
    jwt_secret_key: str = "dev-insecure-local-only"  # prodはSecret Managerで上書き
    jwt_algorithm: str = "HS256"
    jwt_issuer: str = "cycle-journal"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30

    # Vertex AI Claude
    # NOTE: Vertex AI モデル ID は asia-northeast1 の Model Garden で
    # 提供状況を確認のうえ実環境向けに上書きすること。
    claude_model_coach: str = "claude-sonnet-4-5@20250929"
    claude_model_quick: str = "claude-haiku-4-5@20251001"
    # 後方互換: 既存環境変数 CLAUDE_MODEL を coach 用のエイリアスとして残す
    claude_model: str = "claude-sonnet-4-5@20250929"
    claude_max_tokens: int = 500
    claude_temperature: float = 0.7

    # LangGraphフローを有効にする（感情分析・Cycle要素判定・安全フィルター）
    use_langgraph: bool = False

    model_config = {"env_prefix": "", "case_sensitive": False}


settings = Settings()
