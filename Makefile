.PHONY: dev package-macos build-server

dev:
	./scripts/dev.sh

package-macos:
	./scripts/package-macos.sh

build-server:
	cd server && npm run build
