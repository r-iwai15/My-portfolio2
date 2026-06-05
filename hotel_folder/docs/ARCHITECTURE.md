# アーキテクチャ図

> 面接・レビュー用の俯瞰図です。まず **0. 全体像（1枚）** を見れば、4 プロジェクトと共通セキュリティ基盤の関係が掴めます。各スタックの詳細は以降のセクションを参照してください。

---

## 0. 全体像（1 枚で俯瞰）

「外向け（ホテル予約）」「社内向け」「セキュリティ調査」の 3 領域を、**共通のセキュリティ基盤**の上に並べています。外向け・社内向けとも *同じ設計哲学*（顧客体験 / 企業文化を起点に Type-B＝伝統・統制型 と Type-A＝先端・自律型 を対比）で構成しています。

```mermaid
flowchart TB
  classDef ext fill:#dbeafe,stroke:#2563eb,color:#1e3a8a;
  classDef int fill:#dcfce7,stroke:#16a34a,color:#14532d;
  classDef ana fill:#f3e8ff,stroke:#9333ea,color:#581c87;
  classDef gov fill:#fef3c7,stroke:#d97706,color:#92400e;

  User(["ゲスト / 社員"])

  subgraph EXT["外向け: ホテル予約 (hotel_folder/terraform)"]
    direction LR
    TA["Type-A: サーバーレス<br/>Bedrock Agent + 関所Lambda + DynamoDB"]:::ext
    TB["Type-B: 伝統3層<br/>ALB + RDS + Sentinel防御Lambda"]:::ext
  end

  subgraph INT["社内向け: internal-infra/terraform"]
    direction LR
    ITA["Type-A: Cloud-Native<br/>ZTNA / IGWなし / 社内RAG"]:::int
    ITB["Type-B: Enterprise<br/>ハイブリッド / AD連携 / Sentinel"]:::int
  end

  subgraph ANA["セキュリティ調査"]
    direction LR
    WS["analysis_wireshark<br/>オフラインEgress監査"]:::ana
    LOG["AWS_log<br/>Athena: CloudTrail / VPC Flow"]:::ana
  end

  subgraph BASE["共通セキュリティ基盤 (横断)"]
    direction LR
    KMS["KMS CMK<br/>+ 自動ローテーション"]:::gov
    IAM["最小権限 IAM"]:::gov
    OBS["CloudTrail / Config<br/>GuardDuty / Flow Logs"]:::gov
    SC["CI / Dependabot<br/>npm・pip audit"]:::gov
  end

  User --> EXT
  User --> INT
  EXT -. 監査ログ .-> LOG
  INT -. 監査ログ .-> LOG
  EXT --- BASE
  INT --- BASE
  WS -. データ主権の検証 .-> User
```

---

## 1. 外向け Type-A（サーバーレス + 関所付きオーケストレーター）★中核

完全サーバーレス。**White（対話）→ Gray（読取/検証）→ 実行（書込）** と責務を関所で分離し、書き込みに触れるのは `execution/reservation` だけ。エッジ〜認証〜AI〜データまで、各層にセキュリティ統制を敷いています。

