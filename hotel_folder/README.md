# Hotel Reservation & Internal Infra Platform

外向けホテル予約（Type-B / Type-A）と社内向けインフラ比較を **単一リポジトリ** で管理します。

## 最初に読むもの

| ファイル | 内容 |
|----------|------|
| [`STRUCTURE.md`](STRUCTURE.md) | ディレクトリ構成と AI 関所モデル（interface / tools / execution） |
| [`docs/TECHNICAL_OVERVIEW.md`](docs/TECHNICAL_OVERVIEW.md) | 技術要素の全体像 |
| [`docs/IMPLEMENTATION_GUIDE.md`](docs/IMPLEMENTATION_GUIDE.md) | ビルド・Terraform・デプロイ手順 |

## クイックスタート

```bash
make test    # Lambda テスト
make build   # lambda/*.zip
make ci      # test + terraform fmt/validate
```

## Terraform ルート

| パス | 用途 |
|------|------|
| `terraform/type-b` | 伝統型 3 層 + Sentinel |
| `terraform/type-a` | Bedrock Agent + 関所分離 Lambda |
| `terraform/corp-internal` | 社内最小 VPCE |
| `internal-infra/terraform/` | 社内 Type-B / Type-A 比較 |

## Type-A の Lambda 分離

```
lambda/type-a/
├── interface/              # 対話（API → Bedrock Agent）
├── tools/reader/           # 読み取り Tool
└── execution/reservation/  # 予約書き込み（決定論的実行）
```

スキーマ: `packages/reservation-schema/intent.schema.json`（execution で AJV 検証）

フロント（スタブ）: [`frontend/type-a-chat/index.html`](frontend/type-a-chat/index.html)
