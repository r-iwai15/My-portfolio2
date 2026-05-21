"""
Type-B: Sentinel Executioner Lambda

CloudWatch Logsのサブスクリプションフィルターにより、
プロンプトインジェクション攻撃を検知した際にトリガーされる。

攻撃者のIPをWAFブラックリストに追加し、Cognitoユーザーを即時無効化する。
DynamoDB追跡テーブルにブロック時刻を記録し、
Release Lambdaが24時間後にIPを解放できるようにする。

Env:
  WAF_IPSET_ID    - WAF IPセットID
  WAF_IPSET_NAME  - WAF IPセット名
  SCOPE           - WAFスコープ (CLOUDFRONT)
  REGION          - WAFが存在するリージョン (us-east-1)
  USER_POOL_ID    - CognitoユーザープールID
  TRACKING_TABLE  - ブロック追跡用DynamoDBテーブル名
  TTL_HOURS       - ブロック有効期間（時間）
"""

import base64
import gzip
import json
import logging
import os
import boto3
from datetime import datetime, timezone, timedelta

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_waf():
    return boto3.client("wafv2", region_name=os.environ["REGION"])

def get_cognito():
    return boto3.client("cognito-idp", region_name=os.environ.get("AWS_REGION", "ap-northeast-1"))

def get_table():
    dynamo = boto3.resource("dynamodb", region_name=os.environ.get("AWS_REGION", "ap-northeast-1"))
    return dynamo.Table(os.environ["TRACKING_TABLE"])


def decode_cloudwatch_event(event: dict) -> list[dict]:
    """CloudWatch Logsサブスクリプションイベントをデコードしてログエントリ一覧を返す"""
    compressed = base64.b64decode(event["awslogs"]["data"])
    payload    = gzip.decompress(compressed)
    log_data   = json.loads(payload)
    return log_data.get("logEvents", [])


def parse_log_entry(message: str) -> dict | None:
    """ログメッセージをJSONとしてパース。不正な形式はスキップ"""
    try:
        return json.loads(message)
    except (json.JSONDecodeError, TypeError):
        return None


def block_ip_in_waf(source_ip: str) -> None:
    """攻撃者IPをWAF IPセット（ブラックリスト）に追加する"""
    ipset_id   = os.environ["WAF_IPSET_ID"]
    ipset_name = os.environ["WAF_IPSET_NAME"]
    scope      = os.environ["SCOPE"]

    waf        = get_waf()
    response   = waf.get_ip_set(Name=ipset_name, Scope=scope, Id=ipset_id)
    lock_token = response["LockToken"]

    existing_addresses = set(response["IPSet"].get("Addresses", []))
    new_cidr           = f"{source_ip}/32"

    if new_cidr in existing_addresses:
        logger.info("IP %s is already blocked. Skipping WAF update.", source_ip)
        return

    updated_addresses = list(existing_addresses | {new_cidr})
    waf.update_ip_set(
        Name      = ipset_name,
        Scope     = scope,
        Id        = ipset_id,
        LockToken = lock_token,
        Addresses = updated_addresses,
    )
    logger.info("Blocked IP in WAF: %s (total blocked: %d)", source_ip, len(updated_addresses))


def disable_cognito_user(user_id: str) -> None:
    """攻撃者のCognitoアカウントを即時無効化する"""
    cognito = get_cognito()
    try:
        cognito.admin_disable_user(UserPoolId=os.environ["USER_POOL_ID"], Username=user_id)
        logger.info("Disabled Cognito user: %s", user_id)
    except cognito.exceptions.UserNotFoundException:
        logger.warning("Cognito user not found: %s", user_id)


def record_block_in_dynamodb(source_ip: str, user_id: str) -> None:
    """ブロック情報をDynamoDBに記録する"""
    ttl_hours = int(os.environ.get("TTL_HOURS", "24"))
    now       = datetime.now(timezone.utc)
    expire_at = int((now + timedelta(hours=ttl_hours)).timestamp())

    get_table().put_item(Item={
        "ip":         source_ip,
        "user_id":    user_id,
        "blocked_at": now.isoformat(),
        "expire_at":  expire_at,
    })
    logger.info("Recorded block in DynamoDB: ip=%s", source_ip)


def lambda_handler(event, context):
    log_events = decode_cloudwatch_event(event)
    logger.info("Processing %d log events from CloudWatch.", len(log_events))

    blocked_ips   = []
    blocked_users = []

    for log_event in log_events:
        entry = parse_log_entry(log_event.get("message", ""))
        if entry is None:
            continue

        source_ip    = entry.get("sourceIp")
        user_id      = entry.get("userId")
        user_message = entry.get("userMessage", "")

        if not source_ip or not user_id:
            logger.warning("Missing sourceIp or userId in log entry. Skipping.")
            continue

        logger.warning(
            "INJECTION DETECTED | ip=%s | userId=%s | message=%s",
            source_ip, user_id, user_message[:200],
        )

        # 1. WAFブラックリストへ追加
        try:
            block_ip_in_waf(source_ip)
            blocked_ips.append(source_ip)
        except Exception as e:
            logger.error("Failed to block IP %s in WAF: %s", source_ip, e)
            continue

        # 2. DynamoDB追跡テーブルへ記録
        try:
            record_block_in_dynamodb(source_ip, user_id)
        except Exception as e:
            logger.error("Failed to record block for IP %s: %s (IP remains blocked in WAF)", source_ip, e)

        # 3. Cognitoユーザー無効化
        try:
            disable_cognito_user(user_id)
            blocked_users.append(user_id)
        except Exception as e:
            logger.error("Failed to disable Cognito user %s: %s", user_id, e)

    logger.info(
        "Sentinel execution complete. Blocked IPs: %s | Disabled users: %s",
        blocked_ips, blocked_users,
    )
    return {"blockedIps": blocked_ips, "disabledUsers": blocked_users}
