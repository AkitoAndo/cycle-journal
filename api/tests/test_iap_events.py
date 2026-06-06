"""ASSN side-effect mapping tests for #37 B3/B5."""

from app.services.iap_events import ga4_event_name, should_send_cancel_silent_push


def test_ga4_event_name_maps_subscription_lifecycle():
    assert ga4_event_name("SUBSCRIBED", None, "trial") == (
        "subscription_trial_started"
    )
    assert ga4_event_name("DID_RENEW", None, "active") == "subscription_renewed"
    assert (
        ga4_event_name(
            "DID_CHANGE_RENEWAL_STATUS",
            "AUTO_RENEW_DISABLED",
            "cancelled",
        )
        == "subscription_cancelled"
    )
    assert ga4_event_name("REFUND", None, "revoked") == "subscription_refunded"


def test_ga4_event_name_distinguishes_trial_conversion():
    """#37 KPI: トライアル中の更新は転換、それ以外の更新は通常更新."""
    assert (
        ga4_event_name("DID_RENEW", None, "active", "trial")
        == "trial_converted_to_paid"
    )
    assert (
        ga4_event_name("DID_RENEW", None, "active", "active")
        == "subscription_renewed"
    )
    # prior_status 省略時 (後方互換) は通常更新
    assert ga4_event_name("DID_RENEW", None, "active") == "subscription_renewed"


def test_ga4_event_name_expired_uses_prior_status():
    """EXPIRED はトライアルのまま失効か課金後失効かを直前状態で区別."""
    assert (
        ga4_event_name("EXPIRED", None, "expired", "trial")
        == "trial_expired_without_conversion"
    )
    assert (
        ga4_event_name("EXPIRED", None, "expired", "active")
        == "subscription_expired"
    )


def test_cancel_silent_push_only_for_auto_renew_disabled():
    assert should_send_cancel_silent_push(
        "DID_CHANGE_RENEWAL_STATUS",
        "AUTO_RENEW_DISABLED",
    )
    assert not should_send_cancel_silent_push(
        "DID_CHANGE_RENEWAL_STATUS",
        "AUTO_RENEW_ENABLED",
    )
    assert not should_send_cancel_silent_push("DID_RENEW", None)
