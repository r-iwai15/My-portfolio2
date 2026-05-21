from main import lambda_handler


def test_iam_anomaly():
    r = lambda_handler({"detail": {"threatType": "IAM_ANOMALY"}}, None)
    assert r["body"]["action"] == "invalidate_sessions"


def test_unknown_ip():
    r = lambda_handler({"detail": {"threatType": "UNKNOWN_IP"}}, None)
    assert r["body"]["action"] == "block_at_edge"
