SHELL := /bin/bash

# =====================================================
# AI-Driven Internal Infrastructure — build & test
# =====================================================

PYTHON ?= python3
PIP_FLAGS := $(if $(GITHUB_ACTIONS),,--break-system-packages)

define run_pytest
	cd $(1) && \
	if [ -n "$$GITHUB_ACTIONS" ]; then \
	  $(PYTHON) -m venv .venv-ci && \
	  . .venv-ci/bin/activate && \
	  pip install -q -r requirements-dev.txt && \
	  pytest test_main.py -v; \
	else \
	  PYENV_DISABLE_REHASH=1 PIP_DISABLE_PIP_VERSION_CHECK=1 $(PYTHON) -m pip install -q -r requirements-dev.txt $(PIP_FLAGS) && \
	  $(PYTHON) -m pytest test_main.py -v; \
	fi
endef

.PHONY: test terraform-fmt-check terraform-validate \
        test-sentinel-enterprise test-sentinel-cloud-native test-rag-query

test: test-sentinel-enterprise test-sentinel-cloud-native test-rag-query
	@echo "\n✅ internal-infra Lambda テスト完了"

test-sentinel-enterprise:
	@echo "▶ sentinel_enterprise ..."
	$(call run_pytest,lambda/sentinel_enterprise)

test-sentinel-cloud-native:
	@echo "▶ sentinel_cloud_native ..."
	$(call run_pytest,lambda/sentinel_cloud_native)

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
