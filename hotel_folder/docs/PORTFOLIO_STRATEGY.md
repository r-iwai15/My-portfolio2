# ポートフォリオのスコープと境界

本リポジトリは **本番 SaaS の完成品ではなく**、クラウド・セキュリティ・AI エージェント設計を比較検証するためのポートフォリオです。

## 含むもの

- Type-B / Type-A の **対照的な IaC**（Terraform）
- **テスト付き Lambda スタブ**（予約・防御・社内 RAG 等）
- ログ調査（Athena）・オフライン Egress 監査
- 実ホテル運用を想定した **責務分界のドキュメント**（決済・OTA は外部）

## 意図的に含まないもの（本番で別途必要）

- 本番 SLA・マルチリージョン DR の完成形
- PCI 完了を意味する決済実装（Stripe 本番連携は [REAL_WORLD_HOTEL_INTEGRATIONS.md](REAL_WORLD_HOTEL_INTEGRATIONS.md) 参照）
- OTA 全チャネル同期・PMS 深い結合
- フル機能フロントエンド（`frontend/` はデモ用スタブ）

## デモ環境

- **公開デモ URL は未ホスト**（コスト・認証情報の都合）。ローカル検証は `hotel_folder` で `make test` / `make ci`。

## 読み方

| 目的 | ドキュメント |
|------|--------------|
| フォルダ構成 | [`../STRUCTURE.md`](../STRUCTURE.md) |
| 技術一覧 | [TECHNICAL_OVERVIEW.md](TECHNICAL_OVERVIEW.md) |
| 手順 | [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) |
| アーキテクチャ図 | [ARCHITECTURE.md](ARCHITECTURE.md) |
