#!/bin/bash

# ==============================================================================
# Hotel Agile Architecture - 自動セットアップスクリプト
# このスクリプトを実行すると、足りないフォルダやファイルを自動で生成・配置します。
# ==============================================================================

echo "🚀 ポートフォリオ環境の自動セットアップを開始します..."

# 1. 必要なディレクトリの作成
mkdir -p lambda/type-a/reader
mkdir -p lambda/type-a/interface
mkdir -p lambda/type-a/tools/reader
mkdir -p lambda/type-a/execution/reservation
mkdir -p packages/reservation-schema
mkdir -p lambda/type-b/chatbot
mkdir -p lambda/type-b/send_email
mkdir -p lambda/type-b/sentinel_executioner

# 2. ファイルの生成
echo "📝 ファイルを生成中..."

# --- ルートディレクトリのファイル ---

cat << 'EOF' > PORTFOLIO_STRATEGY.md
# 🎯 ポートフォリオのスコープと今後の展望（Future Works）

本プロジェクトは、元々「Terraformの基本的な学習」を目的としてスタートしました。
しかし、設計を進めるうちに「技術（AWSリソース）の羅列ではなく、ビジネス要件（UXやブランド）を満たすための手段としてインフラはどうあるべきか？」というアーキテクチャの探求へと発展しました。

そのため、現在のリポジトリは**「インフラストラクチャの設計とIaC（Infrastructure as Code）の実装」に特化（スコープ）**しています。

## 📍 現在のプロジェクトの境界線（スコープ）

1. **インフラストラクチャ層（完了）**:
   - Terraformを用いたType-B（従来型）およびType-A（モダン型）の完全なコード化。
   - WAF、GuardDuty、KMS、CloudTrail等を用いたエンタープライズレベルのセキュリティ実装。
2. **アプリケーション層（スタブ状態）**:
   - Lambda関数やフロントエンドのHTML/JSは、インフラのプロビジョニングを検証するための「ダミーコード（スタブ）」として実装しています。
   - *※Terraformコード内の `dummy.zip` は、インフラ構築テスト用のプレースホルダーです。*

## 🚀 今後の展望と課題（Future Works）

実運用（プロダクション）レベルに引き上げるために、インフラだけでなく「アプリケーションのライフサイクル管理」が必要であると認識しており、以下のフェーズを今後の拡張課題として設定しています。

### 1. アプリケーションのビルドパイプライン構築
現在ダミーとなっているLambda関数（Node.js / Python）に対し、`package.json` や `requirements.txt` を用いた依存関係の管理を導入します。
手動でのZIP化ではなく、GitHub Actions等のCI/CDツールを用いて、依存ライブラリを含めたパッケージングとAWSへの自動デプロイを構築します。

### 2. 自動テスト（ユニットテスト）の導入
特に「Sentinel（Type-Bの自律防衛Lambda）」のようなセキュリティの中核を担うロジックに対して、`pytest` や `Vitest` を用いたユニットテストを実装します。

### 3. フロントエンドSPAの実装
Type-Aの完全なUXを実現するため、CognitoのSRP認証フローとAPI GatewayへのJWT認可を組み込んだReact/Vueベースのシングルページアプリケーション（SPA）をS3 + CloudFrontにデプロイします。
EOF

cat << 'EOF' > HOW_TO_DEPLOY.md
# 🚀 構築・デプロイメントガイド

本プロジェクトは、AWS上に「Type-B（従来型）」と「Type-A（モダン型）」の2つのアーキテクチャを構築します。

## 1. アプリケーションのテストとビルド

インフラ（Terraform）を構築する前に、Lambda関数のコードをテストし、AWSにデプロイ可能な形（ZIPファイル）にパッケージングします。

プロジェクトのルートディレクトリ（`Makefile`がある場所）で以下のコマンドを実行します。

```bash
# テストの実行
make test

# ZIPファイルの生成（ビルド）
make build