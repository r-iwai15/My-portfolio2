# AI-Driven Internal Infrastructure Architectures

## 社内 Terraform の使い分け（最初に読む）

| パス | 役割 |
|------|------|
| **`internal-infra/terraform/`** | Type-B Enterprise / Type-A Cloud-Native **比較の本線**（今後の拡張はここ） |
| **`../terraform/corp-internal`** | Session Manager 向け VPCE 等の **最小 1 スタック**（両系統に共通しうる足場） |

実装・デプロイの**具体的な手順**は [`docs/IMPLEMENTATION_GUIDE.md`](../docs/IMPLEMENTATION_GUIDE.md) を参照してください。

## プロジェクト概要

本プロジェクトは、ホテル予約システム（Type-B / Type-A）と**同じ設計哲学を社内インフラに適用した**比較検証プロジェクトです。

> 「どんな企業文化を持つ組織のために、誰が働くかによって、社内インフラの思想は根本から変わるべきである」

外部顧客向けシステムでは「どんなホスピタリティを提供するか」がアーキテクチャを決めました。社内インフラでは**「どんな企業文化・働き方を支えるか」**がアーキテクチャを決めます。

---

## 2つのアーキテクチャモデル

### Type-B: Enterprise Edition（伝統・統制型）

**「変えないことが信頼の証明。既存資産を守りながら、見えないところだけ進化する。」**

- **想定モデル:** 大手日系製造業・金融・官公庁。20年以上稼働するオンプレミスサーバーと Active Directory を持ち、急激な変化がコンプライアンス違反やシステム障害に直結する環境。

**設計思想**

- 既存の Active Directory とオンプレミスを AWS とハイブリッド接続する
- 社員は今まで通りの操作感でシステムを使う（変化を感じさせない）
- セキュリティと監視レイヤーだけを AI で強化する
- コンプライアンス（CIS Benchmark・NIST）への自動準拠を徹底する

**セキュリティの思想:** 発見的統制。怪しい挙動を検知して対応する。変更管理プロセスをインフラで強制する。

---

### Type-A: Cloud-Native Edition（先端・自律型）

**「VPNをなくす。場所を問わない。IDだけを信頼する。」**

- **想定モデル:** SaaS 系スタートアップ・デジタルネイティブ企業・フルリモート組織。オンプレなし、Active Directory なし、全員が MacBook と Slack で働く環境。

**設計思想**

- VPN を廃止し、ID とデバイス証明書だけでアクセスを制御する（ZTNA）
- 開発者が Guardrails（上限・制約）の範囲内で自律的にリソースをプロビジョニングできる
- セキュリティをコードとして実装し、人手の運用を最小化する
- GitHub Actions + Terraform で全インフラをコードで管理する

**セキュリティの思想:** 予防的統制。そもそも侵入させない設計。信頼はネットワーク位置ではなく ID で決まる。

---

## アーキテクチャ比較表

| 項目 | Type-B（伝統・統制型） | Type-A（先端・自律型） |
|------|------------------------|----------------------------|
| 想定組織 | 大手日系企業・金融・官公庁 | SaaS 系スタートアップ・フルリモート |
| 既存資産 | Active Directory・オンプレサーバーあり | クラウドネイティブ・レガシーなし |
| ネットワーク | ハイブリッド（Direct Connect + VPN） | VPN なし・AWS Verified Access（ZTNA） |
| ID 管理 | AD Connector（既存 AD と連携） | IAM Identity Center + SCIM（Okta / Google Workspace） |
| 開発者体験 | 承認プロセス必須・変更管理あり | セルフサービス・Guardrails 内で自由 |
| セキュリティ | 検知・対応型（SIEM 的アプローチ） | 予防・自動化型（Policy as Code） |
| コンプライアンス | CIS Benchmark・NIST 自動監査 | AWS SCP によるポリシー強制 |
| AI の役割 | 脅威の自律検知・対応（Sentinel Enterprise） | セルフサービスポータルの AI アシスト |

---

## Type-B: Enterprise Edition — 詳細設計（概要）

### ネットワーク構成

```
オンプレミス（既存環境）
    │
    ├── Direct Connect（専用線）または Site-to-Site VPN
    │
AWS Transit Gateway（ハブ）
    │
    ├── 管理アカウント VPC
    │     └── AD Connector（既存 AD へのプロキシ）
    │
    ├── セキュリティアカウント VPC
    │     ├── AWS Network Firewall
    │     ├── GuardDuty（全アカウント集約）
    │     └── Security Hub（コンプライアンス監視）
    │
    └── ワークロードアカウント VPC
          ├── 社内アプリケーション（ECS Fargate）
          └── RDS（既存 DB スキーマ互換）
```

