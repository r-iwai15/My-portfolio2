#!/bin/bash
set -euo pipefail

# ==============================================================================
# Hotel Reservation & Internal Infra Platform - セットアップ確認スクリプト
#
# 既存ファイルは一切上書きしません。期待するディレクトリ構成が存在するかを
# 確認し、不足分のみを作成します。ドキュメントは docs/ 配下が Source of Truth
# のため、このスクリプトでは生成しません（STRUCTURE.md / docs/ を参照）。
# ==============================================================================

echo "🚀 ディレクトリ構成を確認します..."

REQUIRED_DIRS=(
  "lambda/type-a/interface"
  "lambda/type-a/tools/reader"
  "lambda/type-a/execution/reservation"
  "lambda/type-b/chatbot"
  "lambda/type-b/send_email"
  "lambda/type-b/sentinel_executioner"
  "lambda/type-b/sentinel_release"
  "packages/reservation-schema"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    echo "  ✅ $dir"
  else
    echo "  ➕ $dir を作成します"
    mkdir -p "$dir"
  fi
done

echo ""
echo "✅ 構成確認が完了しました。"
echo "   次のステップ:"
echo "     make test    # 全 Lambda テスト"
echo "     make build   # lambda/*.zip 生成"
echo "     make ci      # test + terraform fmt/validate"
echo "   詳細は STRUCTURE.md / docs/IMPLEMENTATION_GUIDE.md を参照してください。"
