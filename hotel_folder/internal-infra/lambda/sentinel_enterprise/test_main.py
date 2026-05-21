import json

from main import lambda_handler


def test_critical_routes_to_revoke():
    out = lambda_handler({"detail": {"severity": "CRITICAL"}}, None)
    assert out["statusCode"] == 200
    assert out["body"]["action"] == "revoke_or_isolate"


def test_medium_routes_to_report():
    out = lambda_handler({"detail": {"severity": "MEDIUM"}}, None)
    assert out["body"]["action"] == "log_and_report"


def test_low_defaults():
    out = lambda_handler({"detail": {"severity": "LOW"}}, None)
    assert out["body"]["action"] == "log_only"
