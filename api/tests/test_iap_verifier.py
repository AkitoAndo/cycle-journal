"""IAP verifier factory tests (A backend).

SignedDataVerifier / AppStoreServerAPIClient のファクトリーが正しい引数で
インスタンス化されることを検証する(library 本体の挙動はモック)。
"""

from unittest.mock import MagicMock, patch


@patch("app.services.iap_verifier.SignedDataVerifier")
def test_build_verifier_uses_sandbox_env_by_default(mock_sdv):
    """A: APPLE_IAP_ENV=Sandbox の場合 Environment.SANDBOX が渡される."""
    from appstoreserverlibrary.models.Environment import Environment

    from app.services.iap_verifier import build_verifier

    settings = MagicMock()
    settings.apple_iap_env = "Sandbox"
    settings.apple_bundle_id = "com.akitoando.CycleJournal"
    settings.apple_iap_app_apple_id = None

    build_verifier(settings, root_certificates=[b"dummy_root_cert"])

    call_kwargs = mock_sdv.call_args.kwargs
    assert call_kwargs["environment"] == Environment.SANDBOX
    assert call_kwargs["bundle_id"] == "com.akitoando.CycleJournal"
    assert call_kwargs["root_certificates"] == [b"dummy_root_cert"]


@patch("app.services.iap_verifier.SignedDataVerifier")
def test_build_verifier_uses_production_env(mock_sdv):
    """A: APPLE_IAP_ENV=Production の場合 Environment.PRODUCTION が渡される."""
    from appstoreserverlibrary.models.Environment import Environment

    from app.services.iap_verifier import build_verifier

    settings = MagicMock()
    settings.apple_iap_env = "Production"
    settings.apple_bundle_id = "com.akitoando.CycleJournal"
    settings.apple_iap_app_apple_id = 1234567890

    build_verifier(settings, root_certificates=[b"dummy_root_cert"])

    call_kwargs = mock_sdv.call_args.kwargs
    assert call_kwargs["environment"] == Environment.PRODUCTION
    assert call_kwargs["app_apple_id"] == 1234567890


@patch("app.services.iap_verifier.AppStoreServerAPIClient")
def test_build_api_client_uses_iap_credentials(mock_client):
    """A: AppStoreServerAPIClient が IAP 認証情報で構築される."""
    from app.services.iap_verifier import build_api_client

    settings = MagicMock()
    settings.apple_iap_env = "Sandbox"
    settings.apple_bundle_id = "com.akitoando.CycleJournal"
    settings.apple_iap_issuer_id = "test-issuer"
    settings.apple_iap_key_id = "TESTKEY01"
    settings.apple_iap_private_key = (
        "-----BEGIN PRIVATE KEY-----\nDUMMY\n-----END PRIVATE KEY-----\n"
    )

    build_api_client(settings)

    call_kwargs = mock_client.call_args.kwargs
    assert call_kwargs["issuer_id"] == "test-issuer"
    assert call_kwargs["key_id"] == "TESTKEY01"
    assert call_kwargs["bundle_id"] == "com.akitoando.CycleJournal"
    assert b"DUMMY" in call_kwargs["signing_key"]
