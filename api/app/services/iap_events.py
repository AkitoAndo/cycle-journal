"""ASSN V2 notification side-effect mapping for analytics and push."""

from __future__ import annotations

from typing import Any

from app.services.iap_subscription import normalize_enum


def ga4_event_name(
    notification_type: Any | None,
    subtype: Any | None,
    status: str,
) -> str | None:
    """Map App Store Server Notifications V2 to GA4 event names."""
    nt = normalize_enum(notification_type)
    st = normalize_enum(subtype)

    if nt == "SUBSCRIBED":
        return (
            "subscription_trial_started"
            if status == "trial"
            else "subscription_started"
        )
    if nt == "DID_RENEW":
        return "subscription_renewed"
    if nt == "DID_CHANGE_RENEWAL_STATUS":
        if st == "AUTO_RENEW_DISABLED":
            return "subscription_cancelled"
        if st == "AUTO_RENEW_ENABLED":
            return "subscription_reactivated"
    if nt in {"REFUND", "REVOKE", "REFUND_REVERSED"}:
        return (
            "subscription_refund_reversed"
            if nt == "REFUND_REVERSED"
            else "subscription_refunded"
        )
    if nt == "EXPIRED":
        return (
            "trial_expired_without_conversion"
            if status == "expired"
            else "subscription_expired"
        )
    if nt == "DID_FAIL_TO_RENEW":
        return "subscription_billing_issue"
    if nt == "GRACE_PERIOD_EXPIRED":
        return "subscription_grace_period_expired"
    return None


def should_send_cancel_silent_push(
    notification_type: Any | None,
    subtype: Any | None,
) -> bool:
    """Return true when local trial notifications should be cancelled on device."""
    nt = normalize_enum(notification_type)
    st = normalize_enum(subtype)
    return nt == "DID_CHANGE_RENEWAL_STATUS" and st == "AUTO_RENEW_DISABLED"
