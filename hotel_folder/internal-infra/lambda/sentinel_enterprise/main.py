"""
Sentinel Enterprise (Type-B internal): route Security Hub / GuardDuty style events by severity.
Stub implementation for IaC validation — wire to EventBridge + Slack/Jira in production.
"""

import json


def _normalize_severity(raw):
    """severity を大文字ラベルに正規化する。

    Security Hub / GuardDuty は severity を文字列ラベル・数値・
    {"Label": ..., "Normalized": ...} 形式のいずれでも返しうるため、
    すべてを安全に扱えるようにする（.upper() を生値に直接呼ばない）。
    """
    if raw is None:
        return "MEDIUM"

    # Security Hub: {"Label": "HIGH", "Normalized": 70} 形式
    if isinstance(raw, dict):
        label = raw.get("Label") or raw.get("label")
        if label:
            return str(label).upper()
        raw = raw.get("Normalized") or raw.get("normalized")

    # 数値（GuardDuty 1.0-8.9 / Security Hub Normalized 0-100）
    if isinstance(raw, (int, float)):
        score = float(raw)
        if score >= 70:
            return "CRITICAL" if score >= 90 else "HIGH"
        if score >= 40 or (4.0 <= score < 70):
            return "MEDIUM"
        if score > 0:
            return "LOW"
        return "INFORMATIONAL"

    return str(raw).upper()


def lambda_handler(event, context):
    detail = event.get("detail", event)
    severity = _normalize_severity(
        detail.get("severity") if detail.get("severity") is not None else detail.get("Severity")
    )

    if severity in ("CRITICAL", "HIGH"):
        action = "revoke_or_isolate"
    elif severity == "MEDIUM":
        action = "log_and_report"
    else:
        action = "log_only"

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "severity": severity,
                "action": action,
                "source": detail.get("source", "unknown"),
            }
        ),
    }
