.PHONY: all
all: bin config dotfiles etc gnupg ## Installs the bin, config, etc and gnupg directory files and the dotfiles.

.PHONY: bin
bin: ## Installs the bin directory files.
	# add aliases for things in bin
	for file in $(shell find $(CURDIR)/bin -maxdepth 1 -mindepth 1 -type f -not -name "*-backlight" -not -name ".*.swp"); do \
		f=$$(basename $$file); \
		sudo ln -sf $$file /usr/local/bin/$$f; \
	done

.PHONY: config
config: ## Installs the .config directory.
	# add aliases for .config directory
	mkdir -p $(HOME)/.config;
	for file in $(shell find $(CURDIR)/.config -maxdepth 1 -mindepth 1 -not -name ".*.swp"); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/.config/$$f; \
	done; \
	ln -snf $(CURDIR)/.config/i3 $(HOME)/.config/sway;

.PHONY: dotfiles
dotfiles: ## Installs the dotfiles.
	# add aliases for dotfiles
	for file in $(shell find $(CURDIR) -maxdepth 1 -mindepth 1 -type f -name ".*" -not -name ".gitignore" -not -name ".travis.yml" -not -name ".*.swp"); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/$$f; \
	done; \
	ln -fn $(CURDIR)/gitignore $(HOME)/.gitignore;
	git update-index --skip-worktree $(CURDIR)/.gitconfig;
	mkdir -p $(HOME)/.local/share;
	ln -snf $(CURDIR)/.fonts $(HOME)/.local/share/fonts;
	if [ -f /usr/local/bin/pinentry ]; then \
		sudo ln -snf /usr/bin/pinentry /usr/local/bin/pinentry; \
	fi;

.PHONY: etc
etc: ## Installs the etc directory files.
	sudo mkdir -p /etc/docker/seccomp
	for file in $(shell find $(CURDIR)/etc -type f -not -name ".*.swp"); do \
		f=$$(echo $$file | sed -e 's|$(CURDIR)||'); \
		sudo mkdir -p $$(dirname $$f); \
		sudo ln -f $$file $$f; \
	done
	systemctl --user daemon-reload || true
	sudo systemctl daemon-reload
	sudo ln -snf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

.PHONY: gnupg
gnupg: ## Installs the .gnupg directory.
	# add aliases for .gnupg directory
	mkdir -p $(HOME)/.gnupg;
	gpg --list-keys || true;
	for file in $(shell find $(CURDIR)/.gnupg -maxdepth 1 -mindepth 1); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/.gnupg/$$f; \
	done; \

.PHONY: test
test: shellcheck ## Runs all the tests on the files in the repository.

# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

.PHONY: shellcheck
shellcheck: ## Runs the shellcheck tests on the scripts.
	docker run --rm -i $(DOCKER_FLAGS) \
		--name df-shellcheck \
		-v $(CURDIR):/usr/src:ro \
		--workdir /usr/src \
		r.j3ss.co/shellcheck ./test.sh

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
