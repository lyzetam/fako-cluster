.PHONY: verify
verify: ## Render every Flux root offline; VERIFY_SERVER=1 adds a server-side dry-run
	@bash scripts/verify.sh
