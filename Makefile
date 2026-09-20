PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin
VERSION := $(shell awk -F'"' '/^VERSION=/{print $$2; exit}' bin/clean-node-modules)
DISTDIR := dist

.PHONY: all install uninstall test lint dist clean

all: test

install:
	@mkdir -p $(BINDIR)
	@install -m 0755 bin/clean-node-modules $(BINDIR)/clean-node-modules
	@echo "installed $(BINDIR)/clean-node-modules"

uninstall:
	@rm -f $(BINDIR)/clean-node-modules
	@echo "removed $(BINDIR)/clean-node-modules"

test:
	@./test/run-tests.sh

lint:
	@command -v shellcheck >/dev/null 2>&1 \
		&& shellcheck bin/clean-node-modules test/run-tests.sh install.sh \
		|| echo "shellcheck not installed, skipping"

# Release artifacts: the bare script, a tarball, and checksums for both.
dist: clean
	@mkdir -p $(DISTDIR)
	@install -m 0755 bin/clean-node-modules $(DISTDIR)/clean-node-modules
	@tar -czf $(DISTDIR)/clean-node-modules-$(VERSION).tar.gz \
		bin/clean-node-modules install.sh Makefile README.md
	@cd $(DISTDIR) && { command -v sha256sum >/dev/null 2>&1 \
		&& sha256sum clean-node-modules clean-node-modules-$(VERSION).tar.gz > SHA256SUMS \
		|| shasum -a 256 clean-node-modules clean-node-modules-$(VERSION).tar.gz > SHA256SUMS; }
	@echo "built $(DISTDIR)/ for v$(VERSION)"
	@ls -1 $(DISTDIR)

clean:
	@rm -rf $(DISTDIR)
