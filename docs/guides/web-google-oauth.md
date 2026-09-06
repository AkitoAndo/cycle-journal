# Web Google OAuth 運用手順

Treow の iOS / Web で同じ Google アカウントを使用するための認証情報台帳。
Client Secret の値は Git やこの文書には保存しない。

## Google Cloud

- Project ID: `cycle-journal`
- Project number: `1031235624127`
- OAuth clients: <https://console.cloud.google.com/auth/clients?project=cycle-journal>
- OAuth branding: <https://console.cloud.google.com/auth/branding?project=cycle-journal>
- OAuth audience: <https://console.cloud.google.com/auth/audience?project=cycle-journal>

## Development client

- Name: `Treow Web Development`
- Client ID: `1031235624127-j358em4cvl8hll11p4kg3pd650chj82f.apps.googleusercontent.com`
- Secret Manager secret: `google-oauth-web-development`
- Secret versions: <https://console.cloud.google.com/security/secret-manager/secret/google-oauth-web-development/versions?project=cycle-journal>
- Local Web setting: `web/.env.local` の `NEXT_PUBLIC_GOOGLE_CLIENT_ID`

Authorized JavaScript origins:

- `http://localhost:3000`
- `http://127.0.0.1:3000`
- `http://localhost:3001`
- `http://127.0.0.1:3001`
- `https://cycle-web-dev-1031235624127.asia-northeast1.run.app`

Authorized redirect URIs:

- `http://localhost:3000/auth/google/callback`
- `http://127.0.0.1:3000/auth/google/callback`
- `http://localhost:3001/auth/google/callback`
- `http://127.0.0.1:3001/auth/google/callback`
- `https://cycle-web-dev-1031235624127.asia-northeast1.run.app/auth/google/callback`

Web版はGoogle Identity Servicesのredirect UXを使用する。GoogleからのPOSTは
`g_csrf_token`のCookie・フォーム値を照合した後、APIの`/auth/google`でID Tokenを
検証する。ポップアップ方式へ戻す場合も、ブラウザ互換性のためredirect UXを
フォールバックとして維持する。

Secret Manager から値を確認する場合（権限保持者のみ）:

```bash
gcloud secrets versions access latest \
  --secret=google-oauth-web-development \
  --project=cycle-journal
```

## Hosted development

- Web: `https://cycle-web-dev-1031235624127.asia-northeast1.run.app`
- API: `https://cycle-api-dev-1031235624127.asia-northeast1.run.app`
- Cloud Run service: `cycle-web-dev`
- OAuth client: `Treow Web Development`
- OAuth audience: Testing

GitHub の `api-dev` environment には公開値の変数
`GOOGLE_OAUTH_WEB_CLIENT_ID` を設定する。`develop` へのpushでWeb CI/CDが
型検査・本番ビルド後に `cycle-web-dev` を更新する。

現在到達可能な法務URL（いずれもHTTP 200確認済み）:

- Privacy policy: `https://akitoando.github.io/cycle-journal/legal/PRIVACY_POLICY.html`
- Terms of service: `https://akitoando.github.io/cycle-journal/legal/TERMS_OF_SERVICE.html`

## Public production client（独自ドメイン確定後）

Googleの公開OAuth要件に合わせ、所有権を確認できる独自ドメインを使用する。
Homepageはログイン画面だけにせずアプリの目的・Googleデータの利用目的を説明し、
同じドメイン上のPrivacy Policyへリンクする。ドメイン所有権をGoogle Search
Consoleで確認してから、`Treow Web Production` を別クライアントとして作成する。
localhostと一時的な`run.app` originはProduction clientへ追加しない。

Production Client Secretは`google-oauth-web-production`に保存する。

Web は `cycle-web-prod` Cloud Run service として公開する。GitHub の
`api-prod` environment には公開値の変数
`GOOGLE_OAUTH_WEB_CLIENT_ID` を設定する。

Production clientには、公開originに加えて次をAuthorized redirect URIとして
登録する。

- `https://<production-origin>/auth/google/callback`

初回の手動ビルドは `web/cloudbuild.yaml` を使う。`.gcloudignore` により
`.env.local`、`node_modules`、`.next` はCloud Buildへ送信されない。

独自ドメイン公開時、APIの本番環境では次を設定する。

- `GOOGLE_CLIENT_ID`: iOS client ID（後方互換）
- `GOOGLE_CLIENT_IDS`: Web production client ID（カンマ区切りで追加可能）
- `CORS_ALLOWED_ORIGINS`: Web production origin のみ

開発環境は `infra/environments/dev/main.tf` に Web development client と
localhost の許可 origin を固定し、本番環境は
`infra/environments/prod` の変数から正確な値を渡す。Client Secret は
Web/API の実行時環境変数には渡さない。

## ローテーション

1. Google Auth Platform で新しいクライアントまたは Secret を発行する。
2. Secret Manager に新しいバージョンを追加する。
3. Web / API の環境変数を更新してデプロイする。
4. iOS / Web のログインを確認する。
5. 使用されていない旧認証情報を無効化する。
