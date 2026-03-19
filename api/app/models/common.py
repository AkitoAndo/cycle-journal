"""Common Pydantic models for API responses."""

from enum import Enum
from typing import Any

from pydantic import BaseModel


class CycleElement(str, Enum):
    soil = "soil"
    water = "water"
    root = "root"
    trunk = "trunk"
    branch = "branch"
    leaf = "leaf"
    fruit = "fruit"
    sky = "sky"


class ErrorDetail(BaseModel):
    field: str
    message: str


class ErrorBody(BaseModel):
    code: str
    message: str
    details: list[ErrorDetail] | None = None


class ErrorResponse(BaseModel):
    error: ErrorBody


class DataResponse(BaseModel):
    """Generic wrapper: {"data": ...}"""

    data: Any
