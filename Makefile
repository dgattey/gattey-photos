.PHONY: dev package-macos icon

# Build everything and run (one sync server + opens the app).
dev:
	./scripts/dev.sh

package-macos:
	./scripts/package-macos.sh

icon:
	./scripts/generate-app-icon.sh
