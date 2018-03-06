.PHONY: all
all: help

.PHONY: build-shellcheck
build-shellcheck: ## Builds a new shellcheck docker image to run tests in
	docker build -t gregarmer/dotfiles-shellcheck:latest -f Dockerfile.shellcheck .

.PHONY: build-dev-arch
build-dev-arch: ## Builds a new dev-arch docker image
	docker build -t gregarmer/dotfiles-arch:latest -f Dockerfile.arch .

.PHONY: dev-arch
dev-arch: ## Runs a basic ArchLinux environment in docker to develop with
	docker run -it --rm -v $(CURDIR):/home/greg/dotfiles:cached gregarmer/dotfiles-arch:latest zsh

.PHONY: test
test: shellcheck ## Runs all the tests on the files in the repository.

.PHONY: shellcheck
shellcheck: ## Runs the shellcheck tests on the scripts.
	docker run -it --rm -v $(CURDIR):/dotfiles:ro gregarmer/dotfiles-shellcheck:latest ./test.sh

.PHONY: update-submodules
update-submodules: ## Update the git submodules
	@git submodule update --init

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
