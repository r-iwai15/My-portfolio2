import json

from main import lambda_handler


def _body(out):
    return json.loads(out["body"])


def test_critical_routes_to_revoke():
    out = lambda_handler({"detail": {"severity": "CRITICAL"}}, None)
    assert out["statusCode"] == 200
    assert _body(out)["action"] == "revoke_or_isolate"


def test_medium_routes_to_report():
    out = lambda_handler({"detail": {"severity": "MEDIUM"}}, None)
    assert _body(out)["action"] == "log_and_report"


def test_low_defaults():
    out = lambda_handler({"detail": {"severity": "LOW"}}, None)
    assert _body(out)["action"] == "log_only"


def test_numeric_security_hub_normalized_score():
    out = lambda_handler({"detail": {"severity": 75}}, None)
    assert _body(out)["action"] == "revoke_or_isolate"


def test_security_hub_label_dict():
    out = lambda_handler({"detail": {"severity": {"Label": "HIGH", "Normalized": 70}}}, None)
    assert _body(out)["action"] == "revoke_or_isolate"


def test_missing_severity_defaults_to_medium():
    out = lambda_handler({"detail": {}}, None)
    assert _body(out)["severity"] == "MEDIUM"
