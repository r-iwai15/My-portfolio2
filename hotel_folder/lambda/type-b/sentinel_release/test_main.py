"""
sentinel_release のユニットテスト

ユーザーの実装に合わせたテスト:
- expire_at (epoch秒) で期限判定
- 早期リターンは {"releasedCount": 0}
- 通常リターンは {"releasedCount": N, "releasedIps": [...]}
- reEnabledUsers キーは存在しない → admin_get_user で直接確認
"""

import os
import pytest
import boto3
from moto import mock_aws
from datetime import datetime, timezone, timedelta

os.environ.update({
    "WAF_IPSET_ID":   "test-ipset-id",
    "WAF_IPSET_NAME": "test-ipset-name",
    "SCOPE":          "REGIONAL",
    "REGION":         "ap-northeast-1",
    "USER_POOL_ID":   "ap-northeast-1_testpool",
    "TRACKING_TABLE": "hotel-innovative-blocked-ips",
    "AWS_REGION":     "ap-northeast-1",
})

from main import lambda_handler


# =====================================================
# ヘルパー
# =====================================================

def make_ip_set(waf_client):
    res = waf_client.create_ip_set(
        Name             = "test-ipset-name",
        Scope            = "REGIONAL",
        IPAddressVersion = "IPV4",
        Addresses        = [],
    )
    return res["Summary"]["Id"]


def make_tracking_table(dynamo):
    return dynamo.create_table(
        TableName            = "hotel-innovative-blocked-ips",
        KeySchema            = [{"AttributeName": "ip", "KeyType": "HASH"}],
        AttributeDefinitions = [{"AttributeName": "ip", "AttributeType": "S"}],
        BillingMode          = "PAY_PER_REQUEST",
    )


def make_user_pool(cognito_client):
    res = cognito_client.create_user_pool(PoolName="test-pool")
    return res["UserPool"]["Id"]


def add_expired_ip(table, ip, user_id):
    """TTL切れのIPを追加 (expire_at が過去)"""
    now = int(datetime.now(timezone.utc).timestamp())
    table.put_item(Item={
        "ip":        ip,
        "user_id":   user_id,
        "expire_at": now - 3600,  # 1時間前に期限切れ
    })


def add_active_ip(table, ip, user_id):
    """まだ有効なIPを追加 (expire_at が未来)"""
    now = int(datetime.now(timezone.utc).timestamp())
    table.put_item(Item={
        "ip":        ip,
        "user_id":   user_id,
        "expire_at": now + 82800,  # 23時間後に期限切れ
    })


# =====================================================
# テスト
# =====================================================

class TestLambdaHandler:
    def setup_method(self, method=None):
        self.mock = mock_aws()
        self.mock.start()

        region = os.environ["AWS_REGION"]

        # WAF IPセット作成
        self.waf    = boto3.client("wafv2", region_name=region)
        ipset_id    = make_ip_set(self.waf)
        os.environ["WAF_IPSET_ID"] = ipset_id

        # WAFにブロック済みIPを事前登録
        res = self.waf.get_ip_set(Name="test-ipset-name", Scope="REGIONAL", Id=ipset_id)
        self.waf.update_ip_set(
            Name      = "test-ipset-name",
            Scope     = "REGIONAL",
            Id        = ipset_id,
            LockToken = res["LockToken"],
            Addresses = ["1.2.3.4/32", "5.6.7.8/32"],
        )

        # DynamoDB
        dynamo     = boto3.resource("dynamodb", region_name=region)
        self.table = make_tracking_table(dynamo)

        # Cognito
        self.cognito = boto3.client("cognito-idp", region_name=region)
        pool_id      = make_user_pool(self.cognito)
        os.environ["USER_POOL_ID"] = pool_id

        self.cognito.admin_create_user(UserPoolId=pool_id, Username="user-victim")
        self.cognito.admin_disable_user(UserPoolId=pool_id, Username="user-victim")

    def teardown_method(self, method=None):
        self.mock.stop()

    # --------------------------------------------------

    def test_TTL超過IPがWAFから解放される(self):
        add_expired_ip(self.table, "1.2.3.4", "user-victim")

        result = lambda_handler({}, None)

        assert "1.2.3.4" in result["releasedIps"]

        res = self.waf.get_ip_set(
            Name=os.environ["WAF_IPSET_NAME"], Scope=os.environ["SCOPE"], Id=os.environ["WAF_IPSET_ID"]
        )
        assert "1.2.3.4/32" not in res["IPSet"]["Addresses"]

    def test_TTL未満のIPは解放されない(self):
        add_active_ip(self.table, "1.2.3.4", "user-victim")

        result = lambda_handler({}, None)

        # 有効期限内のIPは解放されず releasedCount が 0
        assert result["releasedCount"] == 0

        # WAFに残っていることを確認
        res = self.waf.get_ip_set(
            Name=os.environ["WAF_IPSET_NAME"], Scope=os.environ["SCOPE"], Id=os.environ["WAF_IPSET_ID"]
        )
        assert "1.2.3.4/32" in res["IPSet"]["Addresses"]

    def test_解放後にDynamoDBのレコードが削除される(self):
        add_expired_ip(self.table, "1.2.3.4", "user-victim")

        lambda_handler({}, None)

        res = self.table.get_item(Key={"ip": "1.2.3.4"})
        assert "Item" not in res

    def test_解放後にCognitoユーザーが再有効化される(self):
        add_expired_ip(self.table, "1.2.3.4", "user-victim")

        lambda_handler({}, None)

        # admin_get_user で直接 Enabled フラグを確認
        user = self.cognito.admin_get_user(
            UserPoolId=os.environ["USER_POOL_ID"], Username="user-victim"
        )
        assert user["Enabled"] is True

    def test_解放対象がない場合はreleasedCountが0(self):
        result = lambda_handler({}, None)

        assert result["releasedCount"] == 0