### 主要コンポーネント

- **Identity:** AD Connector、`aws_iam_identity_center`、MFA 強制（TOTP / FIDO2）
- **Network:** Transit Gateway、Network Firewall、VPN / DX、VPC Flow Logs
- **Security（Sentinel Enterprise）:** GuardDuty・Security Hub 集約、Config、CloudTrail、`sentinel_enterprise` Lambda（重要度別対応）
- **Compliance:** Config Conformance Pack、メトリクスアラーム、Organizations SCP

### Sentinel Enterprise フロー

```
GuardDuty / Security Hub 検知
    │
EventBridge Rule（重要度でフィルタ）
    │
Lambda: sentinel_enterprise
    │
    ├── [CRITICAL] IAM ロール権限を即時剥奪 → Slack に緊急通知
    ├── [HIGH]     Security Group でネットワーク隔離 → Jira チケット自動作成
    └── [MEDIUM]   CloudWatch Logs に記録 → 週次セキュリティレポートに集約
```

---

## Type-A: Cloud-Native Edition — 詳細設計（概要）

### ネットワーク構成

```
Internet
    │
AWS Verified Access（VPN なし・ID ベース ZTNA）
    │
    ├── 認証: IAM Identity Center + デバイス証明書
    │
Private Subnet（IGW なし）
    │
    ├── 社内アプリ（Lambda / ECS Fargate）
    ├── 社内 RAG システム（Bedrock Knowledge Base）
    └── 開発者セルフサービスポータル（Lambda + API Gateway）
    │
VPC Endpoints（PrivateLink）
```

### 主要コンポーネント

- **Identity:** IAM Identity Center、SCIM、Verified Access、MFA・短いセッション
- **Network:** IGW なし、VPC Endpoints、Network Firewall
- **Application:** Bedrock Knowledge Base、Claude、`rag_query` Lambda、DynamoDB 会話履歴
- **Developer Self-Service:** `provisioner` Lambda、Service Catalog、SCP Guardrails、GitHub Actions OIDC

---

## セキュリティ設計の対比

| 観点 | Type-B | Type-A |
|------|--------|------------|
| 脅威への対応 | 検知してから対応（事後） | そもそも侵入させない（事前防御） |
| アクセス制御 | ネットワーク境界（VPN 内＝信頼） | ID・デバイス証明書 |
| コンプライアンス | CIS・NIST 自動監査・レポート | SCP で違反を不可能に |
| 変更管理 | 承認フロー・記録の完全保持 | IaC・GitOps で自動追跡 |
| インシデント対応 | 重要度別エスカレーション | 自動遮断・自動復旧を最大化 |

---

## 共通セキュリティ基盤（両アーキテクチャ）

| 機能 | 設定の考え方 |
|------|----------------|
| KMS | CMK・自動ローテーション・削除猶予 |
| CloudTrail | マルチリージョン・整合性検証・長期保持 |
| GuardDuty | 主要リソース保護の有効化 |
| AWS Config | 変更記録・長期保持 |
| VPC Flow Logs | トラフィック可視化・KMS 暗号化 |
| Macie / Access Analyzer | データ露出・公開リソースの継続スキャン |

（本リポジトリの Terraform では代表リソースから段階的に実装）

---

## リポジトリ内の配置

```
internal-infra/
├── README.md                 # 本書
├── Makefile                  # テスト・Terraform 検証
├── terraform/
│   ├── type-b/               # Enterprise Edition（段階的実装）
│   └── type-a/           # Cloud-Native Edition（段階的実装）
└── lambda/
    ├── sentinel_enterprise/   # Type-B: 検知イベントの重要度別ルーティング（スタブ）
    ├── sentinel_cloud_native/ # Type-A: 自動対応（スタブ）
    └── rag_query/             # Type-A: RAG クエリ（スタブ）
```

**既存の `terraform/corp-internal`** は、「社内専用・Session Manager 向け VPCE」など**両系統に共通しうる最小フットプリント**用です。本 `internal-infra` の Type-B / Type-A と役割が被る場合は、将来マージまたは参照関係を整理してください。

---

## 設計思想（まとめ）

本プロジェクトはホテル予約システムと同じコアメッセージを社内インフラに適用しています。

- **Type-B** が選ぶのは「変えないことで守る安心」。既存の組織文化と資産を尊重し、社員が気づかないところだけを AI で強化する。
- **Type-A** が選ぶのは「ID だけを信頼する自由」。場所・デバイス・ネットワークへの依存を減らし、どこからでも安全に働ける環境を目指す。

どちらが優れているかという問いは成立しない。**どんな組織文化を支えたいか**という問いへの答えが、インフラの思想を決定する。
