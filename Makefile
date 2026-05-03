SHELL := /bin/sh

UPSTREAM_BRANCH ?= upstream/main
BUNDLE_DIR := src-tauri/target/release/bundle
DEB_DIR := $(BUNDLE_DIR)/deb
PACKAGE_NAME := codex-switcher
APP_PROCESS := codex-switcher
TAURI_LOCAL_CONFIG := {"bundle":{"createUpdaterArtifacts":false}}

.PHONY: check-update update build stop-app install-deb

check-update:
	@git fetch upstream
	@missing_count=$$(git rev-list --count HEAD..$(UPSTREAM_BRANCH)); \
	local_count=$$(git rev-list --count $(UPSTREAM_BRANCH)..HEAD); \
	if [ "$$missing_count" -eq 0 ]; then \
		echo "No upstream updates found on $(UPSTREAM_BRANCH)."; \
	else \
		echo "$$missing_count upstream commit(s) available from $(UPSTREAM_BRANCH):"; \
		git --no-pager log --oneline HEAD..$(UPSTREAM_BRANCH); \
	fi; \
	if [ "$$local_count" -gt 0 ]; then \
		echo ""; \
		if [ "$$missing_count" -gt 0 ]; then \
			echo "$$local_count local commit(s) will be replayed when you run make update:"; \
		else \
			echo "$$local_count local fork commit(s):"; \
		fi; \
		git --no-pager log --oneline $(UPSTREAM_BRANCH)..HEAD; \
	fi

update:
	git fetch upstream
	git rebase $(UPSTREAM_BRANCH)

build: stop-app
	pnpm tauri build --bundles deb --config '$(TAURI_LOCAL_CONFIG)'
	$(MAKE) install-deb

stop-app:
	@if pgrep -x "$(APP_PROCESS)" >/dev/null 2>&1; then \
		echo "Stopping running $(APP_PROCESS)..."; \
		pkill -x "$(APP_PROCESS)" || true; \
		for attempt in 1 2 3 4 5; do \
			if ! pgrep -x "$(APP_PROCESS)" >/dev/null 2>&1; then \
				break; \
			fi; \
			sleep 1; \
		done; \
		if pgrep -x "$(APP_PROCESS)" >/dev/null 2>&1; then \
			echo "Force stopping $(APP_PROCESS)..."; \
			pkill -9 -x "$(APP_PROCESS)" || true; \
		fi; \
	fi

install-deb:
	@deb_path=$$(find "$(DEB_DIR)" -name '*.deb' -print 2>/dev/null | sort | tail -n 1); \
	if [ -z "$$deb_path" ]; then \
		echo "No .deb bundle found under $(DEB_DIR)."; \
		exit 1; \
	fi; \
	echo "Installing $$deb_path..."; \
	sudo dpkg -i "$$deb_path"; \
	echo "Installed package status:"; \
	dpkg-query -W -f='$${Package} $${Version} $${Status}\n' "$(PACKAGE_NAME)"
