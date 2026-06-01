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
