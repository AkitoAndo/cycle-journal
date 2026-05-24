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
    claude_model: str = "claude-sonnet-4-20250514"
    claude_max_tokens: int = 500
    claude_temperature: float = 0.7

    # LangGraphフローを有効にする（感情分析・Cycle要素判定・安全フィルター）
    use_langgraph: bool = False

    # Apple In-App Purchase (App Store Server API / Notifications V2)
    # - apple_iap_issuer_id / apple_iap_key_id / apple_iap_private_key は
    #   App Store Connect → Users and Access → Integrations → In-App Purchase Keys
    #   から発行する .p8 とそのメタ情報。Sign in with Apple 用の鍵とは別管理。
    # - apple_iap_env は "Sandbox" / "Production"。デプロイ環境ごとに上書き。
    # - apple_iap_app_apple_id は App Store Connect の App ID(数値)。Sandbox では None 可。  # noqa: E501
    apple_iap_issuer_id: str = ""
    apple_iap_key_id: str = ""
    apple_iap_private_key: str = ""  # .p8 PEM 本体
    apple_iap_env: str = "Sandbox"
    apple_iap_app_apple_id: int | None = None

    model_config = {"env_prefix": "", "case_sensitive": False}


settings = Settings()
