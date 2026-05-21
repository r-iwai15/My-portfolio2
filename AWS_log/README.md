AWS Serverless Security Log Analysis with Terraform

📝 概要 (Overview)

Terraformを使用して、AWS環境におけるセキュアかつ低コストな「サーバーレスログ分析基盤」をコード（IaC）で構築するプロジェクトです。

AWS Certified Security - Specialty (SCS) で求められるベストプラクティスに基づき、インフラの要である AWS CloudTrail（API操作ログ） と Amazon VPC Flow Logs（ネットワーク通信ログ） を一元的に収集し、Amazon Athenaを用いてSQLで高速に分析する環境を構築します。

✨ アーキテクチャとアピールポイント

1. セキュリティのベストプラクティス実装

• パブリックアクセスブロック (BPA) の完全有効化: 意図しないS3バケットの公開をTerraformレベルで強制的にブロック。

• 混乱した代理（Confused Deputy）問題の対策: S3バケットポリシーにおいて aws:SourceArn と aws:SourceAccount を厳格に指定し、外部アカウントからの不正なログ書き込みを防止。

• 最小権限の原則: CloudTrailとVPC Flow Logsに必要な権限 (s3:PutObject, s3:GetBucketAcl) のみを付与。

2. 極限まで最適化されたコスト管理

ポートフォリオや検証用として個人環境でも安心して動かせるよう、維持費を「ほぼゼロ」に抑える設計を行っています。

• サーバーレスアーキテクチャ: 常時稼働のSIEM（OpenSearchやEC2）を持たず、Athena（スキャンしたデータ量に対する従量課金）を採用。

• S3ライフサイクルルール: 保存されたログは「1日後に自動削除（Expiration）」されるよう設定し、ストレージの肥大化を防止。

• 証跡の最適化: CloudTrailは無料枠となる「1つ目の証跡」を利用し、マルチリージョン設定をOFFにすることで転送コストを抑制。

🛠 使用技術 (Tech Stack)

• Infrastructure as Code: Terraform

• AWS Services: Amazon S3, AWS CloudTrail, Amazon VPC Flow Logs, Amazon Athena

🚀 構築・実行手順 (How to Use)

1. インフラのデプロイ

Terraformコマンドを使用して、AWS上にログ収集・分析基盤を一括構築します。

[bash]
terraform init
terraform plan
terraform apply


2. Athenaでのテーブル作成 (DDL)

数分待機してS3にログが出力され始めたら、AWSコンソールのAthenaクエリエディタ（ワークグループ: security-log-analysis-workgroup）を開き、ログの構造を定義します。

▼ CloudTrail用のテーブル定義例
(※ <バケット名> と <アカウントID> は環境に合わせて変更してください)

[sql]
CREATE EXTERNAL TABLE cloudtrail_logs (
    eventVersion STRING,
    userIdentity STRUCT<type: STRING, principalId: STRING, arn: STRING, accountId: STRING, invokedBy: STRING, accessKeyId: STRING, userName: STRING, sessionContext: STRUCT<attributes: STRUCT<mfaAuthenticated: STRING, creationDate: STRING>, sessionIssuer: STRUCT<type: STRING, principalId: STRING, arn: STRING, accountId: STRING, userName: STRING>, ec2RoleDelivery: STRING, webIdFederationData: MAP<STRING,STRING>>>,
    eventTime STRING,
    eventSource STRING,
    eventName STRING,
    awsRegion STRING,
    sourceIpAddress STRING,
    userAgent STRING,
    errorCode STRING,
    errorMessage STRING,
    requestParameters STRING,
    responseElements STRING,
    additionalEventData STRING,
    requestId STRING,
    eventId STRING,
    resources ARRAY<STRUCT<arn: STRING, accountId: STRING, type: STRING>>,
    eventType STRING,
    apiVersion STRING,
    readOnly STRING,
    recipientAccountId STRING,
    serviceEventDetails STRING,
    sharedEventID STRING,
    vpcEndpointId STRING,
    tlsDetails STRUCT<tlsVersion: STRING, cipherSuite: STRING, clientProvidedHostHeader: STRING>
)
ROW FORMAT SERDE 'com.amazon.emr.hive.serde.CloudTrailSerde'
STORED AS INPUTFORMAT 'com.amazon.emr.cloudtrail.CloudTrailInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://<バケット名>/AWSLogs/<アカウントID>/CloudTrail/'
TBLPROPERTIES ('classification'='cloudtrail');


3. ログの分析 (SQL Query)

テーブル作成後、実際にセキュリティ分析を行います。

▼ [例] 最近実行されたAWS API操作（誰が・いつ・何をしたか）を特定する

[sql]
SELECT 
    eventtime AS "発生日時",
    eventsource AS "対象サービス",
    eventname AS "実行されたアクション",
    sourceipaddress AS "送信元IP",
    useragent AS "使用ツール"
FROM cloudtrail_logs
ORDER BY eventtime DESC
LIMIT 20;


4. クリーンアップ (環境の破棄)

検証完了後、無駄なリソースを残さないために一括削除します。
（※Athena上で作成したテーブルやワークグループは、必要に応じて手動で削除してから実行してください）

[bash]
terraform destroy
