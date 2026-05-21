# Terraform Plan（ローカル / 実 AWS）

## 子モジュール化後の state 移行

既存 state がある環境では、初回 `plan` で `moved` ブロックにより **destroy/recreate なし** になる想定です。

```bash
cd hotel_folder
# S3 backend を使う場合（backends/s3.hcl を用意）
cp terraform/type-b/backends/s3.hcl.example terraform/type-b/backends/s3.hcl
# 編集後
TF_STATE_BACKEND_FILE=terraform/type-b/backends/s3.hcl \
  AWS_PROFILE=your-profile \
  make terraform-plan-type-b-aws
```

## ローカル state（ポートフォリオ検証・新規 plan）

デフォルト backend は `local`（`.state/terraform.tfstate`）。S3 不要です。

```bash
cd hotel_folder
make terraform-plan-type-b
make terraform-plan-type-a
```

空 state では **全リソース create** の plan になります（AWS 認証があると data source が解決されます）。

## 実 AWS との差分（S3 state）

1. `terraform/type-*/backends/s3.hcl.example` を `s3.hcl` にコピーし、`bucket` / `key` / `region` を設定
2. AWS 認証（`AWS_PROFILE` または環境変数）
3. `make terraform-plan-type-b-aws` または `make terraform-plan-type-a-aws`

`plan.tfplan` は `.gitignore` 対象です。共有する場合は `terraform show plan.tfplan` のテキストを export してください。

## モジュール境界

| モジュール | パス | state |
|-----------|------|--------|
| VPC (Type-B) | `modules/vpc_type_b` | 親 stack と同一 |
| VPC (Type-A) | `modules/vpc_type_a` | 親 stack と同一 |
| Sentinel | `modules/sentinel` | 親 stack と同一 |

子モジュールは **別 state にしない** 設計です（単一 root state で運用・レビューしやすくするため）。
