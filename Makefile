CHASSIS := $(shell sudo dmidecode --string chassis-type)

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: bin config localshare profile etc gnupg ## Installs the bin, .config, .local/share, etc and .gnupg directory files and the profile files.

desktop: all ## Bootstrap a new desktop install
	(cd scripts && sudo bash desktop_bootstrap_arch.sh)

wsl: all ## Bootstrap a new WSL install
	(cd scripts && sudo wsl_bootstrap_debian.sh)

bin: ## Installs the bin directory files.
	@echo '==Linking /bin files=='
	@if [ -d $(CURDIR)/$$(uname -n)/bin ]; then \
		for src_file in $(shell find -L $(CURDIR)/$$(uname -n)/bin -maxdepth 1 -mindepth 1 -type f -not -name ".*.swp"); do \
			dst_file=$$(basename $${src_file}); \
			echo "$${dst_file}"; \
			sudo ln -sf $${src_file} /usr/local/bin/$${dst_file}; \
		done; \
	fi

config: ## Installs the .config directory.
	@echo '==Linking ~/.config files=='
	@if [ -d $(CURDIR)/$$(uname -n)/profile/.config ]; then \
		mkdir -p $(HOME)/.config; \
		for src_file in $(shell find -L $(CURDIR)/$$(uname -n)/profile/.config -maxdepth 1 -mindepth 1 -not -name ".*.swp"); do \
			dst_file=$$(basename $${src_file}); \
			echo "$${dst_file}"; \
			ln -sfn $${src_file} $(HOME)/.config/$${dst_file}; \
		done; \
		ln -snf $(CURDIR)/$$(uname -n)/profile/.config/i3 $(HOME)/.config/sway; \
		SERVICE_LIST=( $(shell ls $(CURDIR)/$$(uname -n)/profile/.config/systemd/user) ); \
		if [ $${#SERVICE_LIST[@]} -gt 0 ]; then  \
			echo "Reload systemd user daemon"; \
			systemctl --user daemon-reload; \
			echo "Enable/Start systemd user services: $${SERVICE_LIST[@]}"; \
			systemctl --user enable $${SERVICE_LIST[@]}; \
			systemctl --user start $${SERVICE_LIST[@]}; \
		fi; \
	fi

localshare: ## Installs the .local/share directory.
	@echo '==Linking ~/.local/share files=='
	@if [ -d $(CURDIR)/$$(uname -n)/profile/.local/share ]; then \
		mkdir -p $(HOME)/.local/share; \
		for src_file in $(shell find -L $(CURDIR)/$$(uname -n)/profile/.local/share -maxdepth 1 -mindepth 1 -not -name ".*.swp"); do \
			dst_file=$$(basename $${src_file}); \
			echo "$${dst_file}"; \
			ln -sfn $${src_file} $(HOME)/.local/share/$${dst_file}; \
		done; \
	fi

profile: ## Installs the profile.
	@echo '==Linking homedir files=='
	@if [ -d $(CURDIR)/$$(uname -n)/profile ]; then \
		for src_file in $(shell find -L $(CURDIR)/$$(uname -n)/profile -maxdepth 1 -mindepth 1 -type f -not -name "gitignore" -not -name "gitmodules" -not -name ".*.swp"); do \
			dst_file=$$(basename $${src_file}); \
			echo "$${dst_file}"; \
			ln -sfn $${src_file} $(HOME)/$${dst_file}; \
		done; \
		if [ -f $(CURDIR)/$$(uname -n)/profile/gitignore ]; then \
			echo '.gitignore'; \
			ln -sfn $(CURDIR)/$$(uname -n)/profile/gitignore $(HOME)/.gitignore; \
		fi; \
		if [ -f $(CURDIR)/$$(uname -n)/profile/gitmodules ]; then \
			echo '.gitmodules'; \
			ln -sfn $(CURDIR)/$$(uname -n)/profile/gitmodules $(HOME)/.gitmodules; \
		fi; \
		systemctl --user daemon-reload || true; \
		git update-index --skip-worktree $(CURDIR)/.gitconfig; \
	fi

etc: ## Installs the etc directory files.
	@echo '==Copying /etc files=='
	@if [ -d $(CURDIR)/$$(uname -n)/etc ]; then \
		for src_file in $(shell find -L $(CURDIR)/$$(uname -n)/etc -type f -not -name ".*.swp"); do \
			dst_file=$$(echo $${src_file} | sed -e 's|$(CURDIR)/$(shell uname -n)||'); \
			echo "$${dst_file}"; \
			sudo mkdir -p $$(dirname $${dst_file}); \
			sudo cp $${src_file} $${dst_file}; \
		done; \
		echo "Reload systemd daemon"; \
		sudo systemctl daemon-reload; \
		echo "Enable/Start systemd services: $(shell ls $(CURDIR)/$$(uname -n)/etc/systemd/system)"; \
		sudo systemctl enable $(shell ls $(CURDIR)/$$(uname -n)/etc/systemd/system); \
		sudo systemctl start $(shell ls $(CURDIR)/$$(uname -n)/etc/systemd/system); \
	fi

gnupg: ## Installs the .gnupg directory.
	@echo '==Linking ~/.gnupg files=='
	@if [ -d $(CURDIR)/$$(uname -n)/profile/.gnupg ]; then \
		mkdir -p $(HOME)/.gnupg; \
		gpg --list-keys || true; \
		for src_file in $(shell find -L $(CURDIR)/$$(uname -n)/profile/.gnupg -maxdepth 1 -mindepth 1); do \
			dst_file=$$(basename $${src_file}); \
			echo "$${dst_file}"; \
			ln -sfn $${src_file} $(HOME)/.gnupg/$${dst_file}; \
		done; \
	fi

test: shellcheck ## Runs all the tests on the files in the repository.

# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

shellcheck: ## Runs the shellcheck tests on the scripts.
	docker run --rm -i $(DOCKER_FLAGS) \
		--name df-shellcheck \
		-v $(CURDIR):/usr/src:ro \
		--workdir /usr/src \
		rjszynal/shellcheck ./test.sh

.PHONY: help all desktop wsl bin config localshare profile etc gnupg test shellcheck
