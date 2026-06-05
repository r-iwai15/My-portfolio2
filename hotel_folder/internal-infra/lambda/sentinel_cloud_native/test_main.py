import json

from main import lambda_handler


def _body(r):
    return json.loads(r["body"])


def test_iam_anomaly():
    r = lambda_handler({"detail": {"threatType": "IAM_ANOMALY"}}, None)
    assert _body(r)["action"] == "invalidate_sessions"


def test_unknown_ip():
    r = lambda_handler({"detail": {"threatType": "UNKNOWN_IP"}}, None)
    assert _body(r)["action"] == "block_at_edge"


def test_unrecognized_threat_defaults_to_audit_log():
    r = lambda_handler({"detail": {"threatType": "SOMETHING_ELSE"}}, None)
    assert _body(r)["action"] == "audit_log"


def test_missing_threat_type_defaults_to_audit_log():
    r = lambda_handler({"detail": {}}, None)
    assert _body(r)["action"] == "audit_log"
