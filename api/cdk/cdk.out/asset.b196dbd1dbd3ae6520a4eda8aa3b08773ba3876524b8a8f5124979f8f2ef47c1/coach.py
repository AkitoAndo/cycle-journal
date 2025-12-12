"""Coach handler - AI coaching endpoint."""

import json
import os


def handler(event, context):
    """Coach chat endpoint.

    POST /coach
    Body: { "message": "ユーザーのメッセージ" }
    """
    try:
        # リクエストボディをパース
        body = json.loads(event.get("body", "{}"))
        user_message = body.get("message", "")

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

        # TODO: Bedrock呼び出しを実装
        # 現在はモックレスポンス
        response_message = f"「{user_message[:20]}...」について、もう少し詳しく教えてくれる？"

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
                        "model": "mock",
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
