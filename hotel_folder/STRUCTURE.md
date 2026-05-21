# リポジトリ構成（AI エージェント役割分担ガイドライン対応）

本ディレクトリ `hotel_folder/` が、**外向けホテル予約**と**社内向けインフラ比較**の単一の作業ルートです。

## トップレベル

```
hotel_folder/
├── lambda/                    # ビルド成果物 (*.zip) とソース
├── terraform/                 # 外向け IaC
│   ├── type-b/                # 伝統型 3 層 + Sentinel（AI は裏方）
│   ├── type-a/                # サーバーレス + Bedrock Agent
│   ├── corp-internal/         # 社内最小 VPCE スタック
│   └── modules/               # 共通モジュール（CloudWatch 等）
├── internal-infra/            # 社内 Type-B / Type-A 比較
├── packages/
│   └── reservation-schema/    # 予約意図 JSON Schema（Gray 関所）
├── docs/                      # 設計・手順書
├── Makefile                   # test / build / terraform validate
└── STRUCTURE.md               # 本ファイル
```

## Type-A Lambda（関所モデル）

| パス | ゾーン | 責務 |
|------|--------|------|
| `lambda/type-a/interface/` | White〜Gray | API GW → Bedrock Agent（副作用なし） |
| `lambda/type-a/tools/reader/` | Gray（読取） | DynamoDB 読み取り Tool |
| `lambda/type-a/execution/reservation/` | Gray〜Black 手前 | 検証後の予約書き込み（決定論的） |

Terraform 上の Lambda 名: `{app}-interface`, `{app}-reader`, `{app}-reservation`

### Gray ゾーン（既知の改善余地）

Bedrock Agent が **いつ** `execution/reservation` を呼ぶかは、現状 AI の判断に依存します。ガイドライン上の理想形は「Agent は構造化インテント JSON のみ出力 → 実行は常に execution 層」です。`packages/reservation-schema/` と execution 内の AJV 検証は、その関所の第一段です。

## Type-B Lambda

| パス | ゾーン | 責務 |
|------|--------|------|
| `lambda/type-b/chatbot/` | White | 会話のみ（vLLM プロキシ） |
| `lambda/type-b/sentinel_*` | ルール実行 | ログ検知 → WAF / Cognito（AI 非依存） |

## コマンド

```bash
cd hotel_folder
make test      # 全 Lambda テスト
make build     # lambda/*.zip
make ci        # test + terraform fmt/validate
```

## 関連

- ポートフォリオ全体: ルート [`README.md`](../README.md)
- 技術詳細: [`docs/TECHNICAL_OVERVIEW.md`](docs/TECHNICAL_OVERVIEW.md)
