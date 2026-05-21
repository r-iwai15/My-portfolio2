# Execution Plan

このドキュメントは、以下の7テーマを「今すぐ導入済み」と「次フェーズ実行計画」に分けて整理したものです。

- 量子耐性
- README
- ビジネス視点
- シャドーIT対策
- Lambdaコード
- 導入促進支援
- サプライチェーン対策

## Already Introduced (This Sprint)

- README拡張
  - 開発・検証・CI・セキュリティベースライン・運用上の注意点を追加
- サプライチェーンの初期自動化
  - Dependabot導入（GitHub Actions / npm / pip）
  - 週次+手動実行の依存監査Workflow追加
    - `npm audit`（Node.js Lambda）
    - `pip-audit`（Python Lambda）
- セキュリティベースライン実装
  - Terraform `fmt/validate` のCI化
  - KMSポリシー条件追加（`aws:SourceAccount`）
  - ネットワーク外向き通信の絞り込み（Type-B）
  - IAMログ権限の関数単位最小化（Type-A）

## Next Phase Plan

### 1) 量子耐性（PQC）準備

- 目的
  - 直ちに暗号方式を全面置換するのではなく、将来移行に備えた設計へ移行する
- 実施
  - 暗号資産棚卸し（TLS, KMS利用箇所, 署名）
  - crypto-agility設計方針の文書化
  - PQC移行トリガー（規制/クラウド機能提供）定義
- 成果物
  - `docs/crypto-agility-roadmap.md`
  - 暗号資産インベントリ

### 2) ビジネス視点の明文化

- 目的
  - 技術説明を投資判断に変換する
- 実施
  - KPI定義（予約CVR、問い合わせ削減率、運用工数削減、MTTR）
  - Type-B / Type-A の適用条件を業態別に定義
  - 導入コスト対効果の比較テンプレート作成
- 成果物
  - `docs/business-case.md`
  - KPIダッシュボード要件

### 3) シャドーIT対策

- 目的
  - 非承認SaaS・非管理アカウント経由のデータ流出経路を減らす
- 実施
  - アカウント/アプリ利用の可視化フロー定義
  - SSO/MFA必須化ポリシーと例外承認フロー
  - データ分類（機微/非機微）と持ち出しルール整備
- 成果物
  - `docs/shadow-it-policy.md`
  - 運用Runbook（検知→評価→是正）

### 4) 導入促進支援（Enablement）

- 目的
  - PoC止まりを防ぎ、現場運用まで到達させる
- 実施
  - 導入手順書（環境準備、ロール分担、移行手順）
  - FAQ、障害一次切り分け、教育資料
  - 役割別トレーニング（運用/開発/監査）
- 成果物
  - `docs/enablement-playbook.md`
  - `docs/operations-runbook.md`

### 5) サプライチェーン対策の深化

- 目的
  - 依存関係リスクを「検知」から「統制」へ進める
- 実施
  - SBOM生成（CycloneDX など）
  - 脆弱性SLA（例: Critical 24h, High 7d）運用
  - 署名検証・リリース整合性チェックの導入
- 成果物
  - `docs/supply-chain-policy.md`
  - CIのセキュリティゲート強化版Workflow

## Suggested Timeline

- Week 1: ビジネスKPI定義 + 導入手順テンプレ作成
- Week 2: シャドーITポリシー + Runbook初版
- Week 3: SBOM・脆弱性SLA運用開始
- Week 4: PQC準備ドキュメント確定

## Actionable Tickets (Ready to Create)

以下は、そのままIssue化できる粒度で定義した実行チケットです。  
`Owner` と `Due` はチーム事情に応じて埋めてください。

### Week 1

1. **BUS-01: KPI定義ドラフト作成**
   - Scope: 予約CVR、問い合わせ削減率、運用工数削減、MTTRの定義
   - Deliverable: `docs/business-case.md`（KPIセクション）
   - Done: KPIの算式・計測元データ・報告頻度が明記されている
   - Owner: TBD
   - Due: Week1-Day2

