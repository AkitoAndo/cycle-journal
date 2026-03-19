"""Application exceptions and error handlers."""

from fastapi import Request
from fastapi.responses import JSONResponse


class AppError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code = code
        self.message = message
        self.status_code = status_code


class ValidationError(AppError):
    def __init__(self, message: str):
        super().__init__("ValidationError", message, 400)


class AuthenticationError(AppError):
    def __init__(self, message: str = "Authentication required"):
        super().__init__("AuthenticationError", message, 401)


class TokenExpiredError(AppError):
    def __init__(self):
        super().__init__("TokenExpired", "Identity token has expired", 401)


class InvalidTokenError(AppError):
    def __init__(self, message: str = "Invalid token"):
        super().__init__("InvalidToken", message, 401)


class NotFoundError(AppError):
    def __init__(self, resource: str = "Resource"):
        super().__init__("NotFound", f"{resource} not found", 404)


class InternalError(AppError):
    def __init__(self, message: str = "Internal server error"):
        super().__init__("InternalError", message, 500)


async def app_error_handler(_request: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": exc.code, "message": exc.message}},
    )
