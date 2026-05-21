# =====================================================
# Hotel Reservation Platform - Lambda Build & Test
#
# 使い方:
#   make test        全Lambdaのテストを実行
#   make build       全LambdaをZIPに固める (lambda/ に出力)
#   make clean       ビルド成果物を削除
#
# 前提:
#   Node.js >= 20, Python >= 3.11, pip, npm, terraform
#   terraform apply は terraform/type-* から実行
# =====================================================

.PHONY: all ci test build clean terraform-fmt-check terraform-validate \
        terraform-plan-type-b terraform-plan-type-a terraform-plan-type-b-aws terraform-plan-type-a-aws \
        test-chatbot test-sentinel-exec test-sentinel-release \
        test-reader test-interface test-reservation \
        test-internal-infra \
        build-chatbot build-sentinel build-reader build-interface build-reservation

all: test build

ci: test terraform-fmt-check terraform-validate
	@echo "\n✅ CIチェック完了"


# =====================================================
# テスト
# =====================================================

test: test-chatbot test-sentinel-exec test-sentinel-release \
      test-reader test-interface test-reservation test-internal-infra
	@echo "\n✅ 全テスト完了"

test-internal-infra:
	@$(MAKE) -C internal-infra test

test-chatbot:
	@echo "▶ [Type-B] chatbot テスト中..."
	cd lambda/type-b/chatbot && npm install --silent && npm test

test-sentinel-exec:
	@echo "▶ [Type-B] sentinel_executioner テスト中..."
	cd lambda/type-b/sentinel_executioner && \
	  PYENV_DISABLE_REHASH=1 PIP_DISABLE_PIP_VERSION_CHECK=1 python3 -m pip install -q -r requirements-dev.txt --break-system-packages && \
	  python3 -m pytest test_main.py -v

test-sentinel-release:
	@echo "▶ [Type-B] sentinel_release テスト中..."
	cd lambda/type-b/sentinel_release && \
	  PYENV_DISABLE_REHASH=1 PIP_DISABLE_PIP_VERSION_CHECK=1 python3 -m pip install -q -r requirements-dev.txt --break-system-packages && \
	  python3 -m pytest test_main.py -v

test-reader:
	@echo "▶ [Type-A] tools/reader テスト中..."
	cd lambda/type-a/tools/reader && npm install --silent && npm test

test-interface:
	@echo "▶ [Type-A] interface テスト中..."
	cd lambda/type-a/interface && npm install --silent && npm test

test-reservation:
	@echo "▶ [Type-A] execution/reservation テスト中..."
	cd lambda/type-a/execution/reservation && npm install --silent && npm test

terraform-fmt-check:
	@echo "▶ Terraform fmt チェック中..."
	terraform -chdir=terraform/type-b fmt -check -recursive
	terraform -chdir=terraform/type-a fmt -check -recursive
	terraform -chdir=terraform/corp-internal fmt -check -recursive
	terraform -chdir=internal-infra/terraform/type-b fmt -check -recursive
	terraform -chdir=internal-infra/terraform/type-a fmt -check -recursive

terraform-validate:
	@echo "▶ Terraform validate 実行中..."
	terraform -chdir=terraform/type-b init -backend=false -input=false -upgrade
	terraform -chdir=terraform/type-b validate
	terraform -chdir=terraform/type-a init -backend=false -input=false -upgrade
	terraform -chdir=terraform/type-a validate
	terraform -chdir=terraform/corp-internal init -backend=false -input=false -upgrade
	terraform -chdir=terraform/corp-internal validate
	terraform -chdir=internal-infra/terraform/type-b init -backend=false -input=false -upgrade
	terraform -chdir=internal-infra/terraform/type-b validate
	terraform -chdir=internal-infra/terraform/type-a init -backend=false -input=false -upgrade
	terraform -chdir=internal-infra/terraform/type-a validate

terraform-plan-type-b:
	@bash scripts/terraform-plan.sh type-b local

terraform-plan-type-a:
	@bash scripts/terraform-plan.sh type-a local

terraform-plan-type-b-aws:
	@bash scripts/terraform-plan.sh type-b aws

terraform-plan-type-a-aws:
	@bash scripts/terraform-plan.sh type-a aws


# =====================================================
# ビルド (lambda/ 直下にZIPを出力)
# =====================================================

build: build-chatbot build-sentinel build-reader build-interface build-reservation
	@echo "\n📦 全ZIPビルド完了 → lambda/*.zip"

build-chatbot:
	@echo "▶ [Type-B] chatbot をビルド中..."
	cd lambda/type-b/chatbot && \
	  npm install --omit=dev --silent && \
	  zip -rq ../../../lambda/chatbot.zip . --exclude "*.test.js" "*.md" ".gitignore"
	@echo "  → lambda/chatbot.zip"

build-sentinel:
	@echo "▶ [Type-B] sentinel をビルド中..."
	cd lambda/type-b/sentinel_executioner && \
	  zip -jq ../../../lambda/sentinel_executioner.zip main.py
	cd lambda/type-b/sentinel_release && \
	  zip -jq ../../../lambda/sentinel_release.zip main.py
	@echo "  → lambda/sentinel_executioner.zip"
	@echo "  → lambda/sentinel_release.zip"

build-reader:
	@echo "▶ [Type-A] tools/reader をビルド中..."
	cd lambda/type-a/tools/reader && \
	  npm install --omit=dev --silent && \
	  zip -rq ../../../../lambda/reader.zip . --exclude "*.test.js" "*.md" ".gitignore" "coverage/*"
	@echo "  → lambda/reader.zip"

build-interface:
	@echo "▶ [Type-A] interface をビルド中..."
	cd lambda/type-a/interface && \
	  npm install --omit=dev --silent && \
	  zip -rq ../../../lambda/interface.zip . --exclude "*.test.js" "*.md" ".gitignore"
	@echo "  → lambda/interface.zip"

build-reservation:
	@echo "▶ [Type-A] execution/reservation をビルド中..."
	cd lambda/type-a/execution/reservation && \
	  npm install --omit=dev --silent && \
	  zip -rq ../../../../lambda/reservation.zip . --exclude "*.test.js" "*.md" ".gitignore"
	@echo "  → lambda/reservation.zip"

clean:
	rm -f lambda/chatbot.zip \
	      lambda/sentinel_executioner.zip \
	      lambda/sentinel_release.zip \
	      lambda/reader.zip \
	      lambda/interface.zip \
	      lambda/reservation.zip \
	      lambda/writer.zip \
	      lambda/send_email.zip
	find lambda -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
	find lambda -name "__pycache__"  -type d -exec rm -rf {} + 2>/dev/null || true
	find lambda -name ".pytest_cache" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "🧹 クリーンアップ完了"
