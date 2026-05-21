# Backend 設定

## ローカル（デフォルト）

`versions.tf` の `backend "local"` を使用。`make terraform-plan-type-b` で plan 可能。

## 本番 S3 への切り替え

1. `versions.tf` の `backend "local" { ... }` を次に置き換え:

```hcl
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
```

2. `cp s3.hcl.example s3.hcl` して bucket / key を設定
3. `terraform init -reconfigure -backend-config=backends/s3.hcl`
4. `terraform plan`

`make terraform-plan-type-b-aws` は上記 1〜3 完了後に実行してください。
