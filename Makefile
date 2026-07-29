.PHONY: build test clean release-site shellcheck

VERSION := $(shell sed -n 's/^GS_APP_VERSION="\(.*\)"/\1/p' src/10_constants.sh)

build:
	bash build.sh

test: build
	bash tests/run_tests.sh

clean:
	rm -f dist/gitstart.sh dist/gitstart.sh.sha256

release-site: build
	mkdir -p site/releases/v$(VERSION)
	cp dist/gitstart.sh site/releases/v$(VERSION)/
	cp dist/gitstart.sh.sha256 site/releases/v$(VERSION)/
	printf 'v$(VERSION)\n' > site/stable.txt

shellcheck:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -s bash dist/gitstart.sh; \
	else \
		echo "ShellCheck not installed."; \
	fi
