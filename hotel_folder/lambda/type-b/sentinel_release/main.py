"""
Type-B: Sentinel Release Lambda
EventBridge (Cron) によって定期実行され、DynamoDBの追跡テーブルを確認。
expire_at（有効期限）を過ぎているIPアドレスをWAFのブラックリストから解除し、
Cognitoユーザーを再有効化する。
"""

import os
import boto3
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_waf(): return boto3.client("wafv2", region_name=os.environ["REGION"])
def get_cognito(): return boto3.client("cognito-idp", region_name=os.environ.get("AWS_REGION", "ap-northeast-1"))
def get_table(): return boto3.resource("dynamodb", region_name=os.environ.get("AWS_REGION", "ap-northeast-1")).Table(os.environ["TRACKING_TABLE"])

def lambda_handler(event, context):
    now = int(datetime.now(timezone.utc).timestamp())
    table = get_table()
    
    # 本番環境ではGSIを活用すべきだが、今回は追跡件数が少ない想定でScanを使用
    response = table.scan()
    items = response.get("Items", [])
    
    # 期限切れのIPを抽出
    expired_items = [item for item in items if item.get("expire_at", 0) < now]

    if not expired_items:
        logger.info("No expired IPs found. Exiting.")
        return {"releasedCount": 0}

    waf = get_waf()
    ipset_id = os.environ["WAF_IPSET_ID"]
    ipset_name = os.environ["WAF_IPSET_NAME"]
    scope = os.environ["SCOPE"]

    # WAF IPセットの取得とロックトークンの確保
    waf_res = waf.get_ip_set(Name=ipset_name, Scope=scope, Id=ipset_id)
    lock_token = waf_res["LockToken"]
    addresses = set(waf_res["IPSet"].get("Addresses", []))

    released_ips = []
    
    for item in expired_items:
        ip_cidr = f"{item['ip']}/32"
        
        # 1. WAFからの解除
        if ip_cidr in addresses:
            addresses.remove(ip_cidr)
        released_ips.append(item['ip'])

        # 2. Cognitoユーザーの再有効化（恩赦）
        try:
            get_cognito().admin_enable_user(UserPoolId=os.environ["USER_POOL_ID"], Username=item['user_id'])
            logger.info("Re-enabled Cognito user: %s", item['user_id'])
        except Exception as e:
            logger.error("Failed to re-enable user %s: %s", item['user_id'], e)

        # 3. DynamoDBから追跡レコードを削除
        table.delete_item(Key={"ip": item["ip"]})

    # WAFに変更をコミット
    if released_ips:
        waf.update_ip_set(
            Name=ipset_name,
            Scope=scope,
            Id=ipset_id,
            LockToken=lock_token,
            Addresses=list(addresses)
        )

    logger.info("Sentinel Release complete. Released IPs: %s", released_ips)
    return {"releasedCount": len(released_ips), "releasedIps": released_ips}