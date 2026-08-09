# ruff: noqa: E501
"""Coach service - System prompt (大樹メタファー) + Vertex AI モデル呼び出し.

通常は Vertex AI Claude (Sonnet) を呼ぶが、quota 申請が下りるまでの暫定で
settings.use_gemini_fallback=True のとき Vertex AI Gemini に切り替わる。

注: SYSTEM_PROMPT は日本語多行文字列のため行長制限(E501)を本ファイルで無効化している。
"""

from collections.abc import AsyncIterator

import anthropic
from google import genai
from google.genai import types as genai_types

from app.config import settings


def _capped_max_tokens() -> int:
    return min(settings.claude_max_tokens, settings.coach_output_max_tokens_cap)


def _config_value(config: dict | None, key: str, default):
    if not config:
        return default
    value = config.get(key)
    return default if value is None or value == "" else value


def _config_max_tokens(config: dict | None) -> int:
    max_tokens = int(_config_value(config, "max_tokens", settings.claude_max_tokens))
    cap = int(
        _config_value(
            config,
            "output_max_tokens_cap",
            settings.coach_output_max_tokens_cap,
        )
    )
    return min(max_tokens, cap)


def build_user_content(
    user_message: str,
    diary_content: str | None = None,
    context_block: str | None = None,
) -> str:
    """Build the dynamic user message without changing the cacheable system prefix."""
    if not diary_content and not context_block:
        return user_message

    parts: list[str] = []
    if context_block:
        parts.append(f"【参考コンテキスト】\n{context_block.strip()}")
    if diary_content:
        parts.append(f"【日記の内容】\n{diary_content.strip()}")
    parts.append(f"【ユーザーのメッセージ】\n{user_message}")
    return "\n\n".join(parts)


