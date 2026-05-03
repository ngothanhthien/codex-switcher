SHELL := /bin/sh

UPSTREAM_BRANCH ?= upstream/main
BUNDLE_DIR := src-tauri/target/release/bundle
APP_NAME := Codex Switcher
APP_PROCESS := codex-switcher

.PHONY: check-update update build stop-app install-local

check-update:
	@git fetch upstream
	@local_ref=$$(git rev-parse HEAD); \
	upstream_ref=$$(git rev-parse $(UPSTREAM_BRANCH)); \
	base_ref=$$(git merge-base HEAD $(UPSTREAM_BRANCH)); \
	if [ "$$local_ref" = "$$upstream_ref" ]; then \
		echo "Already up to date with $(UPSTREAM_BRANCH)."; \
	elif [ "$$local_ref" = "$$base_ref" ]; then \
		echo "Updates available from $(UPSTREAM_BRANCH):"; \
		git --no-pager log --oneline HEAD..$(UPSTREAM_BRANCH); \
	elif [ "$$upstream_ref" = "$$base_ref" ]; then \
		echo "Local branch is ahead of $(UPSTREAM_BRANCH):"; \
		git --no-pager log --oneline $(UPSTREAM_BRANCH)..HEAD; \
	else \
		echo "Local branch and $(UPSTREAM_BRANCH) have diverged."; \
		echo "Upstream commits:"; \
		git --no-pager log --oneline HEAD..$(UPSTREAM_BRANCH); \
		echo "Local commits:"; \
		git --no-pager log --oneline $(UPSTREAM_BRANCH)..HEAD; \
	fi

update:
	git fetch upstream
	git rebase $(UPSTREAM_BRANCH)

build: stop-app
	pnpm tauri build
	$(MAKE) install-local

stop-app:
	@os=$$(uname -s); \
	case "$$os" in \
		Darwin) \
			osascript -e 'quit app "$(APP_NAME)"' >/dev/null 2>&1 || true; \
			pkill -x "$(APP_NAME)" >/dev/null 2>&1 || true; \
			;; \
		Linux) \
			pkill -x "$(APP_PROCESS)" >/dev/null 2>&1 || true; \
			;; \
		MINGW*|MSYS*|CYGWIN*) \
			powershell.exe -NoProfile -Command "Get-Process 'codex-switcher' -ErrorAction SilentlyContinue | Stop-Process -Force" >/dev/null 2>&1 || true; \
			;; \
	esac

install-local:
	@os=$$(uname -s); \
	case "$$os" in \
		Darwin) \
			app_path="$$(find "$(BUNDLE_DIR)/macos" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null)"; \
			if [ -n "$$app_path" ]; then \
				rm -rf "/Applications/$$(basename "$$app_path")"; \
				cp -R "$$app_path" /Applications/; \
				echo "Installed $$(basename "$$app_path") to /Applications."; \
			else \
				echo "macOS app bundle not found under $(BUNDLE_DIR)/macos."; \
			fi; \
			;; \
		Linux) \
			deb_path="$$(find "$(BUNDLE_DIR)/deb" -name '*.deb' -print -quit 2>/dev/null)"; \
			appimage_path="$$(find "$(BUNDLE_DIR)/appimage" -name '*.AppImage' -print -quit 2>/dev/null)"; \
			if [ -n "$$deb_path" ] && command -v dpkg >/dev/null 2>&1; then \
				sudo dpkg -i "$$deb_path"; \
			elif [ -n "$$appimage_path" ]; then \
				mkdir -p "$$HOME/.local/bin"; \
				cp "$$appimage_path" "$$HOME/.local/bin/codex-switcher"; \
				chmod +x "$$HOME/.local/bin/codex-switcher"; \
				echo "Installed AppImage to $$HOME/.local/bin/codex-switcher."; \
			else \
				echo "No installable Linux bundle found under $(BUNDLE_DIR)."; \
			fi; \
			;; \
		MINGW*|MSYS*|CYGWIN*) \
			echo "Windows bundle built under $(BUNDLE_DIR). Run the generated installer manually."; \
			;; \
		*) \
			echo "Unsupported OS $$os. Bundle output is under $(BUNDLE_DIR)."; \
			;; \
	esac
