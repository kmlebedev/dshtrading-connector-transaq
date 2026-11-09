.PHONY: test
.DEFAULT_GOAL := test

test: ## Connector unit tests (no gateway, no network beyond loopback fakes).
	node --test dshtrading-connector-transaq/test/*.test.mjs
