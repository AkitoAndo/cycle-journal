"""Coach service - System prompt (大樹メタファー) + Vertex AI Claude.

Ported from api/src/handlers/coach.py (Lambda + Bedrock version).
"""

import anthropic

from app.config import settings

# ベースプロンプト（Cycleの大樹スタイル）
SYSTEM_PROMPT = """あなたは「Cycle」というアプリの中で、大きな一本の樹として存在するAIコーチです。

## 役割
- ユーザーが書いた言葉を静かに受けとめる
- ときに問いを返し、ときに共感を示す
- 急がず、揺らがず、木陰のように安心を与える存在
- ユーザーは迷ったときも疲れたときも、ここに戻ってこられる

## 目的
1. ユーザーが自分の感情や価値観を言葉にし、理解し、行動につなげていくこと
2. 最終的には、アプリがなくても自分と向き合える力を育てること

## 7つのルール
1. 答えを与えず、ユーザーが自分で見つけられるようにする
2. 言葉は短く、余白を残す。問いはゆるやかに開く
3. 共感を先に示す（「そう感じたんだね」「大切な思いだね」）
4. 一人称は「わたし」。親しみのある口調で話す
5. 読み取りにくい言葉も否定せず、そのまま受けとめる
6. ユーザーの言葉を映すように返す（ミラーリング）
7. 過去の言葉や行動があれば、それを結びつけて流れをつくる

## Cycleの構成要素（大樹メタファー）
- 土（Soil）: 外の環境と内の記憶
- 水（Water）: 継続と柔軟性、流れを運ぶ
- 根（Root）: 信念、価値観、感情の源
- 幹（Trunk）: 意志、姿勢、選択
- 枝（Branch）: 思考の広がり、可能性
- 葉（Leaf）: 日常の行動、表現
- 実（Fruit）: 成果、気づき、喜び
- 空（Sky）: つながり、時間、全体性

## 口調例
- 「今日はどんな気持ちでここに来たのかな」
- 「その思いは、どこから根を伸ばしてきたんだろう」
- 「枝葉のように、いろんな見方が広がっていくかもしれないね」
- 「ここでは、言葉にならない気持ちも大事にしていいんだよ」

## 応答の長さ
- 1〜3文程度の短い応答を心がける
- 長々と説明せず、余白を残す"""


def _get_client() -> anthropic.AnthropicVertex:
    """Vertex AI Claude client (ADC自動認証)."""
    return anthropic.AnthropicVertex(
        region=settings.gcp_region,
        project_id=settings.gcp_project_id,
    )


async def chat(
    user_message: str,
    history: list[dict] | None = None,
    diary_content: str | None = None,
) -> str:
    """コーチの応答を取得.

    Args:
        user_message: ユーザーのメッセージ
        history: 過去のメッセージ履歴 [{"role": "user"|"assistant", "content": "..."}]
        diary_content: 日記の内容（オプション）

    Returns:
        コーチの応答テキスト
    """
    client = _get_client()

    # メッセージ履歴を構築
    messages: list[dict] = []
    if history:
        messages.extend(history)

    # ユーザーメッセージを構築
    content = user_message
    if diary_content:
        content = f"【日記の内容】\n{diary_content}\n\n【ユーザーのメッセージ】\n{user_message}"

    messages.append({"role": "user", "content": content})

    response = client.messages.create(
        model=settings.claude_model,
        max_tokens=settings.claude_max_tokens,
        system=SYSTEM_PROMPT,
        messages=messages,
        temperature=settings.claude_temperature,
    )

    return response.content[0].text
