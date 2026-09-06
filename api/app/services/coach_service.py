"""Coach service - System prompt + Vertex AI model calls.

通常は Vertex AI Claude (Sonnet) を呼ぶが、quota 申請が下りるまでの暫定で
settings.use_gemini_fallback=True のとき Vertex AI Gemini に切り替わる。
"""

from collections.abc import AsyncIterator

import anthropic
from google import genai
from google.genai import types as genai_types

from app.config import settings
from app.services.coach_prompt_core import STATIC_CORE_PROMPT as SYSTEM_PROMPT


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
