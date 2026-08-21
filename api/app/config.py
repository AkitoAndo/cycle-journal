"""Application configuration via environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    environment: str = "dev"
    gcp_project_id: str = "cycle-journal"
    gcp_region: str = "asia-northeast1"
    firestore_database_id: str = "(default)"
    apple_bundle_id: str = "com.akitoando.CycleJournal"
    # Legacy single-client setting. Keep it for existing iOS deployments.
    google_client_id: str = ""
    # Additional comma-separated OAuth audiences (Web dev/prod, admin, etc.).
    google_client_ids: str = ""
    cors_allowed_origins: str = (
        "http://localhost:3000,http://127.0.0.1:3000,"
        "http://localhost:3001,http://127.0.0.1:3001"
    )
    admin_google_emails: str = "takeshiogata1105@gmail.com,28ww.lo.ol.ww28@gmail.com"
    admin_auth_bypass: bool = False

    # Remote MCP resource server for Coach Studio automation.
    # OAuth is intentionally delegated to an established OAuth 2.1 provider
    # (Auth0 is the initial supported provider). The MCP service still applies
    # its own email allowlist as a second authorization gate.
    mcp_public_url: str = "http://127.0.0.1:8080/mcp"
    mcp_oauth_issuer: str = "https://example.invalid/"
    mcp_oauth_audience: str = "http://127.0.0.1:8080/mcp"
    mcp_oauth_jwks_uri: str = ""
    mcp_email_claim: str = "https://cycle-journal.app/email"
    mcp_email_verified_claim: str = "https://cycle-journal.app/email_verified"
    mcp_allowed_emails: str = (
        "takeshiogata1105@gmail.com,28ww.lo.ol.ww28@gmail.com"
    )
    mcp_required_scope: str = "coach:manage"
    # Internal service-to-service boundary. The remote MCP service has no
    # Firestore or Vertex role and can reach only the purpose-built API router.
    mcp_backend_api_url: str = "http://127.0.0.1:8080"
    mcp_service_account_email: str = ""

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
    # NOTE: Sonnet 4.5 / Haiku 4.5 はリージョンエンドポイント (asia-northeast1 等) で
    # 未提供のため global エンドポイントを使う。global は dynamic routing で可用性が
    # 高く、Sonnet 4.5 以降のリージョン pricing premium (10%) も避けられる。
    # quota はベースモデル単位 (anthropic-claude-sonnet-4-5 等) で制御。初期値は 0 の
    # ため Cloud Console → IAM & Admin → Quotas で増枠申請が必要。
    claude_region: str = "global"
    claude_model_coach: str = "claude-sonnet-4-5@20250929"
    claude_model_quick: str = "claude-haiku-4-5@20251001"
    # 後方互換: 既存環境変数 CLAUDE_MODEL を coach 用のエイリアスとして残す
    claude_model: str = "claude-sonnet-4-5@20250929"
    claude_max_tokens: int = 2000
    claude_temperature: float = 0.7

    # Coach API ガードレール
    coach_input_max_chars: int = 10_000
    coach_output_max_tokens_cap: int = 4_000  # 暴走時の hard cap
    coach_stream_timeout_seconds: int = 60
    coach_context_history_max_messages: int = 50
    coach_context_history_max_chars: int = 24_000
    coach_context_summary_limit: int = 5
    coach_context_summary_max_chars: int = 600
    coach_context_diary_max_chars: int = 8_000
    coach_summary_generation_enabled: bool = True
    coach_summary_min_user_messages: int = 1
    coach_summary_refresh_message_interval: int = 4
    coach_summary_source_max_messages: int = 40
    coach_summary_max_chars: int = 360

    # AI monthly usage budget guardrail
    # MVP の上限は 1 user あたり月 1,000 円程度。価格・為替は変わるため env で上書き可。
    ai_monthly_budget_yen: int = 1_000
    ai_usage_usd_to_jpy: float = 160.0
    ai_usage_chars_per_input_token: float = 1.0
    claude_sonnet_input_usd_per_1m: float = 3.0
    claude_sonnet_output_usd_per_1m: float = 15.0
    gemini_pro_input_usd_per_1m: float = 1.25
    gemini_pro_output_usd_per_1m: float = 10.0

    # Gemini fallback（Vertex AI Claude の quota 申請待ち中の暫定）
    # use_gemini_fallback=True のとき chat() は Gemini を呼ぶ。
    # Claude quota が下りたら False にして Claude に戻す（追跡: 別 issue）。
    use_gemini_fallback: bool = True
    gemini_region: str = "global"
    gemini_model_coach: str = "gemini-2.5-pro"  # Sonnet 相当
    gemini_model_quick: str = "gemini-2.5-flash"  # Haiku 相当

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

    # GA4 Measurement Protocol (サーバーサイドからのイベント送信用)
    # - GA4 Admin → Data Streams → 該当 iOS stream → Measurement Protocol API secrets
    #   で API secret を発行し Secret Manager 経由で注入する
    # - measurement_id / api_secret が空のときは send_event は no-op
    ga4_measurement_id: str = ""
    ga4_api_secret: str = ""
    ga4_endpoint: str = "https://www.google-analytics.com/mp/collect"

    # Apple Push Notification service (silent push for subscription state changes)
    # - APNs auth key is separate from Sign in with Apple / IAP keys.
    # - Empty credentials make APNs sending a no-op in local/test environments.
    apple_apns_team_id: str = ""
    apple_apns_key_id: str = ""
    apple_apns_private_key: str = ""
    apple_apns_env: str = "Sandbox"

    @property
    def google_oauth_client_ids(self) -> list[str]:
        """Return every accepted Google OAuth audience without duplicates."""
        values = [self.google_client_id, *self.google_client_ids.split(",")]
        return list(dict.fromkeys(value.strip() for value in values if value.strip()))

    @property
    def cors_origins(self) -> list[str]:
        """Return the explicit browser origins allowed to call the API."""
        return list(
            dict.fromkeys(
                value.strip()
                for value in self.cors_allowed_origins.split(",")
                if value.strip()
            )
        )

    @property
    def mcp_email_allowlist(self) -> set[str]:
        """Return the exact identities allowed to use the remote MCP server."""
        return {
            value.strip().lower()
            for value in self.mcp_allowed_emails.split(",")
            if value.strip()
        }

    model_config = {"env_prefix": "", "case_sensitive": False}


settings = Settings()
