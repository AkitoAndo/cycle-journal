# Coach Studio MCP

Coach Studioの設定確認、検証、テスト、下書き保存、開発環境への適用を、
CodexやChatGPTなどのMCPクライアントから実行するためのリモートMCPです。

## セキュリティ境界

- MCPはAPIとは別のCloud Runサービス `cycle-coach-mcp-dev` として動作する。
- Cloud RunはOAuth discoveryのためHTTPSで到達可能にするが、`/mcp` は有効なBearer
  tokenがない限り常に401を返す。
- MCP OAuth 2.1 resource serverとして、issuer、audience、有効期限、RS256署名、
  `coach:manage` scopeを検証する。
- さらに、tokenに含まれるメールが確認済みで、次のallowlistに含まれることを
  サーバー側で再検証する。
  - `28ww.lo.ol.ww28@gmail.com`
  - `takeshiogata1105@gmail.com`
- 全ツール呼び出しをCloud Loggingへ記録する。プロンプト本文やテスト入力本文は
  監査ログに残さず、設定hashと文字数のみ記録する。
- MCP Cloud RunのサービスアカウントにはFirestoreとVertex AIの権限を付けない。
  Google署名付きservice identityでAPI内の専用routerだけを呼び出し、API側でも
  MCPサービスアカウントと操作主体メールを検証する。
- 本番環境への適用ツールは公開しない。開発環境への適用も版IDを含む確認文字列を
  必須にする。

Cloud Run IAMだけで2人を判定することはできない。Cloud Runから見る呼び出し元は
MCPホストであり、人のGoogleアカウントではないため、ユーザー認可はOAuth tokenの
claimを使ってMCP resource server内で行う。

## 公開ツール

| Tool | 動作 | 書き込み |
| --- | --- | --- |
| `coach_get_current_config` | 現在使用中の設定を取得 | なし |
| `coach_list_versions` | 保存済みの版を一覧表示 | なし |
| `coach_get_version` | 指定した版を取得 | なし |
| `coach_validate_changes` | 設定と固定構造を検証 | なし |
| `coach_test_config` | 保存せず返答をテスト | テスト監査ログのみ |
| `coach_save_draft` | 新しい下書き版を保存 | あり |
| `coach_deploy_to_dev` | 保存済み版をDevへ適用 | あり・明示確認必須 |

## OAuthプロバイダー

OpenAIのMCP認証ガイドは、書き込みを含むMCPにOAuth 2.1、PKCE、protected
resource metadata、authorization server metadataを求めており、自作ではなく既存の
identity providerを推奨している。初期構成では、OpenAIの認証済みMCP scaffoldでも
案内されているAuth0を使用する。

- OpenAI: <https://developers.openai.com/plugins/build/auth>
- OpenAI Authenticated MCP scaffold:
  <https://github.com/openai/openai-mcpkit/tree/main/python-authenticated-mcp-server-scaffold>

### Auth0設定

1. Auth0 tenantを作成し、Google social connectionを有効にする。
2. APIを作成する。
   - Name: `Treow Coach MCP Dev`
   - Identifier:
     `https://cycle-coach-mcp-dev-1031235624127.asia-northeast1.run.app/mcp`
   - Signing Algorithm: `RS256`
3. API permission `coach:manage` を追加する。
4. DevではDCRを有効化し、サードパーティーアプリケーションの既定の
   User-delegated permissionに `coach:manage` だけを許可する。Auth0の新規DCR
   クライアントはPKCE必須のstrict security controlsを使用する。
5. 本番ではopen DCRではなくCIMD registrationを有効化し、Codex／ChatGPTの
   CIMD clientへ `coach:manage` だけを許可する。
6. Post Login Actionで、許可した2メール以外を拒否し、access tokenへ確認済みメールを
   namespaced claimとして追加する。

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const mcpAudience =
    "https://cycle-coach-mcp-dev-1031235624127.asia-northeast1.run.app/mcp";
  if (event.resource_server?.identifier !== mcpAudience) {
    return;
  }

  const allowed = new Set([
    "28ww.lo.ol.ww28@gmail.com",
    "takeshiogata1105@gmail.com",
  ]);
  const email = (event.user.email || "").toLowerCase();

  if (!event.user.email_verified || !allowed.has(email)) {
    api.access.deny("Treow Coach MCP is restricted to approved administrators.");
    return;
  }

  api.accessToken.setCustomClaim("https://cycle-journal.app/email", email);
  api.accessToken.setCustomClaim(
    "https://cycle-journal.app/email_verified",
    true,
  );
};
```

Auth0側のdenyは第一ゲートであり、MCPサーバー側でも同じallowlistを再検証する。

## 設定値の保管

MCP resource serverはAuth0 client secretを保持しない。必要なのは公開情報のみである。

| 値 | 保管場所 |
| --- | --- |
| Auth0 issuer URL | Terraform variable / Cloud Run環境変数 |
| MCP audience | TerraformがCloud Run URLから生成 |
| 許可メール | Terraform / Cloud Run環境変数、およびAuth0 Action |
| Auth0 signing public keys | OIDC discovery経由で取得し、1時間だけメモリcache |
| Auth0管理資格情報 | Auth0アカウント内のみ。repoやCloud Runには保存しない |

## ローカル確認

```bash
cd api
uv sync --frozen --extra dev
uv run ruff check .
uv run pytest
uv run uvicorn app.mcp_server:app --host 0.0.0.0 --port 8080
```

未認証確認:

```bash
curl -i http://127.0.0.1:8080/health
curl -i -X POST http://127.0.0.1:8080/mcp -H 'content-type: application/json' -d '{}'
curl -i http://127.0.0.1:8080/.well-known/oauth-protected-resource/mcp
```

2つ目のリクエストは401になり、`WWW-Authenticate` にprotected resource metadata
URLが含まれること。
