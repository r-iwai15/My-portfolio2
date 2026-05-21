# アーキテクチャ図（Type-B vs Type-A）

## 外向け：Type-B（伝統 + Sentinel）

```mermaid
flowchart LR
  Guest[ゲスト] --> Web[Web / ALB]
  Web --> RDS[(RDS)]
  Web --> Chat[chatbot / vLLM]
  Chat --> Logs[CloudWatch Logs]
  Logs --> Sentinel[Sentinel Lambda]
  Sentinel --> WAF[WAF IP Set]
  Sentinel --> Cognito[Cognito 無効化]
```

AI は **会話とログ監視の補助**。予約の正は RDS。防御は **ルールベース**。

## 外向け：Type-A（関所付きオーケストレーター）

```mermaid
flowchart TB
  Guest[ゲスト] --> APIGW[API Gateway]
  APIGW --> IF[interface Lambda]
  IF --> Agent[Bedrock Agent]
  Agent --> Reader[tools/reader]
  Agent --> Exec[execution/reservation]
  Reader --> DDB[(DynamoDB Read)]
  Exec --> DDBW[(DynamoDB Write)]
  Exec --> Price[pricing-engine コード]
```

- **interface:** 副作用なし（Agent 起動のみ）
- **execution:** スキーマ検証・冪等・料金計算（LLM 非使用）後に書き込み
- **Gray ゾーン:** Agent が「いつ execution を呼ぶか」は AI 側。将来は意図 JSON のみを Agent 出力に限定する改善余地あり（[`STRUCTURE.md`](../STRUCTURE.md)）

## 社内インフラ

```mermaid
flowchart LR
  subgraph corp["corp-internal（最小 VPCE）"]
    VPCE[SSM VPCE / 内部 S3]
  end
  subgraph ii["internal-infra（比較の本線）"]
    TB[Type-B Enterprise]
    TA[Type-A Cloud-Native]
  end
  corp -. 共通フットプリント .- ii
```

**正:** 社内の拡張・比較は `internal-infra/terraform/`。`terraform/corp-internal` は Session Manager 向けなど **最小 1 スタック** 用。