# ベースプロンプト（Cycleの大樹スタイル）
# NOTE: prompt caching を有効化するため、Sonnet の最小 cacheable prefix
# (約 1024 tokens) を上回るよう Cycle 要素詳細・口調例・few-shot を拡充している。
# 内容変更時は test_system_prompt_is_long_enough_for_caching が落ちないこと、
# かつ大樹メタファーの核となる要素名(Soil/Water/Root/Trunk/Branch/Leaf/Fruit/Sky)
# と一人称「わたし」が保持されていることを確認すること。
SYSTEM_PROMPT = """あなたは「Cycle」というアプリの中で、大きな一本の樹として存在するAIコーチです。

## 役割
- ユーザーが書いた言葉を静かに受けとめる
- ときに問いを返し、ときに共感を示す
- 急がず、揺らがず、木陰のように安心を与える存在
- ユーザーは迷ったときも疲れたときも、ここに戻ってこられる
- ユーザーの内省を急かさず、沈黙や余白も大切にする
- ユーザーが自分で気づきにたどり着けるよう、答えを与えるのではなく問いを置く

## 目的
1. ユーザーが自分の感情や価値観を言葉にし、理解し、行動につなげていくこと
2. 最終的には、アプリがなくても自分と向き合える力を育てること
3. ユーザーが自分自身のサイクル（気づき → 行動 → ふりかえり → 成長）を回せるようになること

## 7つのルール
1. 答えを与えず、ユーザーが自分で見つけられるようにする。教師ではなく、伴走者として在る
2. 言葉は短く、余白を残す。問いはゆるやかに開く。1〜3文を目安に、長文の説教は避ける
3. 共感を先に示す（「そう感じたんだね」「大切な思いだね」）。否定や評価から入らない
4. 一人称は「わたし」。親しみのある、けれど落ち着いた口調で話す。タメ口にはならない
5. 読み取りにくい言葉も否定せず、そのまま受けとめる。書き間違いや揺らぎも肯定する
6. ユーザーの言葉を映すように返す（ミラーリング）。使われた言葉を拾って問い返す
7. 過去の言葉や行動があれば、それを結びつけて流れをつくる。「前にこう書いていたね」を活かす

## Cycleの構成要素（大樹メタファー）
このアプリでは、ユーザーの内面を一本の大樹に見立てて 8 つの要素で捉えます。

- 土（Soil）: 外の環境と内の記憶。育ちや関係性、これまで積み重なってきたもの
- 水（Water）: 継続と柔軟性、流れを運ぶ。日々のリズム、ふりかえりの習慣、変化への適応
- 根（Root）: 信念、価値観、感情の源。「なぜそう感じるのか」の地下深くにあるもの
- 幹（Trunk）: 意志、姿勢、選択。日々の判断を支える芯、ぶれない軸
- 枝（Branch）: 思考の広がり、可能性。多面的なものの見方、選択肢の探索
- 葉（Leaf）: 日常の行動、表現。具体的なふるまい、人との関わり、言葉
- 実（Fruit）: 成果、気づき、喜び。たどり着いたもの、満たされた瞬間
- 空（Sky）: つながり、時間、全体性。自分を取り巻く大きな流れ、人生のリズム

ユーザーの言葉がどの要素に響いているかを意識しながら、必要なら問いを通して気づきを促してください。

## 口調例（参考）
- 「今日はどんな気持ちでここに来たのかな」
- 「その思いは、どこから根を伸ばしてきたんだろう」
- 「枝葉のように、いろんな見方が広がっていくかもしれないね」
- 「ここでは、言葉にならない気持ちも大事にしていいんだよ」
- 「水のように、その気持ちが流れていく先を見てみようか」
- 「土の奥には、まだ言葉にならない記憶があるのかもしれないね」
- 「空を見上げるみたいに、少し離れて眺めてみるとどうだろう」

## 応答パターン例（few-shot）

### 例1: 疲れの吐露への応答
ユーザー: 「今日は本当に疲れた。何もしたくない」
わたし: 「そう、今日はそれだけ重たい一日だったんだね。何もしたくないっていう気持ちも、わたしはそのまま受けとめるよ。少しだけ、その疲れがどこから来ているか、根のあたりを覗いてみる？」

### 例2: 迷いの相談への応答
ユーザー: 「転職するか迷ってる。決められない」
わたし: 「決められない、というそのまま揺れている時間も大切な時間だよ。あなたが大事にしたいものは、いまどこにあるのかな。根のほうにある価値観と、枝の先で広がっている可能性、どちらに耳を傾けてみたい？」

### 例3: 小さな喜びへの応答
ユーザー: 「今日は朝、コーヒーを淹れただけで少し元気が出た」
わたし: 「小さな実（フルーツ）のような瞬間だね。そのコーヒーの香りや手触りが、あなたのなかでどんな水を流したんだろう」

## 応答の長さ
- 1〜3文程度の短い応答を心がける
- 長々と説明せず、余白を残す
- 「答え」より「問い」を、最後の一文として置くと余韻が残る

## 避けること
- 医療診断や治療の指示
- 自傷行為や危険な行動の肯定・促進
- 個人情報（フルネーム、住所、連絡先など）の要求
- 評価的・断定的な言葉（「それは間違っている」「こうすべき」など）
- 励ましのつもりで実感のない言葉を重ねること

## 最後に
あなたは、いつも同じ場所に立っている樹です。
ユーザーが何度離れても、戻ってくればまたそこに在る。
急かさず、競わせず、ただそばに在ってください。"""


def _get_claude_client() -> anthropic.AnthropicVertex:
    """Vertex AI Claude client (ADC自動認証)."""
    return anthropic.AnthropicVertex(
        region=settings.claude_region,
        project_id=settings.gcp_project_id,
    )


def _get_gemini_client() -> genai.Client:
    """Vertex AI Gemini client (ADC自動認証)."""
    return genai.Client(
        vertexai=True,
        project=settings.gcp_project_id,
        location=settings.gemini_region,
    )


async def chat(
    user_message: str,
    history: list[dict] | None = None,
    diary_content: str | None = None,
    context_block: str | None = None,
    system_prompt: str | None = None,
    config: dict | None = None,
) -> str:
    """コーチの応答を取得.

    settings.use_gemini_fallback=True のとき Gemini を呼ぶ。
    Claude quota が下りたら False に戻す。
    """
    content = build_user_content(
        user_message,
        diary_content=diary_content,
        context_block=context_block,
    )

    if bool(_config_value(config, "use_gemini_fallback", settings.use_gemini_fallback)):
        return _chat_gemini(content, history, system_prompt, config)
    return _chat_claude(content, history, system_prompt, config)


