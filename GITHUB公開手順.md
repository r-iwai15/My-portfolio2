# GitHub 公開手順

## このリポジトリに含めないもの（`.gitignore` 済み）

- `node_modules/` / `.terraform/` / `*.tfstate` / `plan.tfplan`
- `lambda/*.zip` / `dummy_*.zip` / `dist/*.zip`
- GeoLite `*.mmdb`（MaxMind ライセンス）
- `backends/s3.hcl`（本番バケット名）
- `.env` / 鍵ファイル

## 公開前（必須）

```bash
cd ポートフォリオのコピー5
bash scripts/check-before-push.sh
```

## 初回 push

```bash
git init
git add .
git status    # .mmdb / node_modules / .terraform が無いこと
git commit -m "Initial commit: cloud security portfolio"
git remote add origin git@github.com:YOUR_USER/YOUR_REPO.git
git branch -M main
git push -u origin main
```

**推奨:** 最初は **Private** → 問題なければ Public。

## clone した人向け

```bash
cd hotel_folder
make ci    # テスト + terraform validate（要 Node 20 / Python 3.11 / terraform）
```

Wireshark 解析を使う場合のみ、MaxMind から GeoLite を取得して `analysis_wireshark/geolite/` に配置（[`analysis_wireshark/geolite/README.md`](analysis_wireshark/geolite/README.md)）。

## LICENSE

MIT（`LICENSE`）。著作権表示の名前は必要なら差し替えてください。
