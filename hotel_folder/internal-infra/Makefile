# =====================================================
# AI-Driven Internal Infrastructure — build & test
# =====================================================

.PHONY: test terraform-fmt-check terraform-validate \
        test-sentinel-enterprise test-sentinel-cloud-native test-rag-query

test: test-sentinel-enterprise test-sentinel-cloud-native test-rag-query
	@echo "\n✅ internal-infra Lambda テスト完了"

test-sentinel-enterprise:
	@echo "▶ sentinel_enterprise ..."
	cd lambda/sentinel_enterprise && \
	  PYENV_DISABLE_REHASH=1 PIP_DISABLE_PIP_VERSION_CHECK=1 python3 -m pip install -q -r requirements-dev.txt --break-system-packages && \
	  python3 -m pytest test_main.py -v

test-sentinel-cloud-native:
	@echo "▶ sentinel_cloud_native ..."
	cd lambda/sentinel_cloud_native && \
	  PYENV_DISABLE_REHASH=1 PIP_DISABLE_PIP_VERSION_CHECK=1 python3 -m pip install -q -r requirements-dev.txt --break-system-packages && \
	  python3 -m pytest test_main.py -v

test-rag-query:
	@echo "▶ rag_query ..."
	cd lambda/rag_query && npm install --silent && npm test

terraform-fmt-check:
	terraform -chdir=terraform/type-b fmt -check -recursive
	terraform -chdir=terraform/type-a fmt -check -recursive

terraform-validate:
	terraform -chdir=terraform/type-b init -backend=false -input=false -upgrade
	terraform -chdir=terraform/type-b validate
	terraform -chdir=terraform/type-a init -backend=false -input=false -upgrade
	terraform -chdir=terraform/type-a validate
