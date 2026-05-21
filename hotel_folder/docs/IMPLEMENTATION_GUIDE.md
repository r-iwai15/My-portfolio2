# 実装・セットアップ手順

このドキュメントは、リポジトリを**ローカルで検証する**ための手順と、AWS へ**実際にデプロイする**ときの最低限の流れをまとめたものです。アカウントや組織ポリシーによって差し替えが必要な箇所は `YOUR-*` やコメントで示します。

**構成の技術説明（スタック・Lambda・CI の全体像）**は [`TECHNICAL_OVERVIEW.md`](TECHNICAL_OVERVIEW.md) を参照してください。

---

## 1. 初めに読むもの（5分）

| 読む順 | ファイル | 内容 |
|--------|----------|------|
| 1 | ルート `readme.md` | プロジェクトの目的とフォルダの地図 |
| 2 | `docs/TECHNICAL_OVERVIEW.md` | **技術スタック・Terraform ルート・品質ゲート**の全体説明 |
| 3 | `docs/DESIGN_TYPE_B_VS_A.md` | 外向け Type-B / Type-A の設計分離 |
| 4 | `internal-infra/README.md` | 社内向け Type-B Enterprise / Type-A Cloud-Native の説明 |

**社内 Terraform の「本線」:** 比較・拡張は `internal-infra/terraform/`。最小1本だけ試す場合は `terraform/corp-internal` も利用可（後述）。

---

## 2. 必要なツール

| ツール | 目安 |
|--------|------|
| Terraform | `>= 1.0`（検証時は最新系推奨） |
| Node.js | `>= 20`（Lambda テスト・ビルド） |
| Python | `>= 3.11` 推奨（Sentinel 系テストは 3.10+ でも通る場合あり） |
| AWS CLI | v2 推奨（プロファイル設定・Bedrock Agent 準備コマンド用） |
| make | macOS/Linux の標準で可 |

動作確認コマンド（リポジトリルート）:

```bash
make test
make terraform-fmt-check
make terraform-validate
make ci
```

ネットワーク遮断環境では `terraform init` が失敗することがあるため、初回はインターネット接続を想定してください。

---

## 3. AWS の事前準備（本番・共有環境）

### 3.1 Terraform バックエンド用 S3（必須に近い）

各 `terraform { backend "s3" { ... } }` は、**既存の S3 バケット**を指す必要があります。

1. 組織ルールに従い、**バージョニング有効・暗号化有効**のバケットを1つ以上作成する。
2. （推奨）**DynamoDB テーブル**で state ロック（Type-A コメント参照のキー設計など）。
3. 各スタックの `main.tf` 内 `bucket` / `key` / `region` を、実際のバケットと**一意のキー**に書き換える。  
   - 例: `hotel-innovative/...` と `internal-infra/type-b/...` のように **キーはスタックごとに分ける**。

### 3.2 IAM

- `terraform plan` / `apply` を実行する**主体**（ユーザーまたは CI ロール）に、対象リソースを作成できる権限を付与する。
- 最小権限で始めたい場合は、まず **読み取り中心の `plan` だけ**を別ロールで試す運用も可。

### 3.3 リージョン

デフォルトは多くのスタックで `ap-northeast-1` を想定。変数 `region` やプロバイダで揃える。

---

## 4. Lambda のビルド（ホテル系スタック向け）

外向け Type-B / Type-A の Terraform は、`./lambda/*.zip` を参照する前提があります（変数は各 `main.tf` を参照）。

リポジトリルートで:

```bash
make build
```

生成物（例）: `lambda/chatbot.zip`, `lambda/reader.zip` など。

**クリーンアップ**（ZIP と一部キャッシュを消す）:

```bash
make clean
```

---

## 5. Terraform の実行順（推奨の考え方）

スタック同士は**原則独立**です（別 state）。依存関係は「どのアカウントで何を共有するか」で変わります。

| 目的 | ディレクトリ（`-chdir` 例） | メモ |
|------|-----------------------------|------|
| 外向け 伝統型 | `terraform/type-b` | 規模が大きい。`plan` を必ず確認。 |
| 外向け サーバーレス | `terraform/type-a` | Bedrock Agent 準備に `local-exec` と AWS CLI が要る場合あり。 |
| 社内 最小1本 | `terraform/corp-internal` | Session Manager 向け VPCE 等の薄いスタック。 |
| 社内 二系統（本線） | `internal-infra/terraform/type-b` / `type-a` | 設計の「正」に合わせた拡張はここを優先。 |

典型フロー（例）:

```bash
terraform -chdir=terraform/type-b init
terraform -chdir=terraform/type-b plan
terraform -chdir=terraform/type-b apply
```

別スタックを触る前に、**プロファイルとリージョン**が意図したアカウントになっているか `aws sts get-caller-identity` で確認する。

---

## 6. `terraform/corp-internal` と `internal-infra/terraform` の使い分け

- **`internal-infra/terraform/`**  
  **社内向け Type-B（Enterprise）と Type-A（Cloud-Native）の比較・本線の IaC**。README に設計思想がある。今後の社内リソース追加の**正（かたち）**はここで揃える想定。

- **`terraform/corp-internal`**  
  **単一スタックの最小構成**（軽く試す・他プロジェクトから流用する）向け。`internal-infra` と役割が重なる場合は、**長期的には `internal-infra` に寄せ、corp-internal は倉庫・レガシー用に残す**形が読みやすい。

両方を同一アカウントにそのまま `apply` すると **VPC や名前の衝突**が起きうるため、同一リージョンでは**どちらか一方**から始めるか、CIDR / `name_prefix` を必ず調整する。

---

## 7. Type-A（外向け）の注意

- `null_resource` + `aws bedrock-agent prepare-agent` は、**実行環境の AWS CLI 認証**に依存する。
- 本番では **CI の OIDC ロール**など、監査可能な実行主体に寄せることを推奨。

---

## 8. 社内 Lambda（`internal-infra/lambda`）

スタブとしてテスト可能:

```bash
make -C internal-infra test
```

本番デプロイ時は、各ディレクトリを ZIP に固め、別途 `aws_lambda_function` を Terraform で定義するか、CI でパッケージングする（現状は**インフラの骨格とロジックのスタブ**が中心）。

---

## 9. トラブルシューティング

| 現象 | 確認こと |
|------|-----------|
| `terraform init` がプロバイダ取得で失敗 | ネットワーク、プロキシ、企業ファイアウォール |
| `Error acquiring the state lock` | 他プロセスの apply、古いロック。DynamoDB ロック利用時はテーブル側を確認 |
| `validate` は通るが `apply` で権限エラー | IAM ポリシー、SCP、サービス制限（Bedrock 未開通リージョンなど） |
| 同一 VPC CIDR の衝突 | 各スタックの `vpc_cidr` / `name_prefix` をユニークに |

---

## 10. 次の一歩

- 経営・導入判断向け: `docs/EXECUTION_PLAN.md`
- ポートフォリオの境界: `PORTFOLIO_STRATEGY.md`
