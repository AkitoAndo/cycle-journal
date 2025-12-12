"""Coach handler - AI coaching endpoint with Bedrock integration."""

import json
import os
import boto3

# Bedrock クライアント
bedrock_runtime = boto3.client(
    "bedrock-runtime",
    region_name="ap-northeast-1",
)

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


def call_bedrock(user_message: str, diary_content: str | None = None) -> str:
    """Bedrockを呼び出してコーチの応答を取得."""
    model_id = os.environ.get(
        "BEDROCK_MODEL_ID",
        "anthropic.claude-3-haiku-20240307-v1:0",
    )

    # ユーザーメッセージを構築
    messages_content = user_message
    if diary_content:
        messages_content = f"""【日記の内容】
{diary_content}

【ユーザーのメッセージ】
{user_message}"""

    request_body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 500,
        "system": SYSTEM_PROMPT,
        "messages": [
            {
                "role": "user",
                "content": messages_content,
            }
        ],
        "temperature": 0.7,
    }

    response = bedrock_runtime.invoke_model(
        modelId=model_id,
        body=json.dumps(request_body),
        contentType="application/json",
        accept="application/json",
    )

    response_body = json.loads(response["body"].read())
    return response_body["content"][0]["text"]


def handler(event, context):
    """Coach chat endpoint.

    POST /coach
    Body: {
        "message": "ユーザーのメッセージ",
        "diary_content": "日記の内容（オプション）"
    }
    """
    try:
        # リクエストボディをパース
        body = json.loads(event.get("body", "{}"))
        user_message = body.get("message", "")
        diary_content = body.get("diary_content")

        if not user_message:
            return {
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*",
                },
                "body": json.dumps({
                    "error": {
                        "code": "ValidationError",
                        "message": "message is required",
                    }
                }),
            }

        # Bedrockを呼び出し
        response_message = call_bedrock(user_message, diary_content)

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps({
                "data": {
                    "message": response_message,
                    "metadata": {
                        "stage": os.environ.get("STAGE", "unknown"),
                        "model": os.environ.get("BEDROCK_MODEL_ID", "claude-3-haiku"),
                    }
                }
            }),
        }

    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps({
                "error": {
                    "code": "InvalidJSON",
                    "message": "Request body must be valid JSON",
                }
            }),
        }
    except Exception as e:
        # エラーログを出力
        print(f"Error: {e}")

        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps({
                "error": {
                    "code": "InternalError",
                    "message": str(e),
                }
            }),
        }
