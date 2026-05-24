"""Apple IAP signed-data verifier / App Store Server API client factories.

Wraps the official `app-store-server-library` to keep call-sites (router /
service) free of library-specific instantiation logic. All functions accept a
settings object so unit tests can pass mocked Settings.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import TYPE_CHECKING

from appstoreserverlibrary.api_client import AppStoreServerAPIClient
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier

if TYPE_CHECKING:
    from app.config import Settings


_CERTS_DIR = Path(__file__).resolve().parent.parent / "certs"


def load_root_certificates() -> list[bytes]:
    """`api/app/certs/*.cer` に同梱した Apple ルート証明書を全てロードする.

    本番運用時は AppleRootCA-G3.cer (および互換のため AppleIncRootCertificate.cer)
    を同ディレクトリに配置すること。テスト用にダミーを渡したい場合は
    `build_verifier(..., root_certificates=[...])` を直接指定する。
    """
    if not _CERTS_DIR.exists():
        return []
    return [p.read_bytes() for p in _CERTS_DIR.glob("*.cer")]


def _resolve_environment(env_str: str) -> Environment:
    return Environment.PRODUCTION if env_str == "Production" else Environment.SANDBOX


def build_verifier(
    settings: Settings,
    root_certificates: list[bytes] | None = None,
) -> SignedDataVerifier:
    """SignedDataVerifier を構築する.

    root_certificates 未指定時は `api/app/certs/*.cer` をロード。
    """
    roots = (
        root_certificates if root_certificates is not None else load_root_certificates()
    )
    return SignedDataVerifier(
        root_certificates=roots,
        enable_online_checks=True,
        environment=_resolve_environment(settings.apple_iap_env),
        bundle_id=settings.apple_bundle_id,
        app_apple_id=settings.apple_iap_app_apple_id,
    )


def build_api_client(settings: Settings) -> AppStoreServerAPIClient:
    """App Store Server API クライアントを構築する.

    `transactionId` を渡しての再検証 (`get_transaction_info` /
    `get_all_subscription_statuses`) に使用する。
    """
    signing_key = settings.apple_iap_private_key.encode("utf-8")
    return AppStoreServerAPIClient(
        signing_key=signing_key,
        key_id=settings.apple_iap_key_id,
        issuer_id=settings.apple_iap_issuer_id,
        bundle_id=settings.apple_bundle_id,
        environment=_resolve_environment(settings.apple_iap_env),
    )


@lru_cache(maxsize=1)
def _cached_verifier() -> SignedDataVerifier:
    from app.config import settings

    return build_verifier(settings)


def get_verifier() -> SignedDataVerifier:
    """FastAPI 依存性として使えるシングルトン取得関数."""
    return _cached_verifier()