2. **BUS-02: Type-B/Type-A適用判断マトリクス**
   - Scope: 業態/客層/運用体制ごとの推奨アーキタイプ整理
   - Deliverable: `docs/business-case.md`（適用マトリクス）
   - Done: 3パターン以上のホテル類型で選定理由が説明されている
   - Owner: TBD
   - Due: Week1-Day4

3. **ENB-01: 導入手順テンプレ初版**
   - Scope: 前提条件、初期構築、検証、移行、ロールバック手順
   - Deliverable: `docs/enablement-playbook.md`
   - Done: 新規環境を第三者が再現可能な手順になっている
   - Owner: TBD
   - Due: Week1-Day5

### Week 2

4. **SIT-01: シャドーITポリシー初版**
   - Scope: 利用申請、例外承認、違反時是正フロー
   - Deliverable: `docs/shadow-it-policy.md`
   - Done: 承認/却下基準と例外有効期限が定義されている
   - Owner: TBD
   - Due: Week2-Day2

5. **SIT-02: データ分類・持ち出しルール定義**
   - Scope: 機微データ定義、保管/転送/外部共有ルール
   - Deliverable: `docs/shadow-it-policy.md`（分類表）
   - Done: 最低3分類（機微/社内/公開）で統制ルールが明文化されている
   - Owner: TBD
   - Due: Week2-Day4

6. **ENB-02: 運用Runbook作成**
   - Scope: 監視アラート対応、障害一次切り分け、エスカレーション
   - Deliverable: `docs/operations-runbook.md`
   - Done: 代表的な障害シナリオ3件以上に対する手順がある
   - Owner: TBD
   - Due: Week2-Day5

### Week 3

7. **SC-01: SBOM生成をCIに追加**
   - Scope: CycloneDX形式でNode/Python依存のSBOM出力
   - Deliverable: `.github/workflows/supply-chain-security.yml` 更新
   - Done: 手動実行でSBOM成果物をダウンロードできる
   - Owner: TBD
   - Due: Week3-Day2

8. **SC-02: 脆弱性SLA運用ルール定義**
   - Scope: Critical/High/Mediumの修正期限、例外プロセス
   - Deliverable: `docs/supply-chain-policy.md`
   - Done: 発見からクローズまでの責任分界と期限が定義されている
   - Owner: TBD
   - Due: Week3-Day4

9. **SC-03: 依存監査の失敗基準を明文化**
   - Scope: CI失敗条件（閾値）と暫定例外ルール
   - Deliverable: `docs/supply-chain-policy.md` + Workflowコメント
   - Done: 監査結果の運用方針がチーム合意済み
   - Owner: TBD
   - Due: Week3-Day5

### Week 4

10. **PQC-01: 暗号資産インベントリ作成**
    - Scope: TLS、KMS、署名、鍵ローテーション対象の棚卸し
    - Deliverable: `docs/crypto-agility-roadmap.md`（資産一覧）
    - Done: 資産ごとにアルゴリズム/鍵長/用途/更新周期が記載されている
    - Owner: TBD
    - Due: Week4-Day2

11. **PQC-02: Crypto-agility方針定義**
    - Scope: 将来PQCへ移行するための設計原則と判断基準
    - Deliverable: `docs/crypto-agility-roadmap.md`（方針セクション）
    - Done: 移行トリガーと非機能影響（性能/互換性）が明文化されている
    - Owner: TBD
    - Due: Week4-Day4

12. **PQC-03: 経営報告用サマリー作成**
    - Scope: 技術リスクと投資判断ポイントを1ページで要約
    - Deliverable: `docs/business-case.md`（経営サマリー）
    - Done: 意思決定者向けに「今やる/後でやる」が明確
    - Owner: TBD
    - Due: Week4-Day5
