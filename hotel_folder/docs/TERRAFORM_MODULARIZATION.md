# Terraform モジュール分割（進捗）

## 1. ファイル分割（完了）

`main.tf` を関心ごと別 `.tf` に分割済み。

## 2. 子モジュール化（完了）

| モジュール | 用途 | 呼び出し元 |
|-----------|------|-----------|
| `modules/vpc_type_b` | NAT・多層サブネット VPC | `terraform/type-b` |
| `modules/vpc_type_a` | プライベート VPC + Lambda SG | `terraform/type-a` |
| `modules/sentinel` | WAF 連携・ブロック追跡・Lambda | `terraform/type-b` |
| `modules/cloudwatch_log_group` | ロググループ共通化 | 各 stack |

既存 state 向けに `moved.tf` でアドレス移行を定義しています。

## 3. Plan / Backend

- S3 backend は **部分設定**（`backends/s3.hcl`）
- 手順: [TERRAFORM_PLAN.md](./TERRAFORM_PLAN.md)
- Makefile: `make terraform-plan-type-b` / `terraform-plan-type-a`（ローカル）、`*-aws`（S3 + 実アカウント）

## 検証

```bash
cd hotel_folder
make terraform-validate
make terraform-plan-type-b   # 要 network（provider 取得）
```

## 今後（任意）

- RDS / ALB など追加の子モジュール
- **別 state** にする場合は stack 分割設計（Terragrunt / 複数 root）が別途必要
