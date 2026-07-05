# AI Usage Budget

MVP では 1 user あたり月 1,000 円程度を AI 利用上限とする。

## Pricing Assumptions

2026-06-30 時点の公開価格をもとに、API 側の設定値として保持する。
価格や為替は変動するため、環境変数で上書きできる。

| Model | Input | Output | Settings |
| --- | ---: | ---: | --- |
| Claude Sonnet 4.5 | $3.00 / 1M tokens | $15.00 / 1M tokens | `CLAUDE_SONNET_INPUT_USD_PER_1M`, `CLAUDE_SONNET_OUTPUT_USD_PER_1M` |
| Gemini 2.5 Pro | $1.25 / 1M tokens | $10.00 / 1M tokens | `GEMINI_PRO_INPUT_USD_PER_1M`, `GEMINI_PRO_OUTPUT_USD_PER_1M` |

Default budget settings:

| Setting | Default |
| --- | ---: |
| `AI_MONTHLY_BUDGET_YEN` | `1000` |
| `AI_USAGE_USD_TO_JPY` | `160.0` |
| `AI_USAGE_CHARS_PER_INPUT_TOKEN` | `1.0` |

With the default exchange rate, 1,000 JPY is treated as 6.25 USD.

## Enforcement

The API reserves estimated cost before each Coach model call.

The estimate includes:

- `SYSTEM_PROMPT`
- user message
- diary context
- recent session history passed to the model
- reserved output tokens, capped by `min(CLAUDE_MAX_TOKENS, COACH_OUTPUT_MAX_TOKENS_CAP)`

Usage is stored in Firestore:

```text
ai_usage_monthly/{user_id}_{YYYY-MM}
```

Important fields:

- `estimated_input_tokens`
- `reserved_output_tokens`
- `estimated_total_tokens`
- `estimated_cost_micro_usd`
- `budget_micro_usd`
- `budget_yen`
- `request_count`

When the next reservation would exceed the monthly budget, the Coach endpoint returns:

```json
{
  "detail": {
    "code": "ai_monthly_budget_exceeded",
    "period": "YYYY-MM",
    "budget_yen": 1000,
    "estimated_used_yen": 998.4
  }
}
```

HTTP status is `429`.

## Notes

This is a conservative guardrail, not exact billing reconciliation. It over-reserves before
the provider call so the app fails closed when a user approaches the monthly budget.
Provider-reported usage can be added later if exact reconciliation becomes necessary.