```mermaid
flowchart TB
  classDef white fill:#f8fafc,stroke:#475569,color:#0f172a;
  classDef gray fill:#e2e8f0,stroke:#334155,color:#0f172a;
  classDef data fill:#fee2e2,stroke:#dc2626,color:#7f1d1d;
  classDef gov fill:#fef3c7,stroke:#d97706,color:#92400e;
  classDef edge fill:#e0f2fe,stroke:#0284c7,color:#075985;

  Guest(["ゲスト"])

  subgraph Edge["エッジ / 認証"]
    direction TB
    CF["CloudFront + WAFv2 + OAC"]:::edge
    S3F["S3 静的フロント<br/>(公開ブロック / OAC のみ)"]:::edge
    APIGW["API Gateway REST + WAFv2"]:::edge
    COG["Cognito User Pool<br/>(Authorizer)"]:::edge
  end

  subgraph App["関所付き Lambda"]
    direction TB
    IF["interface<br/>対話のみ・副作用なし"]:::white
    RD["tools/reader<br/>読取 Tool"]:::gray
    EX["execution/reservation<br/>スキーマ検証 + 冪等 + 料金計算"]:::gray
  end

  subgraph AI["Amazon Bedrock"]
    direction TB
    AG["Bedrock Agent<br/>(Orchestrator)"]
    GRD["Guardrail"]
  end

  DDB[("DynamoDB reservations<br/>KMS CMK / GSI")]:::data

  Guest --> CF --> S3F
  Guest --> APIGW --> COG
  APIGW --> IF --> AG
  AG --- GRD
  AG --> RD
  AG --> EX
  RD -->|読取| DDB
  EX -->|TransactWrite（冪等記録+予約を原子的に）| DDB

  subgraph Net["閉域ネットワーク (VPC)"]
    VPCE["VPC Endpoints<br/>DynamoDB(GW) / Bedrock / Cognito / KMS / Logs"]
  end
  EX -. HTTPS 443 .-> VPCE
  RD -. HTTPS 443 .-> VPCE

  subgraph Gov["監査・ガバナンス"]
    direction LR
    CT["CloudTrail → S3"]:::gov
    CFG["AWS Config → S3"]:::gov
    GD["GuardDuty"]:::gov
    FL["VPC Flow Logs"]:::gov
    AL["CloudWatch Alarm<br/>→ SNS (KMS暗号化)"]:::gov
  end
  GD --> AL
```

- **interface:** Bedrock Agent を起動するだけ（副作用なし）。不正 JSON は 400 で弾く。
- **execution:** AJV でスキーマ検証 → 料金計算 → `TransactWriteCommand` で冪等記録と予約を**原子的に**書き込み（孤立レコードを防止）。LLM は使わない決定論的処理。
- **Gray ゾーンの既知課題:** Agent が「いつ execution を呼ぶか」は AI 判断。将来は Agent 出力を意図 JSON のみに限定する改善余地あり（[`STRUCTURE.md`](../STRUCTURE.md)）。

---

## 2. 外向け Type-B（伝統 3 層 + Sentinel 防御ループ）

ユーザーが触れるフロント / 基幹 DB は堅牢な 3 層を維持。**AI は会話とログ監視の裏方**で、防御は決定論的なルールベース（Sentinel）に寄せています。

```mermaid
flowchart LR
  classDef app fill:#dbeafe,stroke:#2563eb,color:#1e3a8a;
  classDef data fill:#fee2e2,stroke:#dc2626,color:#7f1d1d;
  classDef sec fill:#fef3c7,stroke:#d97706,color:#92400e;

  Guest(["ゲスト"]) --> ALB["Web / ALB + WAF"]:::app
  ALB --> RDS[("RDS（予約の正）")]:::data
  ALB --> Chat["chatbot Lambda<br/>(vLLM プロキシ・会話のみ)"]:::app

  Chat --> Logs["CloudWatch Logs"]
  Logs --> Sent["sentinel_executioner<br/>(ログ駆動の検知)"]:::sec
  Sent -->|ブロック| WAFIP["WAF IP Set"]:::sec
  Sent -->|無効化| COG2["Cognito アカウント"]:::sec
  Rel["sentinel_release<br/>(TTL で自動解除)"]:::sec -.-> WAFIP

  subgraph Msg["予約確定通知"]
    SQS["SQS"] --> Mail["send_email Lambda → SES"]
  end
  RDS -. 確定イベント .-> SQS

  subgraph Base["基盤"]
    KMS2["KMS CMK"]:::sec
    FL2["VPC Flow Logs"]:::sec
  end
```