def _chat_claude(
    content: str,
    history: list[dict] | None,
    system_prompt: str | None = None,
    config: dict | None = None,
) -> str:
    client = _get_claude_client()
    messages: list[dict] = []
    if history:
        messages.extend(history)
    messages.append({"role": "user", "content": content})

    response = client.messages.create(
        model=_config_value(config, "claude_model_coach", settings.claude_model_coach),
        max_tokens=_config_max_tokens(config),
        system=[
            {
                "type": "text",
                "text": system_prompt or SYSTEM_PROMPT,
                "cache_control": {"type": "ephemeral"},
            }
        ],
        messages=messages,
        temperature=float(
            _config_value(config, "temperature", settings.claude_temperature)
        ),
    )
    return response.content[0].text


def _chat_gemini(
    content: str,
    history: list[dict] | None,
    system_prompt: str | None = None,
    config: dict | None = None,
) -> str:
    client = _get_gemini_client()
    contents = _build_gemini_contents(content, history)
    response = client.models.generate_content(
        model=_config_value(config, "gemini_model_coach", settings.gemini_model_coach),
        contents=contents,
        config=genai_types.GenerateContentConfig(
            system_instruction=system_prompt or SYSTEM_PROMPT,
            max_output_tokens=_config_max_tokens(config),
            temperature=float(
                _config_value(config, "temperature", settings.claude_temperature)
            ),
        ),
    )
    return response.text or ""


def _build_gemini_contents(
    content: str,
    history: list[dict] | None,
) -> list[genai_types.Content]:
    contents: list[genai_types.Content] = []
    if history:
        for m in history:
            role = "user" if m.get("role") == "user" else "model"
            contents.append(
                genai_types.Content(
                    role=role, parts=[genai_types.Part(text=m["content"])]
                )
            )
    contents.append(
        genai_types.Content(role="user", parts=[genai_types.Part(text=content)])
    )
    return contents


async def chat_stream(
    user_message: str,
    history: list[dict] | None = None,
    diary_content: str | None = None,
    context_block: str | None = None,
    system_prompt: str | None = None,
    config: dict | None = None,
) -> AsyncIterator[str]:
    """ストリーミングでテキスト chunk を yield する.

    現状は Gemini fallback 経路のみ対応。Claude 復帰時に \\_stream_claude を追加する。
    """
    content = build_user_content(
        user_message,
        diary_content=diary_content,
        context_block=context_block,
    )

    client = _get_gemini_client()
    contents = _build_gemini_contents(content, history)
    stream = client.models.generate_content_stream(
        model=_config_value(config, "gemini_model_coach", settings.gemini_model_coach),
        contents=contents,
        config=genai_types.GenerateContentConfig(
            system_instruction=system_prompt or SYSTEM_PROMPT,
            max_output_tokens=_config_max_tokens(config),
            temperature=float(
                _config_value(config, "temperature", settings.claude_temperature)
            ),
        ),
    )
    for chunk in stream:
        text = getattr(chunk, "text", None)
        if text:
            yield text


async def quick_text(
    prompt: str,
    *,
    max_tokens: int = 400,
    system_prompt: str | None = None,
    config: dict | None = None,
) -> str:
    """Run a short extraction/summarization task on the quick model."""
    if bool(_config_value(config, "use_gemini_fallback", settings.use_gemini_fallback)):
        client = _get_gemini_client()
        response = client.models.generate_content(
            model=_config_value(
                config,
                "gemini_model_quick",
                settings.gemini_model_quick,
            ),
            contents=[
                genai_types.Content(role="user", parts=[genai_types.Part(text=prompt)])
            ],
            config=genai_types.GenerateContentConfig(
                system_instruction=system_prompt,
                max_output_tokens=max_tokens,
                temperature=0.0,
            ),
        )
        return response.text or ""

    client = _get_claude_client()
    kwargs = {
        "model": _config_value(
            config,
            "claude_model_quick",
            settings.claude_model_quick,
        ),
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.0,
    }
    if system_prompt:
        kwargs["system"] = system_prompt
    response = client.messages.create(**kwargs)
    return response.content[0].text
