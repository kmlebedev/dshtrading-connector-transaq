.PHONY: test docs docs-serve
.DEFAULT_GOAL := test

test: ## Connector unit tests (no gateway, no network beyond loopback fakes).
	node --test test/*.test.mjs

docs: ## Build the GitHub Pages site (requires mkdocs-material).
	python3 -m mkdocs build --strict

docs-serve: ## Preview the GitHub Pages site locally.
	python3 -m mkdocs serve
