# 09. Vertex AI Model Garden のモデル ID 検証

## 目的

PR #42 で `config.py` のデフォルトに pin した Claude モデル ID（`claude-sonnet-4-5@20250929` / `claude-haiku-4-5@20251001`）が `asia-northeast1` リージョンで実際に GA 提供されているか確認し、必要なら環境変数で上書きする。

Vertex AI のモデル命名規則は **Anthropic 公式 API とは異なる**:
- Anthropic 直: `claude-sonnet-4-6`
- Vertex AI: `claude-sonnet-4-5@20250929`（バージョン日付 サフィックス）

リージョンごとに利用可能なモデルが異なり、特に新リリース直後は東京リージョン（`asia-northeast1`）が遅れることがある。

## 前提条件

- GCP プロジェクト `cycle-journal` の **Vertex AI User** 権限
- `gcloud` CLI 認証済

## 手順

### 1. Model Garden でモデル確認

1. [GCP Console → Vertex AI → Model Garden](https://console.cloud.google.com/vertex-ai/model-garden)
2. 検索バーに `claude` と入力
3. 利用可能なモデル一覧:
   - Claude Sonnet 4.5
   - Claude Haiku 4.5
   - Claude Opus 4.x
4. 該当モデルをクリック → **MODEL DETAILS**
5. 以下を確認:
   - **Regional availability**: `asia-northeast1` が含まれているか
   - **Model ID**: 正確な ID（`claude-sonnet-4-5@20250929` 等の `@YYYYMMDD` 形式）

### 2. CLI でモデル ID 確認

```bash
gcloud ai models list \
  --region=asia-northeast1 \
  --filter="displayName:claude" \
  --format="table(displayName,name)"
```

または `curl` で直接 API を叩いて検証:

```bash
ACCESS_TOKEN=$(gcloud auth print-access-token)
PROJECT_ID=cycle-journal
REGION=asia-northeast1
MODEL_ID="claude-sonnet-4-5@20250929"

curl -sS -X POST \
  "https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/publishers/anthropic/models/${MODEL_ID}:rawPredict" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "anthropic_version": "vertex-2023-10-16",
    "max_tokens": 50,
    "messages": [{"role": "user", "content": "こんにちは"}]
  }' | jq '.content[0].text'
```

`"こんにちは" + 何か応答` が返れば OK。404 / 403 ならモデル ID か権限が誤り。

### 3. 利用申請（必要な場合のみ）

新規モデルは初回利用申請が必要なことがある:

1. Model Garden の該当モデルページ
2. **REQUEST ACCESS** ボタンがあればクリック
3. 利用目的を記入して送信
4. 通常 24 時間以内に承認メールが届く

### 4. config.py の値 vs 実 ID の照合

```bash
cd api
.venv/bin/python -c "
from app.config import settings
print('Coach:', settings.claude_model_coach)
print('Quick:', settings.claude_model_quick)
"
# Coach: claude-sonnet-4-5@20250929
# Quick: claude-haiku-4-5@20251001
```

Model Garden で確認した実際の Model ID と一致していれば変更不要。

### 5. env var で上書き（必要な場合）

`asia-northeast1` で違うバージョン日付の場合や、本番運用時にバージョン固定したい場合:

```bash
# Secret Manager に格納する場合
echo -n "claude-sonnet-4-5@20251015" | \
  gcloud secrets create claude-model-coach --data-file=-

echo -n "claude-haiku-4-5@20251101" | \
  gcloud secrets create claude-model-quick --data-file=-

# Cloud Run に注入
gcloud run deploy cyclejournal-api \
  --update-secrets=CLAUDE_MODEL_COACH=claude-model-coach:latest,\
CLAUDE_MODEL_QUICK=claude-model-quick:latest
```

または直接 env var で:

```bash
gcloud run deploy cyclejournal-api \
  --set-env-vars=CLAUDE_MODEL_COACH=claude-sonnet-4-5@20251015,\
CLAUDE_MODEL_QUICK=claude-haiku-4-5@20251101
```

## 検証

### Cloud Run 上で実呼び出し

デプロイ後、`/coach` エンドポイントを認証付きで叩いて応答が返ること:

```bash
ACCESS_TOKEN="<アプリ発行の JWT>"

curl -sS -X POST https://api.cycle-journal.example.com/coach \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"message":"今日は疲れた"}' | jq
```

### LangGraph 各ノードのモデル切替確認

Cloud Run ログで Haiku 呼び出しが分離されているか:

```bash
gcloud logging read "resource.type=cloud_run_revision \
  AND resource.labels.service_name=cyclejournal-api \
  AND textPayload:claude-haiku" \
  --limit 10
```

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `404 Not Found` | モデル ID が違う / リージョンに無い | Model Garden で正確な ID 確認 |
| `403 Permission Denied` | Vertex AI User 権限不足 | `roles/aiplatform.user` を Cloud Run SA に付与 |
| `RESOURCE_EXHAUSTED` | Quota 超過 | Console → IAM & Admin → Quotas で増枠申請 |
| Prompt caching が効かない | Vertex AI は cache_control サポート最新版でのみ可能 | リージョン・モデルバージョンを確認、SDK バージョンも `anthropic[vertex]>=0.42.0` |

## 公式ドキュメント

- [Use Claude models on Vertex AI](https://cloud.google.com/vertex-ai/generative-ai/docs/partner-models/use-claude)
- [Anthropic Vertex AI versions](https://docs.anthropic.com/en/api/claude-on-vertex-ai)
- [Vertex AI Model Garden](https://cloud.google.com/model-garden)

## 次のステップ

→ [10. Terms / Privacy URL の差し替え](10-legal-urls.md)
