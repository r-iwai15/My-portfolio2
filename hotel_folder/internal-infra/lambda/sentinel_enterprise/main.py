"""
Sentinel Enterprise (Type-B internal): route Security Hub / GuardDuty style events by severity.
Stub implementation for IaC validation — wire to EventBridge + Slack/Jira in production.
"""


def lambda_handler(event, context):
    detail = event.get("detail", event)
    severity = (detail.get("severity") or detail.get("Severity") or "MEDIUM").upper()

    if severity in ("CRITICAL", "HIGH"):
        action = "revoke_or_isolate"
    elif severity == "MEDIUM":
        action = "log_and_report"
    else:
        action = "log_only"

    return {
        "statusCode": 200,
        "body": {
            "severity": severity,
            "action": action,
            "source": detail.get("source", "unknown"),
        },
    }