- **多層防御:** WAF → ALB → アプリ → RDS。アプリ層の外向き通信は VPC 内に制限。
- **Sentinel:** ログ検知で WAF IP Set 追加 / Cognito 無効化。`sentinel_release` が TTL ベースで解除。
- **KMS / SNS:** CloudWatch アラームが KMS 暗号化 SNS へ発行できるよう、キーポリシーに `events` / `cloudwatch` 主体を許可（修正済み）。

---

## 3. 社内インフラ（Enterprise vs Cloud-Native）

外向けと同じ「Type-B＝統制 / Type-A＝自律」の哲学を社内に適用した比較検証。

```mermaid
flowchart TB
  classDef ent fill:#dbeafe,stroke:#2563eb,color:#1e3a8a;
  classDef cn fill:#dcfce7,stroke:#16a34a,color:#14532d;
  classDef sec fill:#fef3c7,stroke:#d97706,color:#92400e;

  subgraph ITB["Type-B: Enterprise（伝統・統制型）"]
    direction TB
    OnPrem["オンプレ / Active Directory"] --> Hybrid["Direct Connect + VPN<br/>(閉域ハイブリッド)"]:::ent
    Hybrid --> ADC["AD Connector"]:::ent
    Hybrid --> WL["ワークロード VPC"]:::ent
    SentE["sentinel_enterprise<br/>GuardDuty/Security Hub → 重要度別ルーティング"]:::sec
    WL -. 検知 .-> SentE
    CompS3["コンプライアンスログ S3"]:::sec
    WL --> CompS3
  end

  subgraph ITA["Type-A: Cloud-Native（先端・自律型）"]
    direction TB
    Dev(["開発者 (MacBook)"]) --> VA["AWS Verified Access<br/>(ZTNA・VPNなし)"]:::cn
    VA --> PVPC["プライベート VPC<br/>(IGW なし)"]:::cn
    PVPC --> VPCE2["Interface VPCE<br/>SSM / Bedrock Runtime"]:::cn
    PVPC --> S3GW["S3 Gateway VPCE"]:::cn
    RAG["rag_query Lambda<br/>(社内RAG入口)"]:::cn --> DDB2[("DynamoDB<br/>会話履歴")]:::cn
    PVPC --> RAG
    IDC["IAM Identity Center + SCIM"]:::cn --> VA
  end

  ITB -. corp-internal（最小 SSM VPCE / 内部S3）で共通フットプリント .- ITA
```

| 比較項目 | Type-B（統制型） | Type-A（自律型） |
|----------|------------------|------------------|
| ネットワーク | 閉域ハイブリッド（DX + VPN） | VPN なし・Verified Access（ZTNA） |
| ID 管理 | AD Connector で既存 AD 連携 | IAM Identity Center + SCIM |
| 開発者体験 | 承認必須・厳格な変更管理 | セルフサービス・Guardrails 内で自由 |
| セキュリティ | 検知・対応型（重要度別ルーティング） | 予防・自動化型（侵入させない設計） |
| AI の役割 | 脅威の自律検知・エスカレーション | 社内 RAG / セルフサービス支援 |

> **実装状況:** Sentinel / RAG / Verified Access は *IaC の骨格 + 挙動スタブ*。外部連携（Slack/Jira/実 KB）は未ワイヤ。詳細は [`internal-infra/README.md`](../internal-infra/README.md) と [`TECHNICAL_OVERVIEW.md`](TECHNICAL_OVERVIEW.md)。

---

## 関連ドキュメント

- 技術全体像: [`TECHNICAL_OVERVIEW.md`](TECHNICAL_OVERVIEW.md)
- 関所モデルの詳細: [`../STRUCTURE.md`](../STRUCTURE.md)
- 設計の意思決定（Type-B vs A）: [`DESIGN_TYPE_B_VS_A.md`](DESIGN_TYPE_B_VS_A.md)
- スコープと境界: [`../../README.md`](../../README.md) / [`PORTFOLIO_STRATEGY.md`](PORTFOLIO_STRATEGY.md)
