"""Vocabulary extraction for coach response linting."""

from __future__ import annotations

from functools import lru_cache

CONTENT_POS = {"名詞", "動詞", "形容詞", "副詞"}

ALLOWED_CORE_LEMMAS = {
    "ある",
    "あり",
    "いる",
    "い",
    "見る",
    "見える",
    "言葉",
    "する",
    "置く",
    "片づく",
    "片付く",
    "残る",
    "届く",
    "止める",
    "難しい",
    "しんどい",
}

STRUCTURAL_LEMMAS = {
    "いま",
    "今",
    "今日",
    "ここ",
    "こと",
    "もの",
    "一つ",
    "二つ",
    "三つ",
    "まま",
    "そう",
    "感じる",
    "話",
}


@lru_cache(maxsize=1)
def _tokenizer():
    from janome.tokenizer import Tokenizer

    return Tokenizer()


def content_lemmas(text: str) -> set[str]:
    lemmas: set[str] = set()
    for token in _tokenizer().tokenize(text):
        part = str(token.part_of_speech).split(",", 1)[0]
        if part not in CONTENT_POS:
            continue
        surface = str(token.surface).strip()
        if not surface:
            continue
        base = str(token.base_form)
        lemmas.add(surface)
        if base != "*":
            lemmas.add(base)
    return lemmas


def allowed_lemmas(sources: list[str | None]) -> set[str]:
    allowed = set(ALLOWED_CORE_LEMMAS)
    allowed.update(STRUCTURAL_LEMMAS)
    for source in sources:
        if source:
            allowed.update(content_lemmas(source))
    return allowed
