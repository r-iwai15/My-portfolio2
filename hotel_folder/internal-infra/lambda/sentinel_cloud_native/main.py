"""
Sentinel Cloud-Native (Type-A internal): preventive response stub.
Maps events to session revoke / edge-block placeholders.
"""

import json


def lambda_handler(event, context):
    detail = event.get("detail", event)
    threat_type = str(detail.get("threatType") or "UNKNOWN").upper()

    if threat_type == "IAM_ANOMALY":
        action = "invalidate_sessions"
    elif threat_type == "UNKNOWN_IP":
        action = "block_at_edge"
    else:
        action = "audit_log"

    return {
        "statusCode": 200,
        "body": json.dumps({"threatType": threat_type, "action": action}),
    }
